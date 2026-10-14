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
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionTagging",
        "s3:ListBucket",
        "s3:ListBucketVersions",
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
