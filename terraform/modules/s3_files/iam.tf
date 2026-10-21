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
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:DeleteObject*",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*",
    ]
  }

  statement {
    sid = "KMSKeyAccess"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
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
