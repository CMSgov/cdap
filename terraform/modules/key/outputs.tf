output "alias" {
  description = "Alias for the KMS key"
  value       = aws_kms_alias.this.name
}

output "arn" {
  description = "ARN for the KMS key"
  value       = aws_kms_key.this.arn
}

output "id" {
  description = "ID for the KMS key"
  value       = aws_kms_key.this.key_id
}
