output "distribution" {
  value = aws_cloudfront_distribution.this
}

output "ip_allow_list_ssm_parameter_name" {
  value = module.aws_ssm_parameter.allowed_ip_list.name
}
