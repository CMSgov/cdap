locals {
  lambda_src = "../../../../opt-out-import-lambda/bin/main"
  lambda_zip = "../../../../opt-out-import-lambda/lambda_function.zip"
  lambda_name = "dpcOptOutImportLambda-${var.env}"
}