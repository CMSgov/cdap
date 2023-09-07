module "ab2d_opt_out_lambda" {
  source                   = "../../modules/lambda_opt_out"
  role                     = module.ab2d_opt_out_lambda.opt_out_lambda_role_arn
  iam_role_name            =  "${var.environment}-${var.env}-opt-out-import-lambda"
  policy_name              = "${var.environment}-${var.env}-opt-out-import-lambda"
  key_description          = "${var.environment}-${var.env}-opt-out-import-env-vars"
  kms_alias_name           = "alias/${var.environment}-${var.env}-opt-out-import-env-vars"
  s3_object_key            = "/tmp/setup/optout/build/distributions/optout.zip"
  s3_bucket                = "lambda-zip-file-storage-${var.account_number}-${var.environment}"
  vpc_subnet_security_group_service_name  = "dpc"
  environment              =   var.environment 
  account_number           =    var.account_number
  function_name            = "OptOutHandler"
  kms_key_arn              = module.ab2d_opt_out_lambda.opt_out_lambda_kms_key_arn
  handler                  = "gov.cms.${var.environment}.optout.OptOutHandler"
  runtime                  = "java11"
  vpc_id                   = module.ab2d_opt_out_lambda.vpc_id
 subnet_ids                = module.ab2d_opt_out_lambda.subnet_ids
 security_group_ids        = module.ab2d_opt_out_lambda.common_security_group_ids
 common_security_group_ids = module.ab2d_opt_out_lambda.common_security_group_ids
  environment_variables    = {
    "com.amazonaws.sdk.disableCertChecking" = true
    IS_LOCALSTACK                           = true
    environment                             = "local"
    JAVA_TOOL_OPTIONS                       = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
    DB_URL                                  = "jdbc:postgresql://host.docker.internal:5432/${var.environment}"
    DB_USERNAME                             = "${var.environment}"
    DB_PASSWORD                             = "${var.environment}"
  }
}
