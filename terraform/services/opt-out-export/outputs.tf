output "lambda_role_arn" {
  value = module.opt_out_export_lambda.role_arn
}

output "zip_bucket" {
  value = module.opt_out_export_lambda.zip_bucket
}
