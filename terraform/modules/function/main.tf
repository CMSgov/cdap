locals {
  provider_domain = "token.actions.githubusercontent.com"
  app             = var.platform.app
  env             = var.platform.env

  full_name_string = "${local.app}-${local.env}-${var.name}"

  # null = use latest S3 version; set = pin to a specific prior version
  lambda_s3_object_version = var.rollback_version != null ? var.rollback_version : (var.source_dir != null ?
  aws_s3_object.function_zip[0].version_id : var.source_code_version)

  lambda_common = {
    description       = var.description
    function_name     = local.full_name_string
    s3_key            = "function.zip"
    s3_bucket         = module.zip_bucket.id
    s3_object_version = local.lambda_s3_object_version
    kms_key_arn       = var.platform.kms_alias_primary.target_key_arn
    role              = aws_iam_role.function.arn
    handler           = var.handler
    runtime           = var.runtime
    timeout           = var.timeout
    memory_size       = var.memory_size
    layers            = var.layer_arns
    architectures     = [var.architecture]
  }

  lambda_function_arn              = var.dd_enabled ? module.lambda-datadog[0].arn : aws_lambda_function.this[0].arn
  lambda_function_name             = var.dd_enabled ? module.lambda-datadog[0].function_name : aws_lambda_function.this[0].function_name
  lambda_function_version          = var.dd_enabled ? module.lambda-datadog[0].version : aws_lambda_function.this[0].version
  lambda_function_s3_version       = var.dd_enabled ? module.lambda-datadog[0].s3_object_version : aws_lambda_function.this[0].s3_object_version
  lambda_function_source_code_hash = var.dd_enabled ? module.lambda-datadog[0].source_code_hash : aws_lambda_function.this[0].source_code_hash
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

module "lambda-datadog" {
  count   = var.dd_enabled ? 1 : 0  # Only create if using Datadog Lambda module (var.dd_enabled = true)
  source  = "DataDog/lambda-datadog/aws"
  version = "4.7.0"

  environment_variables = merge(var.environment_variables, {
    "DD_API_KEY_SSM_ARN" : data.aws_ssm_parameter.dd_api_key.arn
    "DD_ENV" : local.env
    "DD_SERVICE" : local.app
    "DD_SITE" : "ddog-gov.com"
    "DD_VERSION" : var.source_code_version
    "DD_SERVERLESS_LOGS_ENABLED" : false
    "DD_LAMBDA_HANDLER" : var.handler
  })

  datadog_extension_layer_version = var.dd_extension_layer_version
  datadog_python_layer_version    = startswith(var.runtime, "python") ? var.dd_python_layer_version : null
  datadog_node_layer_version      = startswith(var.runtime, "nodejs") ? var.dd_node_layer_version : null
  datadog_java_layer_version      = startswith(var.runtime, "java") ? var.dd_java_layer_version : null
  datadog_ruby_layer_version      = startswith(var.runtime, "ruby") ? var.dd_ruby_layer_version : null
  datadog_dotnet_layer_version    = startswith(var.runtime, "dotnet") ? var.dd_dotnet_layer_version : null

  description       = local.lambda_common.description
  function_name     = local.lambda_common.function_name
  s3_key            = local.lambda_common.s3_key
  s3_bucket         = local.lambda_common.s3_bucket
  s3_object_version = local.lambda_common.s3_object_version
  kms_key_arn       = local.lambda_common.kms_key_arn
  role              = local.lambda_common.role
  handler           = local.lambda_common.handler
  runtime           = local.lambda_common.runtime
  timeout           = local.lambda_common.timeout
  memory_size       = local.lambda_common.memory_size
  layers            = local.lambda_common.layers
  architectures     = local.lambda_common.architectures

  tracing_config_mode           = "Active"
  vpc_config_subnet_ids         = module.subnets.ids
  vpc_config_security_group_ids = [aws_security_group.function.id]
}

resource "aws_lambda_function" "this" {
  count             = var.dd_enabled ? 0 : 1  # Only create if NOT using Datadog Lambda module (var.dd_enabled = false)
  description       = local.lambda_common.description
  function_name     = local.lambda_common.function_name
  s3_key            = local.lambda_common.s3_key
  s3_bucket         = local.lambda_common.s3_bucket
  s3_object_version = local.lambda_common.s3_object_version
  kms_key_arn       = local.lambda_common.kms_key_arn
  role              = local.lambda_common.role
  handler           = local.lambda_common.handler
  runtime           = local.lambda_common.runtime
  timeout           = local.lambda_common.timeout
  memory_size       = local.lambda_common.memory_size
  layers            = local.lambda_common.layers
  architectures     = local.lambda_common.architectures

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

  arn  = local.lambda_function_arn
  rule = aws_cloudwatch_event_rule.this[0].name
}

resource "aws_lambda_permission" "cloudwatch_events" {
  count = var.schedule_expression != "" ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_function_name
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
  function_name = local.lambda_function_name

  triggers = {
    s3_version = local.lambda_function_s3_version
  }

  input = jsonencode({
    RequestType = "LivenessCheck"
  })
}
