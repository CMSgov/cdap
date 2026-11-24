# 702-log-group-audit

Provisions a weekly Lambda (one per CDAP account: test and prod) that audits
every CloudWatch log group in the account for management through the standard
[cloudwatch_log_group module](../../modules/cloudwatch_log_group), which
guarantees the `terraform = true` platform tag and a subscription filter
routing logs to the account's long-term retention Firehose (see
[701-log-retention](../701-log-retention)).

## How it works

Every Monday at 12:00 UTC, the Lambda:

1. Enumerates all log groups in the account (`logs:DescribeLogGroups`),
   skipping any whose name matches a config-managed **exception prefix**
   (CMS Cloud-managed groups like `cms-cloud-*` that CDAP teams cannot act
   on); skipped groups appear nowhere in results, counts, or alerts.
2. Bulk-fetches tags via the Resource Groups Tagging API
   (`tag:GetResources`) and checks for the `terraform = true` tag applied by
   the platform module's `default_tags`.
3. Reads the account's log-retention Firehose ARN at runtime from
   `/cdap/<env>/common/nonsensitive/log-retention/firehose-arn` and checks
   each log group's subscription filters (`logs:DescribeSubscriptionFilters`)
   for a filter delivering to it.
4. Classifies each log group:
   - **`exception`**: name matches the config-managed exceptions list
     (checked first; e.g. the Firehose's own diagnostics log group, which
     would create a delivery loop if subscribed)
   - **`unmanaged`**: no `terraform = true` tag (highest severity: not
     provisioned via Tofu at all)
   - **`misconfigured`**: tagged, but the retention subscription filter is
     missing or points at the wrong destination
   - **`compliant`**: tagged and correctly routed
5. Resolves the owning **app** by delimiter-bounded match (`-`, `/`, `_`, or
   string boundary) against `ab2d|bcda|dpc|cdap` in the log group name,
   defaulting to `cdap` with an `app_fallback: true` flag when no token is
   found. Resolves **env** the same way against `dev|test|sandbox|prod`
   (bounded matching handles ephemeral prefixes like `ephemeral-dev`),
   defaulting to the account's own env with `env_fallback: true`.
6. Writes **full results** (all classifications, not just findings) to the
   results bucket, partitioned so each app can find its own findings:
   - `results/app=<app>/env=<env>/date=<YYYY-MM-DD>/log-groups.json`
   - `results/summary/date=<YYYY-MM-DD>/summary.json` (account-wide counts)
7. Publishes **one SNS message per (app, env) with findings** (unmanaged or
   misconfigured) to the CDAP alarm topic, shaped like a CloudWatch alarm
   (`AlarmName: <app>-<env>-log-group-audit`, `NewStateValue: ALARM`,
   `NewStateReason` with counts and affected names) so
   [201-alarm-to-slack](../201-alarm-to-slack) routes it to the owning team's
   Slack channel. Clean (app, env) pairs produce no message.

A deploy-time liveness check (`{"RequestType": "LivenessCheck"}`, invoked by
the function module's `aws_lambda_invocation`) verifies required configuration
and that the Firehose ARN parameter is readable, failing the Tofu apply
otherwise.

Nothing sensitive leaves the function: CloudWatch log output, Slack alert
text, and error messages all pass through a scrubber that masks anything
shaped like a 12-digit AWS account ID, and ARNs are never logged.

## Adding an exception

Two mechanisms, both in `config/default.yml` (all envs) or `config/<env>.yml`
(one env); lists accumulate across files and are deduplicated:

- `audit.exceptions` — exact log group names. The group is still audited and
  appears in results with classification `exception`. Use for CDAP-owned
  groups that must not be routed (e.g. the Firehose's own diagnostics group).
- `audit.exception_prefixes` — name prefixes. Matching groups are excluded
  from the audit entirely (no results, counts, or alerts). Use for groups
  CDAP cannot act on (CMS Cloud tooling, golden-image agent logs, AWS
  service defaults).

Document why each entry is exempt with a comment.

## Limiting Slack alerts

`audit.notification_apps` in `config/default.yml` (all envs) or
`config/<env>.yml` (one env) controls which teams' findings alerts are
published:

- key absent: alerts for every app (normal operation)
- `notification_apps: []`: all alerts suppressed
- `notification_apps: ["cdap"]`: alerts only for the listed apps

The audit always runs and writes full results to S3, and each suppressed
alert is logged by the Lambda.

## What this creates

- The audit Lambda via the [function module](../../modules/function)
  (python3.14, arm64, weekly EventBridge schedule), with an inline IAM policy
  limited to read-only discovery (`logs:DescribeLogGroups`,
  `logs:DescribeSubscriptionFilters`, `tag:GetResources`), `s3:PutObject`
  scoped to the results prefix, and `sns:Publish` scoped to the alarm topic
- A results bucket via the [bucket module](../../modules/bucket)
  (`cdap-<env>-log-group-audit`). Results are point-in-time snapshots
  partitioned by date and retained indefinitely as an audit trail

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

No requirements.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_log_group_audit_function"></a> [log\_group\_audit\_function](#module\_log\_group\_audit\_function) | ../../modules/function | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |
| <a name="module_results_bucket"></a> [results\_bucket](#module\_results\_bucket) | ../../modules/bucket | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy_document.alarm_publish](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.log_group_audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.results_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.alarms_topic_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the log group audit Lambda function |
| <a name="output_results_bucket"></a> [results\_bucket](#output\_results\_bucket) | Bucket holding audit results, partitioned by app and env |
<!-- END_TF_DOCS -->
