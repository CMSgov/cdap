output "subnet_ids" {
  description = "IDs of filtered subnets"
  value       = data.aws_subnets.this.ids
}
