locals {
  full_name = "${var.app}-${var.env}-ecr-cleanup"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ecr_cleanup" {
  statement {
    sid = "ECRAccess"
    actions = [
      "ecr:DescribeImages",
      "ecr:BatchDeleteImage",
    ]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
    ]
  }

  statement {
    sid = "ECSReadAccess"
    actions = [
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "SSMAccess"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.app}/${var.env}/ecr-cleanup/*"
    ]
  }
}

resource "aws_ssm_parameter" "repo_list" {
  name        = "/${var.app}/${var.env}/ecr-cleanup/repos"
  type        = "SecureString"
  description = "Comma-separated list of ECR repository names to clean up"
  value       = join(",", var.repo_list)
}

data "archive_file" "ecr_cleanup" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/lambda_function.py"
  output_path = "${path.module}/function.zip"
}

module "ecr_cleanup_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=b177921621c97d02dc4a21f830e4532147aa0749"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Deletes old ECR images while protecting images referenced by active ECS task definitions"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  schedule_expression = "cron(0 6 * * ? *)"

  function_role_inline_policies = {
    ecr-cleanup = data.aws_iam_policy_document.ecr_cleanup.json
  }

  environment_variables = {
    APP = var.app
    ENV = var.env
  }

  source_code_version = aws_s3_object.ecr_cleanup_zip.version_id
}

resource "aws_s3_object" "ecr_cleanup_zip" {
  bucket = module.ecr_cleanup_function.zip_bucket
  key    = "function.zip"
  source = data.archive_file.ecr_cleanup.output_path
  etag   = data.archive_file.ecr_cleanup.output_md5
}
