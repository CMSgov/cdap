data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "env_vars" {
  description         = "For ${var.function_name} lambda to decrypt and encrypt environment variables"
  enable_key_rotation = true
}

resource "aws_kms_alias" "env_vars" {
  name          = "alias/${var.function_name}-env-vars"
  target_key_id = aws_kms_key.env_vars.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeNetworkInterfaces",
      "kms:Decrypt",
      "kms:Encrypt",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "ssm:GetParameters",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-lambda"
  path = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  inline_policy {
    name   = "default-lambda"
    policy = data.aws_iam_policy_document.lambda_inline.json
  }

  dynamic "inline_policy" {
    for_each = var.lambda_role_inline_policies
    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }
}

# Prod and sbx deploy roles are only needed in the test environment
data "aws_ssm_parameter" "prod_deploy_role_arn" {
  count = var.env == "test" ? 1 : 0
  name  = "/${var.app}/prod/deploy-role-arn"
}

data "aws_ssm_parameter" "sbx_deploy_role_arn" {
  count = var.env == "test" ? 1 : 0
  name  = "/${var.app}/sbx/deploy-role-arn"
}

module "zip_bucket" {
  source = "../bucket"

  name = "${var.function_name}-lambda"
  cross_account_read_roles = var.env == "test" ? [
    data.aws_ssm_parameter.prod_deploy_role_arn[0].value,
    data.aws_ssm_parameter.sbx_deploy_role_arn[0].value,
  ] : []
}

resource "aws_s3_object" "empty_function_zip" {
  count = var.create_function_zip ? 1 : 0

  bucket = module.zip_bucket.id
  key    = "function.zip"
  source = "${path.module}/dummy_function.zip"

  # This resource only exists to initialize the function, not manage it
  lifecycle {
    ignore_changes = all
  }
}

module "vpc" {
  source = "../vpc"

  app = var.app
  env = var.env
}

module "subnets" {
  source = "../subnets"

  vpc_id = module.vpc.id
  app    = var.app
  layer  = "data"
}

resource "aws_security_group" "lambda" {
  count = length(var.security_group_ids) > 0 ? 0 : 1

  name        = "${var.function_name}-lambda"
  description = "For the ${var.function_name} lambda"
  vpc_id      = module.vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lambda_function" "this" {
  description   = var.function_description
  function_name = var.function_name
  s3_key        = "function.zip"
  s3_bucket     = module.zip_bucket.id
  role          = aws_iam_role.lambda.arn
  handler       = var.handler
  runtime       = var.runtime
  kms_key_arn   = aws_kms_key.env_vars.arn

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = module.subnets.ids
    security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : [aws_security_group.lambda[0].id]
  }

  environment {
    variables = var.environment_variables
  }
}
