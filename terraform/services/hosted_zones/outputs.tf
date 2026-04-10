locals {
  zscaler_hosted_zone_instructions = <<-EOT
                                           ============================================================
                                           *** ACTION REQUIRED — CMS DNS Registration ***
                                           ============================================================
                                           Zone Name    : ${aws_route53_zone.zscaler.name}
                                           Zone ID      : ${aws_route53_zone.zscaler.zone_id}
                                           Name Servers : ${join(", ", aws_route53_zone.zscaler.name_servers)}
                                           ============================================================

                                           For hosted zones that allow access via Zscaler, you must coordinate with the CMS DNS/networking
                                           team to register this zone. Provide them with:

                                             1. The information above
                                             2. The AWS Account ID and region where the zone is managed
                                             3. The intended use to be Zscaler resolution of internal endpoints.

                                           Upon completion, verify the Zscaler VPC association
                                           has been completed on the hosted zone configuration and that the Zscaler team has validated DNS forwarding
                                           for this zone's domain suffix.
                                           ============================================================
                                         EOT
}

output "zscaler_hosted_zone_id" {
  description = "The Route53 Hosted Zone ID that allows developer access. Provide this to CMS DNS/networking team for zone delegation or discovery registration."
  value       = aws_route53_zone.zscaler.zone_id
}

output "zscaler_hosted_zone_name" {
  description = "The fully qualified domain name of the zscaler-friendly hosted zone."
  value       = aws_route53_zone.zscaler.name
}

output "zscaler_hosted_zone_name_servers" {
  description = "Name servers assigned to this hosted zone by Route53. Required for public zone NS delegation — provide these to the CMS DNS team."
  value       = aws_route53_zone.zscaler.name_servers
}

output "cms_dns_registration_instructions" {
  description = "Rendered instructions for registering this hosted zone with CMS DNS/networking."
  value       = local.zscaler_hosted_zone_instructions
}

output "internal_hosted_zone_id" {
  description = "The Route53 Hosted Zone ID that allows developer access. Provide this to CMS DNS/networking team for zone delegation or discovery registration."
  value       = aws_route53_zone.internal.zone_id
}

output "internal_hosted_zone_name" {
  description = "The fully qualified domain name of the hosted zone accessible by VPC only."
  value       = aws_route53_zone.internal.name
}

output "internal_hosted_zone_name_servers" {
  description = "Name servers assigned to this hosted zone by Route53."
  value       = aws_route53_zone.internal.name_servers
}
