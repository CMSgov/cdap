locals {
  default_config  = yamldecode(file("${path.module}/config/default.yml"))
  env_config_file = "${path.module}/config/${var.env}.yml"
  env_config      = fileexists(local.env_config_file) ? yamldecode(file(local.env_config_file)) : {}

  default_cleanup = try(local.default_config.cleanup, {})
  env_cleanup     = try(local.env_config.cleanup, {})

  # env.yml replaces default's strategy list if present
  default_strategies = try(local.env_cleanup.default_strategies, try(local.default_cleanup.default_strategies, []))

  # exclusions accumulate across default and env, deduplicated
  exclusion_list = distinct(concat(
    try(local.default_cleanup.exclusion_list, []),
    try(local.env_cleanup.exclusion_list, [])
  ))

  # repo_overrides merge by repo name — env.yml can add new repos or replace
  # an existing repo's override, but can't patch a single field of one (merge() is shallow)
  repo_overrides = merge(
    try(local.default_cleanup.repo_overrides, {}),
    try(local.env_cleanup.repo_overrides, {})
  )

  opted_in_repos = [
    for name, cfg in local.repo_overrides : name
    if try(cfg.opt_in, false) && !contains(local.exclusion_list, name)
  ]
}


module "ecr_cleanup_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=3464ddc9b34a40818fa865e10bd1fe3e20ae99dd"

  platform               = module.platform
  architecture           = "arm64"
  liveness_check_enabled = true
  description            = "Deletes old ECR images while protecting images referenced by active ECS task definitions"

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
    ENV                = var.env
    DEFAULT_STRATEGIES = jsonencode(local.default_strategies)
    REPO_OVERRIDES     = jsonencode(local.repo_overrides)
    EXCLUSION_LIST     = jsonencode(local.exclusion_list)
  }
}
