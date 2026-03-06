locals {
  arm64_image               = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
  x86_image                 = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
  account_env_suffix        = var.app == "cdap" ? (var.env == "prod" || var.env == "sandbox" ? "-prod" : "-non-prod") : ""
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

  arm64_evaluation_repos = [
    "bcda-app",
    "bcda-ssas-app"
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

module "vpc" {
  source = "../../modules/vpc"

  app = "cdap"
  env = var.app == "bcda" ? "mgmt" : var.env
}

module "subnets" {
  source = "../../modules/subnets"

  vpc_id = var.app == "bcda" ? module.vpc.id : module.standards.cdap_vpc.id
  use    = "private"
}

resource "aws_security_group" "codebuild_project" {
  for_each = toset(local.repos)

  name = "${each.key}-codebuild-project"

  description = "For the ${local.account_env_suffix} ${each.key}"
  vpc_id      = module.vpc.id
}

resource "aws_vpc_security_group_egress_rule" "codebuild_project" {
  for_each          = toset(local.repos)
  security_group_id = aws_security_group.codebuild_project[each.key].id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "tcp"
  to_port     = 0
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
  for_each = toset(local.repos)

  name         = "${each.key}${local.account_env_suffix}"
  description  = "Codebuild project for ${each.key}"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = var.app == "bcda" ? local.x86_image : local.arm64_image
    type                        = var.app == "bcda" ? "LINUX_CONTAINER" : "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  vpc_config {
    vpc_id             = var.app == "bcda" ? module.vpc.id : module.standards.cdap_vpc.id
    subnets            = module.subnets.ids
    security_group_ids = local.codebuild_project_security_group_ids
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
  for_each = toset(local.repos)

  project_name = "${each.key}${local.account_env_suffix}"
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
  for_each = toset(local.arm64_evaluation_repos)

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
