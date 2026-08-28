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
    "cdap-tftesting-service" = {
      strategies = [
        ["count_image", "", 3],
        ["days_older_than", null, 2]
      ]
      opt_in = true
    }
  }
}

module "ecr_cleanup_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=3464ddc9b34a40818fa865e10bd1fe3e20ae99dd"

  platform     = module.platform
  architecture = "arm64"

  description = "Deletes old ECR images while protecting images referenced by active ECS task definitions"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  schedule_expression = "cron(0 6 * * ? *)"

  source_dir = "${path.module}/lambda_src"
  source_dir_excludes = [
    "test.py",
    "test_strategies.py",
    "test_lambda_function.py",
    "dry_run.py",
    "dry_run_config.json",
    "requirements.txt",
    "requirements-dev.txt",
    "Makefile",
    ".venv/**",
    "__pycache__/**",
    ".pytest_cache/**",
    "*.pyc",
    "coverage.xml",
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
