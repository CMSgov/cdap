# TODO: Are these needed? Any extras?
output "function_role_arn" {
  value = module.cclf_import_function.role_arn
}

output "sqs_queue_arn" {
  value = module.cclf_import_queue.arn
}

output "zip_bucket" {
  value = module.cclf_import_function.zip_bucket
}
