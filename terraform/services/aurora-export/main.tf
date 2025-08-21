locals {
  export_bucket_name = "bcda-${var.env}-aurora-export"
}

module "export_bucket" {
  source = "../../modules/bucket"
  name   = local.export_bucket_name
}

resource "aws_iam_policy" "aurora_export" {
  name   = "aurora_export"
  policy = data.aws_iam_policy_document.aurora_export.json
}

resource "aws_iam_role_policy_attachment" "aurora_export" {
  role       = aws_iam_role.aurora_export.name
  policy_arn = aws_iam_policy.aurora_export.arn
}

resource "aws_iam_role" "aurora_export" {
  name        = "aurora_export"
  description = "Allows Aurora access to the Export S3 bucket."
  path        = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_s3_object" "aurora_export_manifest" {
  bucket = module.export_bucket.id
  key    = "manifest.json"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = [
          "https://${module.export_bucket.id}.s3-${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"
        ]
      }
    ]
    globalUploadSettings = {
      format         = "CSV"
      delimiter      = ","
      textqualifier  = "\""
      containsHeader = true
    }
  })
}

