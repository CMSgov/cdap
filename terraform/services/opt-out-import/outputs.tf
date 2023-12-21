output "lambda_role_arn" {
  value = module.opt_out_import_lambda.role_arn
}

output "sqs_queue_arn" {
  value = module.opt_out_import_queue.arn
}

output "zip_file_bucket" {
  value = module.opt_out_import_lambda.zip_file_bucket
}
