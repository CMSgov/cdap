output "bucket_arn" {
  description = "ARN of the BB2 QuickSight export bucket"
  value       = module.quicksight_export.arn
}

output "bucket_id" {
  description = "ID of the BB2 QuickSight export bucket"
  value       = module.quicksight_export.id
}
