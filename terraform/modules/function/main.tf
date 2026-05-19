locals {
  provider_domain = "token.actions.githubusercontent.com"
  app             = var.platform.app
  env             = var.platform.env

  full_name_string = "${local.app}-${local.env}-${var.name}"
}

# Only used when source_dir is provided
data "archive_file" "function" {
  count = var.source_dir != null ? 1 : 0

  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.terraform/tmp/${local.full_name_string}-function.zip"
  excludes    = var.source_dir_excludes
}

module "zip_bucket" {
  source = "../bucket"

  additional_bucket_policies = length(var.github_actions_repos) > 0 ? [data.aws_iam_policy_document.cicd_manage_lambda_objects.json] : []
  app                        = local.app
  env                        = local.env
  name                       = "${local.full_name_string}-function"
  ssm_parameter              = "/${local.app}/${local.env}/${var.name}-bucket"
}

# Managed zip upload — used when source_dir is provided
resource "aws_s3_object" "function_zip" {
  count = var.source_dir != null ? 1 : 0

  bucket      = module.zip_bucket.id
  key         = "function.zip"
  source      = data.archive_file.function[0].output_path
  source_hash = data.archive_file.function[0].output_base64sha256
  kms_key_id  = var.platform.kms_alias_primary.target_key_arn
}

resource "aws_s3_object" "empty_function_zip" {
  count = var.source_dir == null && length(var.github_actions_repos) == 0 ? 1 : 0

  bucket = module.zip_bucket.id
  key    = "function.zip"
  source = "${path.module}/dummy_function.zip"
}

module "vpc" {
  source = "../vpc"

  app = local.app
  env = local.env
}

module "subnets" {
  source = "../subnets"

  vpc_id = module.vpc.id
}

resource "aws_lambda_function" "this" {
  description   = var.description
  function_name = local.full_name_string
  s3_key        = "function.zip"
  s3_bucket     = module.zip_bucket.id
  # null = use latest S3 version; set = pin to a specific prior version
  s3_object_version = var.rollback_version != null ? var.rollback_version : (var.source_dir != null ?
  aws_s3_object.function_zip[0].version_id : var.source_code_version)

  kms_key_arn   = var.platform.kms_alias_primary.target_key_arn
  role          = aws_iam_role.function.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  layers        = var.layer_arns
  architectures = [var.architecture]

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = module.subnets.ids
    security_group_ids = [aws_security_group.function.id]
  }

  environment {
    variables = var.environment_variables
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  count = var.schedule_expression != "" ? 1 : 0

  name                = "${local.full_name_string}-function"
  description         = "Trigger ${local.full_name_string} function"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.schedule_expression != "" ? 1 : 0

  arn  = aws_lambda_function.this.arn
  rule = aws_cloudwatch_event_rule.this[0].name
}

resource "aws_lambda_permission" "cloudwatch_events" {
  count = var.schedule_expression != "" ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}

# Manage cloudwatch log group to ensure compliant
resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.full_name_string}"
  kms_key_id        = var.platform.kms_alias_primary.target_key_arn
  skip_destroy      = strcontains(local.env, "prod") ? true : false
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_invocation" "liveness_check" {
  count         = var.liveness_check_enabled ? 1 : 0
  function_name = aws_lambda_function.this.function_name

  triggers = {
    s3_version = aws_lambda_function.this.s3_object_version
  }

  input = jsonencode({
    RequestType = "LivenessCheck"
  })
}
