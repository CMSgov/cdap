output "primary_kms_alias" {
  description = "Name of the KMS alias in the primary AWS account."
  value       = aws_kms_alias.primary.name
}

output "secondary_kms_alias" {
  description = "Name of the KMS alias in the secondary AWS account."
  value       = aws_kms_alias.secondary.name
}
