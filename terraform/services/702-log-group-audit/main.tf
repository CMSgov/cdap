locals {
  default_config  = yamldecode(file("${path.module}/config/default.yml"))
  env_config_file = "${path.module}/config/${var.env}.yml"
  env_config      = fileexists(local.env_config_file) ? yamldecode(file(local.env_config_file)) : {}

  default_audit = try(local.default_config.audit, {})
  env_audit     = try(local.env_config.audit, {})

  # exceptions accumulate across default and env, deduplicated
  exceptions = distinct(concat(
    try(local.default_audit.exceptions, []),
    try(local.env_audit.exceptions, [])
  ))

  # name prefixes excluded from the audit entirely, accumulated the same way
  exception_prefixes = distinct(concat(
    try(local.default_audit.exception_prefixes, []),
    try(local.env_audit.exception_prefixes, [])
  ))

  # Published by 701-log-retention
  firehose_arn_ssm_param = "/cdap/${var.env}/common/nonsensitive/log-retention/firehose-arn"

  results_prefix = "results/"
}

data "aws_ssm_parameter" "alarms_topic_arn" {
  name = "/cdap/${var.env}/cdap-alarm-topic/nonsensitive/alarms-topic-arn"
}

module "results_bucket" {
  # Results are point-in-time snapshots regenerated weekly
  source = "../../modules/bucket"

  app  = module.platform.app
  env  = var.env
  name = "cdap-${var.env}-log-group-audit"
}

module "log_group_audit_function" {
  source = "../../modules/function"

  platform               = module.platform
  architecture           = "arm64"
  liveness_check_enabled = true
  description            = "Audits CloudWatch log groups for management through the cloudwatch_log_group module (terraform tag + log-retention subscription filter)"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.14"

  # Weekly, Monday 12:00 UTC
  schedule_expression = "cron(0 12 ? * MON *)"

  source_dir = "${path.module}/lambda_src"
  source_dir_excludes = [
    "test_lambda_function.py",
    "requirements.txt",
    "requirements-dev.txt",
    "Makefile",
    "sonar-project.properties",
    ".venv/**",
    "__pycache__/**",
    ".pytest_cache/**",
    "*.pyc",
    "coverage/**",
    "coverage.xml",
  ]

  ssm_parameter_paths = [local.firehose_arn_ssm_param]

  function_role_inline_policies = {
    log-group-audit = data.aws_iam_policy_document.log_group_audit.json
  }

  environment_variables = {
    ENV                    = var.env
    EXCEPTIONS             = jsonencode(local.exceptions)
    EXCEPTION_PREFIXES     = jsonencode(local.exception_prefixes)
    RESULTS_BUCKET         = module.results_bucket.id
    RESULTS_PREFIX         = local.results_prefix
    SNS_TOPIC_ARN          = data.aws_ssm_parameter.alarms_topic_arn.value
    FIREHOSE_ARN_SSM_PARAM = local.firehose_arn_ssm_param
  }
}
