locals {
  provider_domain = "token.actions.githubusercontent.com"
}

data "aws_kms_alias" "kms_key" {
  name = "alias/${var.app}-${var.env}"
}

# Only used when source_dir is provided
data "archive_file" "function" {
  count = var.source_dir != null ? 1 : 0

  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.terraform/tmp/${var.name}-function.zip"
  excludes    = var.source_dir_excludes
}

module "zip_bucket" {
  source = "../bucket"

  additional_bucket_policies = length(var.github_actions_repos) > 0 ? [data.aws_iam_policy_document.cicd_manage_lambda_objects.json] : []
  app                        = var.app
  env                        = var.env
  name                       = "${var.name}-function"
  ssm_parameter              = "/${var.app}/${var.env}/${var.name}-bucket"
}

# Managed zip upload — used when source_dir is provided
resource "aws_s3_object" "function_zip" {
  count = var.source_dir != null ? 1 : 0

  bucket = module.zip_bucket.id
  key    = "function.zip"
  source = data.archive_file.function[0].output_path

  # Use the hash so S3 object (and Lambda) updates when source changes
  source_hash = data.archive_file.function[0].output_base64sha256

  # KMS encryption
  kms_key_id = data.aws_kms_alias.kms_key.target_key_arn
}

resource "aws_s3_object" "empty_function_zip" {
  count = var.source_dir == null && length(var.github_actions_repos) == 0 ? 1 : 0

  bucket = module.zip_bucket.id
  key    = "function.zip"
  source = "${path.module}/dummy_function.zip"
}

module "vpc" {
  source = "../vpc"

  app = var.app
  env = var.env
}

module "subnets" {
  source = "../subnets"

  vpc_id = module.vpc.id
}

resource "aws_security_group" "function" {
  name        = "${var.name}-function"
  description = "For the ${var.name} function"
  vpc_id      = module.vpc.id
}

resource "aws_vpc_security_group_egress_rule" "ipv4" {
  for_each = {
    for idx, rule in var.egress_rules : tostring(idx) => rule
    if rule.cidr_ipv4 != null
  }

  security_group_id = aws_security_group.function.id
  cidr_ipv4         = each.value.cidr_ipv4
  ip_protocol       = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  description       = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "ipv6" {
  for_each = {
    for idx, rule in var.egress_rules : tostring(idx) => rule
    if rule.cidr_ipv6 != null
  }

  security_group_id = aws_security_group.function.id
  cidr_ipv6         = each.value.cidr_ipv6
  ip_protocol       = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  description       = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "sg_source" {
  for_each = {
    for idx, rule in var.egress_rules : tostring(idx) => rule
    if rule.referenced_sg_id != null
  }

  security_group_id            = aws_security_group.function.id
  referenced_security_group_id = each.value.referenced_sg_id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  description                  = each.value.description
}

resource "aws_lambda_function" "this" {
  description   = var.description
  function_name = var.name
  s3_key        = "function.zip"
  s3_bucket     = module.zip_bucket.id
  # If source_dir is managed by this module, track the uploaded object version.
  # Otherwise, fall back to the externally-supplied version (or null).
  s3_object_version = var.source_dir != null ? aws_s3_object.function_zip[0].version_id : var.source_code_version
  kms_key_arn       = data.aws_kms_alias.kms_key.target_key_arn
  role              = aws_iam_role.function.arn
  handler           = var.handler
  runtime           = var.runtime
  timeout           = var.timeout
  memory_size       = var.memory_size
  layers            = var.layer_arns
  architectures     = [var.architecture]

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

  name                = "${var.name}-function"
  description         = "Trigger ${var.name} function"
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
  name              = "/aws/lambda/${var.name}"
  kms_key_id        = data.aws_kms_alias.kms_key.target_key_arn
  skip_destroy      = strcontains(var.env, "prod") ? true : false
  retention_in_days = var.log_retention_days
}
