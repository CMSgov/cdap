output "opt_out_import_lambda_role_arn" {
  value = module.opt_out_import_lambda.lambda_role_arn
}

output "opt_out_import_lambda_bucket" {
  value = module.opt_out_import_lambda.lambda_zip_file_bucket
}
