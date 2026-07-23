output "base_tags" {
  description = "Base tags applied to synthetics tests in this module."
  value       = local.base_tags
}

output "non_private_location_ids" {
  description = "Datadog location IDs for all aws:us-gov* locations"
  value       = local.non_private_location_ids
}
