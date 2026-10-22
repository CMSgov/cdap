output "vpce_clients_all_security_group_id" {
  value = aws_security_group.vpce_clients_all.id
}

output "vpce_clients_platform_security_group_id" {
  value = aws_security_group.vpce_clients_platform.id
}
