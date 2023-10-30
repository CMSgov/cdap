output "opt_out_lambda_role_arn" {
  description = "ARN of the IAM role for the opt-out Lambda"
  value       = aws_iam_role.opt_out_import_lambda_role.arn
}
output "opt_out_lambda_kms_key_arn" {
  value = aws_kms_key.env_vars_kms_key.arn
}
output "vpn_security_group" {
  value = data.aws_security_group.vpn
}

output "tools_security_group" {
  value = data.aws_security_group.tools
}

output "management_security_group" {
  value = data.aws_security_group.management
}

output "efs_security_group" {
  value = data.aws_security_group.efs
}

output "main_vpc" {
  value = data.aws_vpc.main
}

output "az1_subnet" {
  value = data.aws_subnet.az1
}

output "az2_subnet" {
  value = data.aws_subnet.az2
}

output "common_security_group_ids" {
  value = [
    data.aws_security_group.vpn.id,
    data.aws_security_group.tools.id,
    data.aws_security_group.management.id,
    data.aws_security_group.efs.id,
  ]
}
output "vpc_id" {
  value = data.aws_vpc.main.id
}

output "subnet_ids" {
  value = [
    data.aws_subnet.az1.id,
    data.aws_subnet.az2.id
  ]
}
