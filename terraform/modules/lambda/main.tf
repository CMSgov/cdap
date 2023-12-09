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
  description             = "For ${var.function_name} lambda to decrypt and encrypt environment variables"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "env_vars" {
  name          = "alias/${var.function_name}-env-vars"
  target_key_id = aws_kms_key.env_vars.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    actions   = ["ec2:DescribeAccountAttributes"]
    resources = ["*"]
  }
  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
    ]
    resources = [aws_kms_key.env_vars.arn]
  }
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ssm:GetParameters",
    ]
    resources = ["arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter/*"]
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
}

resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = length(var.lambda_role_managed_policy_arns)
  role       = aws_iam_role.lambda.name
  policy_arn = element(var.lambda_role_managed_policy_arns, count.index)
}

resource "aws_s3_bucket" "lambda_zip_file" {
  bucket_prefix = "${var.function_name}-lambda-"
}

resource "aws_s3_bucket_versioning" "lambda_zip_file" {
  bucket = aws_s3_bucket.lambda_zip_file.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "lambda" {
  count = length(var.security_group_ids) > 0 ? 0 : 1

  name        = "${var.function_name}-lambda"
  description = "For the ${var.function_name} lambda"
  vpc_id      = var.vpc_id

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
  s3_bucket     = aws_s3_bucket.lambda_zip_file.id
  role          = aws_iam_role.lambda.arn
  handler       = var.handler
  runtime       = var.runtime
  kms_key_arn   = aws_kms_key.env_vars.arn

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : [aws_security_group.lambda[0].id]
  }

  environment {
    variables = var.environment_variables
  }
}
