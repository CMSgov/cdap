module "ab2d_opt_out_lambda" {
  source                  = "../../lambda_opt_out"
  role                    = module.ab2d_opt_out_lambda.opt_out_lambda_role_arn
  iam_role_name           =  "${var.service_name}-${var.env}-opt-out-import-lambda"
  policy_name             = "${var.service_name}-${var.env}-opt-out-import-lambda"
  policy_description      = "Beneficiary Opt-Out Lambda Policy"
  key_description         = "${var.service_name}-${var.env}-opt-out-import-env-vars"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  kms_alias_name          = "alias/${var.service_name}-${var.env}-opt-out-import-env-vars"
  filename                = "/tmp/setup/optout/build/distributions/optout.zip"
  source_code_hash = filebase64sha256("/tmp/setup/optout/build/distributions/optout.zip")
  vpc_subnet_security_group_service_name  = "dpc"
  service_name            =   "ab2d"     
  function_name = "OptOutHandler"
  description   = "Ingests the most recent beneficiary opt-out list from BFD"
  kms_key_arn      = module.ab2d_opt_out_lambda.opt_out_lambda_kms_key_arn
  handler     = "gov.cms.${var.service_name}.optout.OptOutHandler"
  runtime     = "java11"
  timeout     = 900
  memory_size = 128
  vpc_id                 = module.ab2d_opt_out_lambda.vpc_id
 subnet_ids             = module.ab2d_opt_out_lambda.subnet_ids
 security_group_ids = module.ab2d_opt_out_lambda.common_security_group_ids
 common_security_group_ids = module.ab2d_opt_out_lambda.common_security_group_ids
  environment_variables = {
    "com.amazonaws.sdk.disableCertChecking" = true
    IS_LOCALSTACK                           = true
    environment                             = "local"
    JAVA_TOOL_OPTIONS                       = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
    DB_URL                                  = "jdbc:postgresql://host.docker.internal:5432/${var.service_name}"
    DB_USERNAME                             = "${var.service_name}"
    DB_PASSWORD                             = "${var.service_name}"
  }
}
