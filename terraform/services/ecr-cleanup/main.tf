locals {
  full_name = "${var.app}-${var.env}-ecr-cleanup"

  repo_list_by_env = {
    test = ["dpc-web"]
    prod = ["dpc-web"]
  }
  repo_config = {
    "test" : {
      "dpc-web" : {
        "strategies" : [
          ["count_image", "rls-r", 5],
          ["days_older_than", "", 14],
          ["days_older_than", null, 14]
        ],
      "opt_in" : false }
    },
    "prod" : {
      "dpc-web" : {
        "strategies" : [
          ["count_image", "rls-r", 5],
          ["days_older_than", "", 14],
          ["days_older_than", null, 14]
        ],
      "opt_in" : false }
    }
  }
}

data "aws_ecr_repository" "repos" {
  for_each = toset(local.repo_list_by_env[var.env])
  name     = each.key
}

data "aws_iam_policy_document" "ecr_access_policy" {
  statement {
    sid = "ECRListRepositories"
    actions = [
      "ecr:DescribeImages",
      "ecr:DescribeRepositories"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECRImageAccess"
    actions = [
      "ecr:BatchDeleteImage"
    ]
    resources = values(data.aws_ecr_repository.repos)[*].arn
  }
}

data "aws_iam_policy_document" "ecs_access_policy" {
  statement {
    sid = "ECSReadAccess"
    actions = [
      "ecs:ListClusters",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecr_cleanup" {
  source_policy_documents = [
    data.aws_iam_policy_document.ecr_access_policy.json,
    data.aws_iam_policy_document.ecs_access_policy.json,
  ]
}

data "archive_file" "ecr_cleanup" {
  type        = "zip"
  output_path = "${path.module}/function.zip"

  source {
    content  = file("${path.module}/lambda_src/lambda_function.py")
    filename = "lambda_function.py"
  }

  source {
    content  = file("${path.module}/lambda_src/strategies.py")
    filename = "strategies.py"
  }
}

module "ecr_cleanup_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=a7850b1f5df3f7cdaf828b4cbb7dc08a7117d182"

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
    APP         = var.app
    ENV         = var.env
    REPO_CONFIG = jsonencode(local.repo_config[var.env])
  }

}

resource "aws_s3_object" "ecr_cleanup_zip" {
  bucket = module.ecr_cleanup_function.zip_bucket
  key    = "function.zip"
  source = data.archive_file.ecr_cleanup.output_path
  etag   = data.archive_file.ecr_cleanup.output_md5
}

resource "null_resource" "deploy_lambda" {
  triggers = {
    zip_hash = data.archive_file.ecr_cleanup.output_base64sha256
  }

  provisioner "local-exec" {
    command = "aws lambda update-function-code --function-name ${module.ecr_cleanup_function.name} --s3-bucket ${module.ecr_cleanup_function.zip_bucket} --s3-key function.zip"
  }

  depends_on = [aws_s3_object.ecr_cleanup_zip]
}
