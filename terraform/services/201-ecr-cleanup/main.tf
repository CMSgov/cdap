locals {
  # Strategies applied to any discovered repo that has no explicit override.
  # Intentionally conservative (opt_in = false → log-only) until a team
  # explicitly opts a repo in below.
  default_strategies = [
    ["count_image", "rls-r", 5],
    ["days_older_than", "", 14],
    ["days_older_than", null, 14]
  ]

  # Only repos needing custom strategies OR real deletion (opt_in = true)
  # need an entry here. Everything else matching the app prefix still gets
  # scanned with default_strategies but stays log-only.
  # FIXME Assume all repos should get swept
  repo_overrides = {
    "dpc-web" = {
      strategies = local.default_strategies
      opt_in     = true
    }
  }
}

module "ecr_cleanup_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=<new-ref>"

  platform     = module.platform
  architecture = "arm64"

  # NOTE: the module now builds the full name as "${platform.app}-${platform.env}-${name}",
  # so pass just the base name — don't pre-prefix it like the old module required.
  name        = "ecr-cleanup"
  description = "Deletes old ECR images while protecting images referenced by active ECS task definitions"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  schedule_expression = "cron(0 6 * * ? *)"

  source_dir = "${path.module}/lambda_src"
  source_dir_excludes = [
    "test.py",
    "test_strategies.py",
    "dry_run.py",
    "dry_run_config.json",
    "requirements.txt",
    "__pycache__/**",
    "*.pyc",
  ]

  function_role_inline_policies = {
    ecr-cleanup = data.aws_iam_policy_document.ecr_cleanup.json
  }

  environment_variables = {
    APP                = var.app
    ENV                = var.env
    DEFAULT_STRATEGIES = jsonencode(local.default_strategies)
    REPO_OVERRIDES     = jsonencode(local.repo_overrides)
  }
}
