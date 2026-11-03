output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.this.id
}

output "vpc_endpoint_dns_name" {
  description = "AWS-generated regional DNS name for the endpoint."
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "friendly_dns_name" {
  description = <<-EOT
    "<this app>.<target_domain_name>" that resolves only within this VPC,
    via the shadow zone this module creates. Matches a SAN on the
    target's cert if this app is enrolled there. Use this to build
    DOWNSTREAM_URL.
  EOT
  value       = trimsuffix(aws_route53_record.friendly_name.fqdn, ".")
}

output "security_group_id" {
  description = "The endpoint's security group — managed or passed-in. Use this to add ingress rules for calling services."
  value       = aws_security_group.this.id
}
