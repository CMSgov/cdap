output "arn" {
  description = "The ARN of the WAF WebACL."
  value       = aws_wafv2_web_acl.this.arn
}
