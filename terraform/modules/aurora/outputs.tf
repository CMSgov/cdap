output "security_group" {
  value = aws_security_group.this
}

output "aurora_cluster" {
  value = aws_rds_cluster.this
}

output "aurora_instances" {
  value = aws_rds_cluster_instance.this
}
