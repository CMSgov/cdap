locals {
  arm64_image               = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
  x86_image                 = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
  arm64_changeover_projects = var.app == "bcda" ? ["bcda-app", "bcda-ssas-app"] : []

  repos = [
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
}

module "standards" {
  source = "../../modules/standards"

  app         = "cdap"
  env         = var.app == "bcda" ? "mgmt" : var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/codebuild-projects"
  service     = "codebuild-projects"
  providers   = { aws = aws, aws.secondary = aws.secondary }
}

# IAM

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

# Network
resource "aws_security_group" "codebuild_project" {
  for_each = var.app == "cdap" ? toset(local.repos) : toset([])

  name = "${each.key}-${module.standards.account_env_suffix}-codebuild-project"

  description = "For the ${module.standards.account_env_suffix} ${each.key}"
  vpc_id      = module.standards.cdap_vpc.id
}

resource "aws_vpc_security_group_egress_rule" "codebuild_project" {
  for_each = aws_security_group.codebuild_project

  security_group_id = aws_security_group.codebuild_project[each.key].id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "tcp"
  to_port     = 0
}

# TODO: To deprecate cdap-mgmt runners remove conditional logic for vpc_id and set to use standards module only.
module "subnets" {
  source = "../../modules/subnets"

  vpc_id = var.app == "bcda" ? module.vpc[0].id : module.standards.cdap_vpc.id
  use    = "private"
}

## TO DO: Delete cdap-mgmt codebuilder runners that are managed through bcda-prod terraform and use the cdap-mgmt VPC.
## Remove all blocks from here until the "per_repo" resource instantiations
module "vpc" {
  count  = var.app == "bcda" ? 1 : 0
  source = "../../modules/vpc"

  app = "cdap"
  env = "mgmt"
}


resource "aws_codebuild_project" "this" {
  for_each = var.app == "bcda" ? toset(local.repos) : toset([])

  name         = each.key
  description  = "Codebuild project for ${each.key}"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = local.x86_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  vpc_config {
    vpc_id  = module.vpc[0].id
    subnets = module.subnets.ids
    security_group_ids = [
      data.aws_security_group.security_tools.id,
      data.aws_security_group.security_validation_egress[0].id
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
  for_each = aws_codebuild_project.this

  project_name = each.key
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

# ARM64 Configurations that were established before migrating towards a cdap-test and cdap-prod managed codebuild project
# Moving from these will require code change in bcda-app and bcda-ssas-app

resource "aws_codebuild_project" "arm64" {
  for_each = var.app == "bcda" ? toset(local.arm64_changeover_projects) : toset([])

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
    vpc_id  = module.vpc[0].id
    subnets = module.subnets.ids
    security_group_ids = [
      data.aws_security_group.security_tools.id,
      data.aws_security_group.security_validation_egress[0].id
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

## Maintain the following after cdap-mgmt deprecation:
# Create cdap-test and cdap-prod resources separately for direct deprecation of old resources by block deletion without more code change

resource "aws_codebuild_project" "per_repo" {
  for_each = var.app == "cdap" ? toset(local.repos) : toset([])

  name         = "${each.key}-${module.standards.account_env_suffix}"
  description  = "Codebuild project for ${each.key}"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = local.arm64_image
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  vpc_config {
    vpc_id  = module.standards.cdap_vpc.id
    subnets = module.subnets.ids
    security_group_ids = [
      data.aws_security_group.security_tools.id,
      aws_security_group.codebuild_project[each.key].id
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

resource "aws_codebuild_webhook" "per_repo" {
  for_each = aws_codebuild_project.per_repo

  project_name = "${each.key}-${module.standards.account_env_suffix}"
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}


