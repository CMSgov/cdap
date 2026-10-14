locals {
  full_name = "${var.app}-${var.env}-${var.name}"

  vpc_id     = var.vpc_id != null ? var.vpc_id : module.vpc[0].id
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : module.subnets[0].ids
}

module "vpc" {
  count  = var.vpc_id == null ? 1 : 0
  source = "../vpc"

  app = var.app
  env = var.env
}

module "subnets" {
  count  = var.subnet_ids == null ? 1 : 0
  source = "../subnets"

  vpc_id = local.vpc_id
}

# ── S3 Files Resources ──────────────────────────────────────────────────────

resource "aws_s3files_file_system" "this" {
  bucket     = var.bucket_arn
  role_arn   = aws_iam_role.s3files.arn
  kms_key_id = var.kms_key_arn

  tags = {
    Name = local.full_name
  }
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
}
