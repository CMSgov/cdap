output "vpce_all_clients_security_group_id" {
  value = aws_security_group.vpce_all_clients.id
}

output "vpce_build_clients_security_group_id" {
  value = aws_security_group.vpce_build_clients.id
}
