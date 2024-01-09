output "vpc_id" {
  description = "ID of VPC"
  value       = data.aws_vpc.this.id
}
