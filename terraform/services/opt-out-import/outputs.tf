output "lambda_role_arn" {
  value = module.opt_out_import_lambda.lambda_role_arn
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.file_updates.arn
}

output "zip_file_bucket" {
  value = module.opt_out_import_lambda.lambda_zip_file_bucket
}
