data "aws_iam_policy_document" "github_actions_storage" {
  # Backup
  statement {
    actions = [
      "backup:CreateBackupPlan",
      "backup:CreateBackupSelection",
      "backup:DescribeBackupVault",
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
      "backup:ListTags"
    ]
    resources = ["*"]
  }

  # EFS
  statement {
    actions = [
      # File system lifecycle (aws_efs_file_system)
      "elasticfilesystem:CreateFileSystem",
      "elasticfilesystem:DeleteFileSystem",
      "elasticfilesystem:UpdateFileSystem",
      "elasticfilesystem:PutLifecycleConfiguration",
      "elasticfilesystem:PutBackupPolicy",
      "elasticfilesystem:PutFileSystemPolicy",
      "elasticfilesystem:DeleteFileSystemPolicy",
      "elasticfilesystem:TagResource",
      "elasticfilesystem:UntagResource",

      # Mount target lifecycle (aws_efs_mount_target)
      "elasticfilesystem:CreateMountTarget",
      "elasticfilesystem:DeleteMountTarget",
      "elasticfilesystem:ModifyMountTargetSecurityGroups",

      # Read / describe — used by data sources and Terraform refresh
      # (data.aws_efs_file_system, data.aws_efs_access_points)
      "elasticfilesystem:Describe*",
      "elasticfilesystem:List*",
    ]
    resources = ["*"]
  }

  # RDS

  # Read Describe* cannot be resource-scoped
  statement {
    sid = "RdsRead"
    actions = [
      "rds:Describe*",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RdsWrite"
    actions = [
      # Cluster
      "rds:CreateDBCluster",
      "rds:DeleteDBCluster",
      "rds:ModifyDBCluster",
      # Instances
      "rds:CreateDBInstance",
      "rds:DeleteDBInstance",
      "rds:ModifyDBInstance",
      # Cluster Parameter Group
      "rds:CreateDBClusterParameterGroup",
      "rds:DeleteDBClusterParameterGroup",
      "rds:ModifyDBClusterParameterGroup",
      # Instance Parameter Group
      "rds:CreateDBParameterGroup",
      "rds:DeleteDBParameterGroup",
      "rds:ModifyDBParameterGroup",
      # Subnet Group
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      # IAM Role Association — needed for s3Import and similar features
      "rds:AddRoleToDBCluster",
      "rds:RemoveRoleFromDBCluster",
      # Tagging
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
    ]
    resources = [
      "arn:aws:rds:*:*:cluster:${var.app}-${var.env}",
      "arn:aws:rds:*:*:cluster:${var.app}-${var.env}-*",
      "arn:aws:rds:*:*:db:${var.app}-${var.env}-*",
      "arn:aws:rds:*:*:cluster-pg:${var.app}-${var.env}-*",
      "arn:aws:rds:*:*:pg:${var.app}-${var.env}-*",
      "arn:aws:rds:*:*:subgrp:${var.app}-${var.env}-*",
    ]
  }

  # S3 Buckets
  # List all buckets — must be * (account-level action)
  statement {
    sid       = "S3ListAllBuckets"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  # S3 Bucket Read
  statement {
    sid = "S3BucketRead"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [
      # Conventional pattern — covers most buckets
      "arn:aws:s3:::${var.app}-${var.env}-*",
      # Domain-style — ${var.app}
      "arn:aws:s3:::*.${var.app}.cms.gov",
      "arn:aws:s3:::${var.app}.cms.gov",
    ]
  }

  # S3 Bucket Write — excludes communal/CMS-managed buckets
  statement {
    sid = "S3BucketWrite"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketLogging",
      "s3:PutBucketNotification",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = [
      # Conventional pattern
      "arn:aws:s3:::${var.app}-${var.env}-*",
      # Domain-style
      "arn:aws:s3:::*.${var.app}.cms.gov",
      "arn:aws:s3:::${var.app}.cms.gov",
    ]
  }

  # S3 Object operations
  statement {
    sid = "S3ObjectOperations"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:ListObjectVersions",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]
    resources = [
      # Conventional pattern
      "arn:aws:s3:::${var.app}-${var.env}-*/*",
      # Domain-style
      "arn:aws:s3:::*.${var.app}.cms.gov/*",
      "arn:aws:s3:::${var.app}.cms.gov/*"
    ]
  }
  statement {
    sid = "S3AccessLogsBucketRead"
    actions = [
      "s3:GetBucketAcl", #  CloudFront specifically requires this
      "s3:GetBucketPolicy",
      "s3:GetBucketTagging",
      "s3:GetEncryptionConfiguration",
    ]
    resources = [
      "arn:aws:s3:::bucket-access-logs-*",
    ]
  }

}

