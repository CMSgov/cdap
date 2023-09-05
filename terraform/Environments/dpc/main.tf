module "dpc_opt_out_lambda" {
  source           = "../../lambda_opt_out"
  role                    = module.dpc_opt_out_lambda.opt_out_lambda_role_arn
  iam_role_name           =  "${var.service_name}-${var.env}-opt-out-import-lambda"
  policy_name             = "${var.service_name}-${var.env}-opt-out-import-lambda"
  policy_description = "Beneficiary Opt-Out Lambda Policy" 
  key_description         = "${var.service_name}-${var.env}-opt-out-import-env-vars"
  deletion_window_in_days = 10
  enable_key_rotation =  true
  kms_alias_name          = "alias/${var.service_name}-${var.env}-opt-out-import-env-vars"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  vpc_id                 = module.dpc_opt_out_lambda.vpc_id
  subnet_ids             = module.dpc_opt_out_lambda.subnet_ids
  security_group_ids     =  module.dpc_opt_out_lambda.common_security_group_ids
  common_security_group_ids = module.dpc_opt_out_lambda.common_security_group_ids
  service_name     = "dpc"
  vpc_subnet_security_group_service_name = "dpc"
  function_name    = local.lambda_name
  description      = "Ingests the most recent beneficiary opt-out list from BFD"
  kms_key_arn      = module.dpc_opt_out_lambda.opt_out_lambda_kms_key_arn
  handler          = "main" 
  runtime          = "go1.x"
  timeout          = 900
  memory_size      = 128
  environment_variables = {
      ENV = var.env
      APP_NAME = "${var.service_name}-${var.env}-opt-out-import-lambda"
      DB_HOST = "postgres://db.${var.service_name}-${var.env}.local:5432/${var.service_name}_consent"
    } 
  }