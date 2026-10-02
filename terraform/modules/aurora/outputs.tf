output "security_group" {
  value = aws_security_group.this
}

output "aurora_cluster" {
  value = aws_rds_cluster.this
}

output "aurora_instances" {
  value = aws_rds_cluster_instance.this
}

output "writer_endpoint" {
  description = "The cluster's writer endpoint, as host:port."
  value       = "${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}"
}

output "reader_endpoint" {
  description = "The cluster's reader endpoint, as host:port."
  value       = "${aws_rds_cluster.this.reader_endpoint}:${aws_rds_cluster.this.port}"
}

output "db_security_group_id" {
  description = "Security group ID attached to the cluster."
  value       = aws_security_group.this.id
}

output "breakglass_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed breakglass secret. Null unless manage_breakglass_password = true."
  value       = var.manage_breakglass_password ? aws_rds_cluster.this.master_user_secret[0].secret_arn : null
}

resource "aws_ssm_parameter" "breakglass_secret_arn" {
  count = var.manage_breakglass_password ? 1 : 0

  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/breakglass-secret-arn"
  value = aws_rds_cluster.this.master_user_secret[0].secret_arn
  type  = "String"

  tags = {
    Name = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/breakglass-secret-arn"
  }
}
