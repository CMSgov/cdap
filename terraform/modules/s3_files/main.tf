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

# ── IAM Service Role for S3 Files ──────────────────────────────────────────

data "aws_iam_policy_document" "s3files_assume_role" {
  statement {
    sid     = "S3FilesAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticfilesystem.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3files_bucket_access" {
  statement {
    sid = "S3BucketAccess"
    actions = concat(
      [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ],
      var.read_only ? [] : [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads",
      ]
    )
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*",
    ]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid = "KMSKeyAccess"
      actions = concat(
        [
          "kms:Decrypt",
          "kms:DescribeKey",
        ],
        var.read_only ? [] : [
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
      )
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role" "s3files" {
  name = "${local.full_name}-service-role"
  path = "/delegatedadmin/developer/"

  assume_role_policy = data.aws_iam_policy_document.s3files_assume_role.json
}

resource "aws_iam_role_policy" "s3files" {
  name   = "${local.full_name}-bucket-access"
  role   = aws_iam_role.s3files.id
  policy = data.aws_iam_policy_document.s3files_bucket_access.json
}

# ── Security Group & Mount Targets ──────────────────────────────────────────

resource "aws_security_group" "mount_targets" {
  name        = "${local.full_name}-mount-target"
  description = "Security group for ${local.full_name} S3 Files mount targets"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-mount-target"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nfs_from_allowed_sgs" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.mount_targets.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "Allow NFS ingress from client security group"
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
