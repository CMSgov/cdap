output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.this.id
}

output "vpc_endpoint_dns_name" {
  description = "AWS-generated regional DNS name for the endpoint."
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "friendly_dns_name" {
  description = "Friendly CNAME, if created. Null otherwise and callers can use AWS generated name"
  value       = var.dns_record_name != null ? "${var.dns_record_name}.${data.aws_route53_zone.internal[0].name}" : null
}

output "security_group_id" {
  description = "The endpoint's security group — managed or passed-in. Use this to add ingress rules for calling services."
  value       = aws_security_group.this.id
}
