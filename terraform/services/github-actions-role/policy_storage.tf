data "aws_iam_policy_document" "github_actions_storage" {
  # Backup
  statement {
    actions = [
      "backup:CreateBackupPlan",
      "backup:CreateBackupSelection",
      "backup:DescribeBackupVault",
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
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
      "s3:PutBucket*",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = ["*"] # FIXME ensure github actions can manage only buckets for their given app-env, requires bucket name verifications
    # outliers can be stored in config/ paths like outlier KMS keys
  }

  # Leave broad for Terraform to inspect buckets it didn't create
  statement {
    actions = [
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:ListBucket",
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

