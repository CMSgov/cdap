output "access_point_arn" {
  description = "ARN of the S3 Files access point (pass this to Lambda file_system_config.arn)"
  value       = aws_s3files_access_point.this.arn
}

output "access_point_id" {
  description = "ID of the S3 Files access point"
  value       = aws_s3files_access_point.this.id
}

output "file_system_id" {
  description = "ID of the S3 Files file system"
  value       = aws_s3files_file_system.this.id
}

output "file_system_arn" {
  description = "ARN of the S3 Files file system"
  value       = aws_s3files_file_system.this.arn
}

output "security_group_id" {
  description = "ID of the security group attached to the mount targets (for client egress security group rules)"
  value       = aws_security_group.mount_targets.id
}

output "service_role_arn" {
  description = "ARN of the IAM role used by S3 Files to access the backing S3 bucket"
  value       = aws_iam_role.s3files.arn
}
