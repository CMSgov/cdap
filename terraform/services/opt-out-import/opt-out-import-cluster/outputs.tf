output "function_role_arn" {
  value = module.opt_out_import_function.role_arn
}

output "sqs_queue_arn" {
  value = module.opt_out_import_queue.arn
}

output "zip_bucket" {
  value = module.opt_out_import_function.zip_bucket
}
