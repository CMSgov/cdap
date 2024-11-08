resource "aws_s3_bucket" "dpc-insights-bucket" {
  bucket = "${local.stack_prefix}-${local.account_id}"
}

resource "aws_s3_bucket" "dpc-insights-logging" {
  bucket = "${var.app}-${local.this_env}-logs-${local.account_id}"
}

# block public access to the bucket
resource "aws_s3_bucket_public_access_block" "dpc-insights-bucket" {
  bucket                  = aws_s3_bucket.dpc-insights-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "dpc-insights-logging" {
  bucket                  = aws_s3_bucket.dpc-insights-logging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dpc-insights-bucket" {
  bucket = aws_s3_bucket.dpc-insights-bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.this_env_key
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_logging" "dpc-insights-bucket" {
  bucket = aws_s3_bucket.dpc-insights-bucket.id

  target_bucket = aws_s3_bucket.dpc-insights-logging.id
  target_prefix = "${local.this_env}_s3_access_logs/"
}


resource "aws_s3_bucket_server_side_encryption_configuration" "dpc-insights-logging" {
  bucket = aws_s3_bucket.dpc-insights-logging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# resource "aws_s3_bucket_policy" "dpc-insights-logging" {
#   bucket = aws_s3_bucket.dpc-insights-logging.id
#   policy = <<POLICY
# {
#   "Id": "LogPerms",
#   "Statement": [

#     {
#       "Action": "s3:*",
#       "Condition": {
#         "Bool": {
#           "aws:SecureTransport": "false"
#         }
#       },
#       "Effect": "Deny",
#       "Principal": "*",
#       "Resource": [
#         "${aws_s3_bucket.dpc-insights-logging.arn}",
#         "${aws_s3_bucket.dpc-insights-logging.arn}/*"
#       ],
#       "Sid": "AllowSSLRequestsOnly"
#     }
#   ],
#   "Version": "2012-10-17"
# }
# POLICY
# }

resource "aws_s3_bucket" "dpc-insights-athena" {
  bucket = local.athena_profile
}

# block public access to the bucket
resource "aws_s3_bucket_public_access_block" "dpc-insights-athena" {
  bucket                  = aws_s3_bucket.dpc-insights-athena.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dpc-insights-athena" {
  bucket = aws_s3_bucket.dpc-insights-athena.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.this_env_key
      sse_algorithm     = "aws:kms"
    }
  }
}