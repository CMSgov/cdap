resource "aws_ssm_parameter" "test_config" {
  name = "/cdap/test/tftesting/function/testvalue"
  # only setting as secure for testing
  type = "SecureString"
  # not an actually secure string
  value = "tftesting"

  key_id = module.platform.kms_alias_primary.id
}

# This parameter is NOT in ssm_parameter_paths — only accessible via inline policy
resource "aws_ssm_parameter" "inline_policy_test" {
  name   = "/cdap/test/tftesting/function/inline-policy-test"
  type   = "SecureString"
  value  = "inline-policy-access-confirmed"
  key_id = module.platform.kms_alias_primary.id
}

module "tftesting_function" {
  source = "../../../modules/function"

  platform    = module.platform
  name        = "tftesting"
  description = "Ephemeral Lambda for CI/CD integration testing — exercises module features"

  source_dir          = "${path.module}/lambda_src"
  source_dir_excludes = ["**/__pycache__/**", "**/*.pyc", "**/tests/**"]

  handler      = "lambda_function.function_handler"
  runtime      = "python3.11"
  architecture = "arm64"
  timeout      = 30
  memory_size  = 256 # Evaluates non-default memory

  liveness_check_enabled = true

  log_retention_days = 7

  # Exercises environment_variables
  environment_variables = {
    ENVIRONMENT              = "tftesting"
    SSM_PARAM_PATH           = aws_ssm_parameter.test_config.name
    INLINE_POLICY_PARAM_PATH = aws_ssm_parameter.inline_policy_test.name
  }

  # Exercises ssm_parameter_paths
  ssm_parameter_paths = [aws_ssm_parameter.test_config.arn]

  # Exercises schedule_expression — can be set for scheduler testing
  schedule_expression = ""

  # Exercises function_role_inline_policies —
  function_role_inline_policies = {
    "ssm-inline-test" = data.aws_iam_policy_document.ssm_inline_test.json
  }

  # Placeholder if evaluating github_actions_repos for deploys outside of Tofu
  github_actions_repos = []

  # Rollback support
  rollback_version = null # null = track latest published version
}


module "platform" {
  providers = { aws = aws, aws.secondary = aws.secondary }

  source      = "../../../modules/platform"
  app         = "cdap"
  env         = "test"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tftesting/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}
