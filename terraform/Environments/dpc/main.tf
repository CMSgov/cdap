module "dpc_opt_out_lambda" {
  source                   = "../../modules/lambda_opt_out"
  role                     = module.dpc_opt_out_lambda.opt_out_lambda_role_arn
  iam_role_name            =  "${var.environment}-${var.env}-opt-out-import-lambda"
  policy_name              = "${var.environment}-${var.env}-opt-out-import-lambda"
  key_description          = "${var.environment}-${var.env}-opt-out-import-env-vars"
  kms_alias_name           = "alias/${var.environment}-${var.env}-opt-out-import-env-vars"
  s3_object_key            = "opt-out-import-lambda/lambda_function.zip"
  s3_bucket                =  "lambda-zip-file-storage-${var.account_number}-${var.environment}"
  vpc_id                   = module.dpc_opt_out_lambda.vpc_id
  subnet_ids               = module.dpc_opt_out_lambda.subnet_ids
  security_group_ids       =  module.dpc_opt_out_lambda.common_security_group_ids
  common_security_group_ids = module.dpc_opt_out_lambda.common_security_group_ids
  environment               = "dpc"
  account_number            = var.account_number
  vpc_subnet_security_group_service_name = "dpc"
  function_name             = "dpcOptOutImportLambda-${var.env}"
  kms_key_arn               = module.dpc_opt_out_lambda.opt_out_lambda_kms_key_arn
  handler                   = "main" 
  runtime                   = "go1.x"
  environment_variables     = {
      ENV = var.env
      APP_NAME = "${var.environment}-${var.env}-opt-out-import-lambda"
      DB_HOST = "postgres://db.${var.environment}-${var.env}.local:5432/${var.environment}_consent"
    } 
  }
