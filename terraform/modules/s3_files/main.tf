locals {
  app        = var.platform.app
  env        = var.platform.env
  full_name  = "${local.app}-${local.env}-${var.name}"
  vpc_id     = var.platform.vpc_id
  subnet_ids = nonsensitive([for s in var.platform.private_subnets : s.id])
}

# ── S3 Files Resources ──────────────────────────────────────────────────────

resource "aws_s3files_file_system" "this" {
  bucket     = var.bucket_arn
  role_arn   = aws_iam_role.s3files.arn
  kms_key_id = var.platform.kms_alias_primary.target_key_arn

  tags = {
    Name = local.full_name
  }

  depends_on = [
    aws_iam_role_policy.s3files,
  ]
}

resource "aws_s3files_mount_target" "this" {
  for_each = toset(local.subnet_ids)

  file_system_id  = aws_s3files_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.mount_targets.id]
}

resource "aws_s3files_access_point" "this" {
  file_system_id = aws_s3files_file_system.this.id

  tags = {
    Name = "${local.full_name}-ap"
  }

  depends_on = [
    aws_s3files_mount_target.this,
  ]
}
