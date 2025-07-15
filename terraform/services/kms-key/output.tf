output "primary_kms_alias" {
  value = aws_kms_alias.primary.name
}

output "secondary_kms_alias" {
  value = aws_kms_alias.secondary.name
}
