locals {
  x86_repos = [
    "ab2d",
    "ab2d-website",
    "bcda-app",
    "bcda-ssas-app",
    "bcda-static-site",
    "cdap",
    "dpc-app",
    "dpc-ops",
    "dpc-static-site",
  ]

  arm64_repos = [
    "bcda-app",
    "bcda-ssas-app"
  ]
}

module "standards" {
  source = "../../modules/standards"

  app         = "cdap"
  env         = "mgmt"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/codebuild-projects"
  service     = "codebuild-projects"
  providers   = { aws = aws, aws.secondary = aws.secondary }
}

module "vpc" {
  source = "../../modules/vpc"

  app = "cdap"
  env = "mgmt"
}

module "subnets" {
  source = "../../modules/subnets"

  vpc_id = module.vpc.id
  use    = "private"
}

resource "aws_iam_role" "codebuild" {
  name                 = "codebuild-runner"
  description          = "Service role for CodeBuild runner"
  path                 = "/delegatedadmin/developer/"
  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "codebuild_role_policy" {
  role   = aws_iam_role.codebuild.name
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "secrets_manager_read_write" {
  role       = aws_iam_role.codebuild.name
  policy_arn = data.aws_iam_policy.secrets_manager_read_write.arn
}

resource "aws_iam_role_policy_attachment" "ssm_read_only" {
  role       = aws_iam_role.codebuild.name
  policy_arn = data.aws_iam_policy.ssm_read_only.arn
}

resource "aws_codebuild_project" "this" {
  for_each = toset(local.x86_repos)

  name         = each.key
  description  = "Codebuild project for ${each.key}"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  vpc_config {
    vpc_id  = module.vpc.id
    subnets = module.subnets.ids
    security_group_ids = [
      data.aws_security_group.security_tools.id,
      data.aws_security_group.security_validation_egress.id
    ]
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/CMSgov/${each.key}"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = false
    }
  }

  lifecycle {
    ignore_changes = [
      build_timeout,
      environment[0].compute_type
    ]
  }
}

resource "aws_codebuild_webhook" "this" {
  for_each = toset(local.x86_repos)

  project_name = each.key
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}


# ARM64 Configurations
resource "aws_codebuild_project" "arm64" {
  for_each = toset(local.arm64_repos)

  name         = "${each.key}-arm64"
  description  = "Codebuild project for ${each.key} using arm64"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  vpc_config {
    vpc_id  = module.vpc.id
    subnets = module.subnets.ids
    security_group_ids = [
      data.aws_security_group.security_tools.id,
      data.aws_security_group.security_validation_egress.id
    ]
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/CMSgov/${each.key}"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = false
    }
  }
}

resource "aws_codebuild_webhook" "arm64" {
  for_each = aws_codebuild_project.arm64

  project_name = each.value["name"]
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}
