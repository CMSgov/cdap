## quicksight-related policies and roles
resource "aws_iam_group" "main" {
  name = local.stack_prefix
  path = "/delegatedadmin/developer/"
}

resource "aws_iam_policy" "full" {
  name        = "dpc-insights-full-${var.env}"
  path        = "/delegatedadmin/developer/"
  description = "Allow full access and use of the ${local.stack_prefix} bucket for this account"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Perms"
        Effect = "Allow",
        Action = [
          "s3:PutAnalyticsConfiguration",
          "s3:GetObjectVersionTagging",
          "s3:CreateBucket",
          "s3:ReplicateObject",
          "s3:GetObjectAcl",
          "s3:GetBucketObjectLockConfiguration",
          "s3:DeleteBucketWebsite",
          "s3:PutLifecycleConfiguration",
          "s3:GetObjectVersionAcl",
          "s3:PutBucketAcl",
          "s3:PutObjectTagging",
          "s3:HeadBucket",
          "s3:DeleteObject",
          "s3:DeleteObjectTagging",
          "s3:GetBucketPolicyStatus",
          "s3:PutAccountPublicAccessBlock",
          "s3:GetObjectRetention",
          "s3:GetBucketWebsite",
          "s3:PutReplicationConfiguration",
          "s3:DeleteObjectVersionTagging",
          "s3:PutObjectLegalHold",
          "s3:GetObjectLegalHold",
          "s3:GetBucketNotification",
          "s3:PutBucketCORS",
          "s3:DeleteBucketPolicy",
          "s3:GetReplicationConfiguration",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutBucketNotification",
          "s3:PutBucketLogging",
          "s3:PutObjectVersionAcl",
          "s3:GetAnalyticsConfiguration",
          "s3:PutBucketObjectLockConfiguration",
          "s3:GetObjectVersionForReplication",
          "s3:GetLifecycleConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetBucketTagging",
          "s3:PutAccelerateConfiguration",
          "s3:DeleteObjectVersion",
          "s3:GetBucketLogging",
          "s3:ListBucketVersions",
          "s3:ReplicateTags",
          "s3:RestoreObject",
          "s3:ListBucket",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketPolicy",
          "s3:PutEncryptionConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetObjectVersionTorrent",
          "s3:AbortMultipartUpload",
          "s3:PutBucketTagging",
          "s3:GetBucketRequestPayment",
          "s3:GetObjectTagging",
          "s3:GetMetricsConfiguration",
          "s3:DeleteBucket",
          "s3:PutBucketVersioning",
          "s3:PutObjectAcl",
          "s3:GetBucketPublicAccessBlock",
          "s3:ListBucketMultipartUploads",
          "s3:PutBucketPublicAccessBlock",
          "s3:ListAccessPoints",
          "s3:PutMetricsConfiguration",
          "s3:PutObjectVersionTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:BypassGovernanceRetention",
          "s3:PutInventoryConfiguration",
          "s3:GetObjectTorrent",
          "s3:ObjectOwnerOverrideToBucketOwner",
          "s3:GetAccountPublicAccessBlock",
          "s3:PutBucketWebsite",
          "s3:ListAllMyBuckets",
          "s3:PutBucketRequestPayment",
          "s3:PutObjectRetention",
          "s3:GetBucketCORS",
          "s3:PutBucketPolicy",
          "s3:GetBucketLocation",
          "s3:ReplicateDelete",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.dpc-insights-bucket.arn}/*",
          "${aws_s3_bucket.dpc-insights-bucket.arn}"
        ]
      },
      {
        Sid    = "CMK"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/dcafa12b-bece-45f6-9f4a-d74631656fc9"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "full_attach" {
  #  count      = length(var.full_groups)
  group      = aws_iam_group.main.id
  policy_arn = aws_iam_policy.full.arn
}

# Allows writes to outputs
resource "aws_iam_policy" "athena_query" {
  name        = "dpc-insights-athena-query-${var.env}"
  path        = "/delegatedadmin/developer/"
  description = "Rights needed for athena query access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "s3QueryPolicy"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:CreateBucket",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::aws-athena-query-results-*",
          "${aws_s3_bucket.dpc-insights-bucket.arn}",
          "${aws_s3_bucket.dpc-insights-bucket.arn}/*"
        ]
      },
      {
        Sid    = "CMK"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/dcafa12b-bece-45f6-9f4a-d74631656fc9"
      }
    ]
  })
}


resource "aws_iam_group_policy_attachment" "athena_attach" {
  # count      = length(var.athena_groups)
  group      = aws_iam_group.main.id
  policy_arn = aws_iam_policy.full.arn
}

# resource "aws_s3_bucket_policy" "cross_account" {
#   count  = length(var.cross_accounts) > 0 ? 1 : 0
#   bucket = aws_s3_bucket.main.id
#   policy = <<-POLICY
#     {
#       "Version": "2012-10-17",
#       "Id": "AccessToDB",
#       "Statement": [
#           {
#               "Sid": "StmtID",
#               "Effect": "Allow",
#               "Principal": {
#                 "AWS": [
#                   ${join(",", formatlist("\"%s\"", var.cross_accounts))}
#                 ]
#               },
#               "Action": [
#                   "s3:AbortMultipartUpload",
#                   "s3:GetBucketLocation",
#                   "s3:ListBucket",
#                   "s3:ListBucketMultipartUploads",
#                   "s3:*Object"
#               ],
#               "Resource": [
#                   "${aws_s3_bucket.main.arn}/*",
#                   "${aws_s3_bucket.main.arn}"
#               ]
#           },
#         {
#             "Sid": "AllowSSLRequestsOnly",
#             "Effect": "Deny",
#             "Principal": "*",
#             "Action": "s3:*",
#             "Resource": [
#                   "${aws_s3_bucket.main.arn}",
#                   "${aws_s3_bucket.main.arn}/*"
#             ],
#             "Condition": {
#                 "Bool": {
#                     "aws:SecureTransport": "false"
#                 }
#             }
#         }
#       ]
#     }
#     POLICY
# }

# CloudWatch Role
resource "aws_iam_role" "iam-role-cloudwatch-logs" {
  name        = "${local.agg_profile}-cloudwatch-logs-role"
  description = "Allows access to the DPC Insights Firehose Delivery Stream and Export to S3"
  path        = "/delegatedadmin/developer/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "logs.us-east-1.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  inline_policy {
    name = "${local.agg_profile}-cloudwatch-logs-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["firehose:*"]
          Effect   = "Allow"
          Resource = ["arn:aws:firehose:us-east-1:${data.aws_caller_identity.current.account_id}:deliverystream/${local.agg_profile}-firehose-ingester"]
        }
      ]
    })
  }
}

# Firehose Policy
resource "aws_iam_policy" "iam-policy-firehose" {
  description = "Allow firehose delivery to DPC insights S3 bucket"
  name        = "${local.agg_profile}-firehose-to-s3-policy"
  path        = "/delegatedadmin/developer/"

  policy = jsonencode(
    {
      Statement = [
        # {
        #   Action = [
        #     "glue:GetTable",
        #     "glue:GetTableVersion",
        #     "glue:GetTableVersions",
        #   ]
        #   Effect = "Allow"
        #   Resource = [
        #     "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:table/${module.database.name}/${module.glue-table-api-requests.name}",
        #     "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/${module.database.name}",
        #     "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog"
        #   ]
        #   Sid = "GetGlueTable"
        # },
        {
          Action = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject",
          ]
          Effect = "Allow"
          Resource = [
            "${aws_s3_bucket.dpc-insights-bucket.arn}",
            "${aws_s3_bucket.dpc-insights-bucket.arn}/*",
          ]
          Sid = "GetS3Bucket"
        },
        {
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/dcafa12b-bece-45f6-9f4a-d74631656fc9"
          Sid      = "UseKMSKey"
        },
        {
          Action = [
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${local.agg_profile}-firehose:log-stream:*",
          ]
          Sid = "PutLogEvents"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

# Firehose Role
resource "aws_iam_role" "iam-role-firehose" {
  name                  = "${local.agg_profile}-firehose-role"
  description           = "allows Firehose access to Lambda transformation"
  path                  = "/delegatedadmin/developer/"
  force_detach_policies = false
  managed_policy_arns = [
    aws_iam_policy.iam-policy-firehose.arn,
  ]
  max_session_duration = 3600
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "firehose.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  inline_policy {
    name = "${local.agg_profile}-invoke-cw-to-flattened-json"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = "lambda:InvokeFunction"
            Effect = "Allow"
            Resource = [
              "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:${local.agg_profile}-cw-to-flattened-json",
              "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:${local.agg_profile}-cw-to-flattened-json:$LATEST"
            ]
            Sid = "InvokeCW2Json"
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
}

# Lambda Role
resource "aws_iam_role" "iam-role-firehose-lambda" {
  name                  = "${local.agg_profile}-firehose-lambda-role"
  description           = "Allow Lambda to create and write to its log group"
  path                  = "/delegatedadmin/developer/"
  max_session_duration  = 3600
  force_detach_policies = false
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  inline_policy {
    name = "${local.agg_profile}-lambda-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "logs:CreateLogGroup"
          Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = [
            "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.agg_profile}-cw-to-flattened-json:*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "firehose:PutRecordBatch"
          ]
          Resource = [
            "arn:aws:firehose:us-east-1:${data.aws_caller_identity.current.account_id}:deliverystream/${local.agg_profile}-firehose-ingester"
          ]
        }
      ]
    })
  }
}
