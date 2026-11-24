"""
Audits every CloudWatch log group in the account for management through the
standard cloudwatch_log_group Tofu module.

Classification per log group:
  - exception:     name is on the config-managed exceptions list
  - unmanaged:     missing the terraform=true tag (not provisioned via Tofu)
  - misconfigured: tagged, but the log-retention subscription filter is
                   missing or points at the wrong destination
  - compliant:     tagged and correctly routed to the log-retention Firehose

Full results (all classifications) are written to S3, one object per
(app, env) so each team can find its own findings. One SNS message per
(app, env) with findings is published to the CDAP alarm topic, shaped like
a CloudWatch alarm so alarm-to-slack routes it to the owning team's channel.
"""

from datetime import datetime, timezone
import json
import os
import re
import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

APPS = ['ab2d', 'bcda', 'dpc', 'cdap']
ENVS = ['dev', 'test', 'sandbox', 'prod']

# Recognized as an env token so "non-prod" never resolves as "prod", but
# mapped to the account's own env: non-prod resources live in the test
# account, and alarm-to-slack only routes envs in ENVS
NON_PROD = 'non-prod'

FALLBACK_APP = 'cdap'

# App/env tokens must be bounded by these delimiters (or the string boundary)
# so e.g. "abcda" does not match "bcda"
TOKEN_BOUNDARY = r'[-/_]'

# Cap the number of log group names listed in a Slack alert
MAX_NAMES_IN_REASON = 10

FINDINGS = ('unmanaged', 'misconfigured')

client_cache = {}
ssm_parameter_cache = {}


def get_client(service):
    """
    Cached boto3 client initialization.
    """
    if service not in client_cache:
        client_cache[service] = boto3.client(
            service, config=Config(retries={'mode': 'adaptive', 'max_attempts': 10}))
    return client_cache[service]


def get_ssm_parameter(name):
    """
    Retrieves an SSM parameter and caches the value to prevent duplicate API
    calls. Raises if the parameter is missing, since the audit cannot run without
    the Firehose ARN.
    """
    if name not in ssm_parameter_cache:
        response = get_client('ssm').get_parameter(Name=name, WithDecryption=True)
        ssm_parameter_cache[name] = response['Parameter']['Value']
    return ssm_parameter_cache[name]


def get_exceptions():
    """Exact log group names exempt from the audit, set from Tofu config."""
    return set(json.loads(os.environ.get('EXCEPTIONS', '[]')))


def get_exception_prefixes():
    """
    Log group name prefixes excluded from the audit entirely, set from Tofu
    config. Unlike exact-name exceptions (which stay visible in results with
    classification "exception"), prefix-matched groups are skipped before
    classification and appear nowhere in results, counts, or alerts. Intended
    for CMS Cloud-managed groups (cms-cloud-*, golden-image agent logs, etc.)
    that CDAP teams cannot act on.
    """
    return tuple(json.loads(os.environ.get('EXCEPTION_PREFIXES', '[]')))


def notifications_enabled():
    """
    Whether findings alerts are published to SNS, set from Tofu config.
    When disabled, the audit still runs and writes results to S3, but alerts
    are only logged, so test runs don't page teams in Slack.
    """
    return os.environ.get('NOTIFICATIONS_ENABLED', 'true') == 'true'


def resolve_token(log_group_name, tokens):
    """
    Finds the earliest delimiter-bounded occurrence of any token in the log
    group name. A token only counts when bounded by -, /, _ or the string
    boundary on both sides, so "ephemeral-dev" resolves to "dev" but "abcda"
    never resolves to "bcda". Returns the matched token or None.
    """
    earliest = None
    earliest_pos = None
    for token in tokens:
        pattern = rf'(?:^|{TOKEN_BOUNDARY}){re.escape(token)}(?:$|{TOKEN_BOUNDARY})'
        match = re.search(pattern, log_group_name)
        if match and (earliest_pos is None or match.start() < earliest_pos):
            earliest = token
            earliest_pos = match.start()
    return earliest


def resolve_app(log_group_name):
    """
    Resolves the owning app from the log group name. Returns (app, fallback)
    where fallback=True means no app token was found and cdap was assumed.
    """
    app = resolve_token(log_group_name, APPS)
    if app is None:
        return FALLBACK_APP, True
    return app, False


def resolve_env(log_group_name, account_env):
    """
    Resolves the env from the log group name. Returns (env, fallback) where
    fallback=True means no env token was found and the account's own env was
    assumed. "non-prod" is matched as its own token (so it is never
    misresolved as "prod") and maps to the account env.
    """
    env = resolve_token(log_group_name, ENVS + [NON_PROD])
    if env is None:
        return account_env, True
    if env == NON_PROD:
        return account_env, False
    return env, False


def list_log_groups():
    """Enumerates all log groups in the account via paginated DescribeLogGroups."""
    paginator = get_client('logs').get_paginator('describe_log_groups')
    log_groups = []
    for page in paginator.paginate():
        log_groups.extend(page['logGroups'])
    return log_groups


def get_log_group_tags():
    """
    Bulk fetches tags for every log group in the account via the Resource
    Groups Tagging API. Returns a map of log group name -> {tag key: value}.
    """
    paginator = get_client('resourcegroupstaggingapi').get_paginator('get_resources')
    tags_by_name = {}
    for page in paginator.paginate(ResourceTypeFilters=['logs:log-group']):
        for mapping in page['ResourceTagMappingList']:
            # arn:aws:logs:<region>:<account>:log-group:<name>
            name = mapping['ResourceARN'].split(':log-group:', 1)[1]
            tags_by_name[name] = {t['Key']: t['Value'] for t in mapping['Tags']}
    return tags_by_name


def is_routed(log_group_name, firehose_arn):
    """
    True when any subscription filter on the log group delivers to the
    account's log-retention Firehose.
    """
    response = get_client('logs').describe_subscription_filters(
        logGroupName=log_group_name)
    return any(f.get('destinationArn') == firehose_arn
               for f in response.get('subscriptionFilters', []))


def classify(log_group_name, tags, routed, exceptions):
    """Applies the classification. Exceptions win over everything."""
    if log_group_name in exceptions:
        return 'exception'
    if tags.get('terraform') != 'true':
        return 'unmanaged'
    if not routed:
        return 'misconfigured'
    return 'compliant'


def audit():
    """
    Runs the full audit and returns one record per log group with its
    classification and resolved ownership. Groups matching an exception prefix
    are omitted entirely.
    """
    account_env = os.environ['ENV']
    firehose_arn = get_ssm_parameter(os.environ['FIREHOSE_ARN_SSM_PARAM'])
    exceptions = get_exceptions()
    exception_prefixes = get_exception_prefixes()
    tags_by_name = get_log_group_tags()

    records = []
    skipped = 0
    for log_group in list_log_groups():
        name = log_group['logGroupName']
        if exception_prefixes and name.startswith(exception_prefixes):
            skipped += 1
            continue
        tags = tags_by_name.get(name, {})
        exempt = name in exceptions
        # Skip the per-log-group filter lookup for exceptions, since some (like the
        # Firehose's own diagnostics group) must never be routed
        routed = False if exempt else is_routed(name, firehose_arn)
        app, app_fallback = resolve_app(name)
        env, env_fallback = resolve_env(name, account_env)

        records.append({
            'log_group': name,
            'classification': classify(name, tags, routed, exceptions),
            'app': app,
            'app_fallback': app_fallback,
            'env': env,
            'env_fallback': env_fallback,
            'managed': tags.get('terraform') == 'true',
            'routed': routed,
            'retention_in_days': log_group.get('retentionInDays'),
        })
    if skipped:
        log({'msg': 'Skipped log groups matching exception prefixes',
             'skipped': skipped})
    return records


def group_by_owner(records):
    """Groups audit records into a dict keyed by (app, env)."""
    grouped = {}
    for record in records:
        grouped.setdefault((record['app'], record['env']), []).append(record)
    return grouped


def results_key(prefix, app, env, run_date):
    """S3 key for one (app, env) partition of the audit results."""
    return f'{prefix}app={app}/env={env}/date={run_date}/log-groups.json'


def count_by_classification(records):
    """Returns a dict of classification -> count for a list of records."""
    counts = {}
    for record in records:
        counts[record['classification']] = counts.get(record['classification'], 0) + 1
    return counts


def write_results(grouped, run_date, generated_at):
    """
    Writes full results (not just findings) to S3, one object per (app, env)
    partition plus an account-wide summary.
    """
    s3 = get_client('s3')
    bucket = os.environ['RESULTS_BUCKET']
    prefix = os.environ.get('RESULTS_PREFIX', 'results/')
    account_env = os.environ['ENV']

    summary = {}
    for (app, env), records in sorted(grouped.items()):
        key = results_key(prefix, app, env, run_date)
        body = {
            'generated_at': generated_at,
            'account_env': account_env,
            'app': app,
            'env': env,
            'counts': count_by_classification(records),
            'log_groups': sorted(records, key=lambda r: r['log_group']),
        }
        s3.put_object(Bucket=bucket, Key=key,
                      Body=json.dumps(body, indent=2).encode('utf-8'),
                      ContentType='application/json')
        summary[f'{app}-{env}'] = body['counts']
        log({'msg': 'Wrote audit results', 'bucket': bucket, 'key': key,
             'counts': body['counts']})

    summary_key = f'{prefix}summary/date={run_date}/summary.json'
    s3.put_object(Bucket=bucket, Key=summary_key,
                  Body=json.dumps({
                      'generated_at': generated_at,
                      'account_env': account_env,
                      'owners': summary,
                  }, indent=2).encode('utf-8'),
                  ContentType='application/json')
    log({'msg': 'Wrote audit summary', 'bucket': bucket, 'key': summary_key})


def new_state_reason(app, env, records, findings, s3_uri):
    """Human-readable findings summary for the Slack alert."""
    counts = count_by_classification(findings)
    parts = []
    for classification in FINDINGS:
        if counts.get(classification):
            names = sorted(r['log_group'] for r in findings
                           if r['classification'] == classification)
            shown = ', '.join(names[:MAX_NAMES_IN_REASON])
            if len(names) > MAX_NAMES_IN_REASON:
                shown += f', … and {len(names) - MAX_NAMES_IN_REASON} more'
            parts.append(f'{len(names)} {classification}: {shown}')
    return (f'{len(findings)} of {len(records)} audited log groups for '
            f'{app}-{env} need attention. {"; ".join(parts)}. '
            f'Full results: {s3_uri}')


def publish_findings(grouped, run_date, generated_at):
    """
    Publishes one SNS message per (app, env) that has findings, built like
    a CloudWatch alarm so alarm-to-slack parses AlarmName into app/env and
    routes it to the owning team's Slack channel. Owners with no findings get
    no message. When notifications are disabled via config, alerts are logged
    instead of published.
    """
    enabled = notifications_enabled()
    topic_arn = os.environ['SNS_TOPIC_ARN']
    bucket = os.environ['RESULTS_BUCKET']
    prefix = os.environ.get('RESULTS_PREFIX', 'results/')
    region = os.environ.get('AWS_REGION', 'us-east-1')

    published = 0
    for (app, env), records in sorted(grouped.items()):
        findings = [r for r in records if r['classification'] in FINDINGS]
        if not findings:
            continue

        s3_uri = f's3://{bucket}/{results_key(prefix, app, env, run_date)}'
        message = {
            'AlarmName': f'{app}-{env}-log-group-audit',
            'AlarmDescription': (
                'Weekly audit of CloudWatch log groups for management through '
                'the standard cloudwatch_log_group Tofu module '
                '(terraform tag + log-retention subscription filter)'),
            'NewStateValue': 'ALARM',
            'OldStateValue': 'OK',
            'NewStateReason': new_state_reason(app, env, records, findings, s3_uri),
            'StateChangeTime': generated_at,
            'Region': region,
        }
        if not enabled:
            log({'msg': 'Notifications disabled, suppressed findings alert',
                 'alarm_name': message['AlarmName'], 'findings': len(findings)})
            continue
        get_client('sns').publish(TopicArn=topic_arn, Message=json.dumps(message))
        published += 1
        log({'msg': 'Published findings alert', 'app': app, 'env': env,
             'findings': len(findings)})
    return published


def handle_liveness_event():
    """
    Handles a deploy-time liveness check invocation from Tofu's
    aws_lambda_invocation. Verifies required configuration is present and the
    Firehose ARN parameter is readable. Raises RuntimeError on failure, which
    surfaces as a function error and fails the Tofu apply.
    """
    missing = [var for var in ('ENV', 'RESULTS_BUCKET', 'SNS_TOPIC_ARN',
                               'FIREHOSE_ARN_SSM_PARAM')
               if not os.environ.get(var)]
    if missing:
        raise RuntimeError(
            f'Liveness check failed: missing environment variables: {", ".join(missing)}')

    try:
        firehose_arn = get_ssm_parameter(os.environ['FIREHOSE_ARN_SSM_PARAM'])
    except (BotoCoreError, ClientError) as e:
        raise RuntimeError(
            f'Liveness check failed: cannot read Firehose ARN parameter: {e}') from e

    get_exceptions()  # raises on malformed EXCEPTIONS JSON
    get_exception_prefixes()  # raises on malformed EXCEPTION_PREFIXES JSON

    log({'msg': 'Liveness check passed', 'firehose_arn': firehose_arn})
    return {'statusCode': 200, 'body': 'Liveness check passed'}


def lambda_handler(event, _):
    """
    Main entry point. Handles two event types:
    1) A deploy-time liveness check invoked via Tofu changes
    2) The scheduled weekly audit
    """
    if event.get('RequestType') == 'LivenessCheck':
        return handle_liveness_event()

    now = datetime.now(timezone.utc)
    run_date = now.strftime('%Y-%m-%d')
    generated_at = now.isoformat()

    records = audit()
    grouped = group_by_owner(records)
    write_results(grouped, run_date, generated_at)
    published = publish_findings(grouped, run_date, generated_at)

    counts = count_by_classification(records)
    log({'msg': 'Audit complete', 'log_groups': len(records), 'counts': counts,
         'owners': len(grouped), 'alerts_published': published})
    return {
        'statusCode': 200,
        'log_groups': len(records),
        'counts': counts,
        'alerts_published': published,
    }


def log(data):
    """
    Enriches the log message with the current time and prints it to standard out.
    """
    data['time'] = datetime.now().astimezone(tz=timezone.utc).isoformat()
    print(json.dumps(data))
