module "dpc_opt_out_inbound" {
  source                                 = "../../modules/lambda"
  role                                   = module.dpc_opt_out_inbound.opt_out_lambda_role_arn
  iam_role_name                          = "${var.team_name}-${var.environment_name}-opt-out-import-lambda"
  policy_name                            = "${var.team_name}-${var.environment_name}-opt-out-import-lambda"
  s3_object_key                          = "opt-out-import-lambda/lambda_function.zip"
  s3_bucket                              = "lambda-zip-file-storage-${var.account_number}-${var.team_name}"
  vpc_id                                 = module.dpc_opt_out_inbound.vpc_id
  subnet_ids                             = module.dpc_opt_out_inbound.subnet_ids
  security_group_ids                     = module.dpc_opt_out_inbound.common_security_group_ids
  common_security_group_ids              = module.dpc_opt_out_inbound.common_security_group_ids
  team_name                              = var.team_name
  account_number                         = var.account_number
  vpc_subnet_security_group_service_name = var.team_name
  function_name                          = "OptOutImportLambda-${var.environment_name}"
  handler                                = var.lambda_handler
  runtime                                = var.lambda_runtime
  environment_name                       = var.environment_name
  env                                    = var.env                       
  environment_variables = {
    ENV      = var.environment_name
    APP_NAME = "${var.team_name}-${var.environment_name}-opt-out-import-lambda"
    DB_HOST  = "postgres://db.${var.team_name}-${var.environment_name}.local:5432/${var.team_name}_consent"
    AWS_ASSUME_ROLE_ARN = var.team_name == "dpc" ? "arn:aws:iam::${var.bfd_aws_account}:role/bfd-${local.bfd_env}-eft-dpc-bucket-role" : ""
  }
}
