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
  statement {
    actions = [
      "rds:AddSourceIdentifierToSubscription",
      "rds:CreateDBParameterGroup",
      "rds:CreateDBSubnetGroup",
      "rds:Describe*",
      "rds:List*",
      "rds:ModifyDBCluster",
      "rds:ModifyDBClusterParameterGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:ModifyDBParameterGroup",
    ]
    resources = ["*"]
  }

  # S3 Buckets
  # Mutating actions scoped to app/env buckets
  statement {
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketLogging",
      "s3:PutBucketNotification",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = ["*"] # FIXME ensure github actions can manage only buckets for their given app-env, requires bucket name verifications
    # outliers can be stored in config/ paths like outlier KMS keys
  }

  # Leave broad for Terraform to inspect buckets it didn't create
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads"
    ]
    resources = ["*"]
  }

  # S3 Objects
  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:ListObjectVersions",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]
    resources = ["*"]
  }
}

