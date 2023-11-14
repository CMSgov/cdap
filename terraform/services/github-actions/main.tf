data "aws_vpc" "managed" {
  filter {
    name   = "tag:Name"
    values = ["bcda-managed-vpc"]
  }
}

data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.managed.id]
  }
  tags = {
    Layer = "app"
  }
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

resource "aws_iam_policy" "runner" {
  name = "github-actions-runner"

  description = "Runner has access to everything within the permissions boundary to allow for terraform and other deploy steps"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOT
}

data "aws_security_group" "vpn" {
  filter {
    name   = "description"
    values = ["bcda-managed-vpn-private"]
  }
}

module "github-actions" {
  source  = "philips-labs/github-runner/aws"
  version = "4.1.1"

  aws_region = "us-east-1"
  vpc_id     = data.aws_vpc.managed.id
  subnet_ids = data.aws_subnets.app.ids

  github_app = {
    key_base64     = var.key_base64
    id             = var.app_id
    webhook_secret = var.webhook_secret
  }

  webhook_lambda_zip                = "lambdas-download/webhook.zip"
  runner_binaries_syncer_lambda_zip = "lambdas-download/runner-binaries-syncer.zip"
  runners_lambda_zip                = "lambdas-download/runners.zip"

  ami_owners = [var.ami_account]
  ami_filter = {
    name  = [var.ami_filter],
    state = ["available"]
  }

  role_path                 = "/delegatedadmin/developer/"
  role_permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn

  enable_ssm_on_runners = true

  idle_config = [{
   cron             = "* * 9-17 * * 1-5"
   timeZone         = "America/New_York"
   idleCount        = 2
   evictionStrategy = "oldest_first"
  }]

  runner_iam_role_managed_policy_arns  = [aws_iam_policy.runner.arn]
  runner_additional_security_group_ids = [data.aws_security_group.vpn.id]

  instance_target_capacity_type = "on-demand"
  instance_types = [
    "t3.medium",
  ]
}
