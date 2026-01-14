resource "aws_cloudwatch_log_delivery_source" "this" {
  name         = "${local.naming_prefix}-static-site"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn
}

data "aws_s3_bucket" "cms_cloudfront_logs" {
  bucket = "cms-cloud-${data.aws_caller_identity.this.account_id}-${data.aws_region.primary.name}"
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  name          = "${local.naming_prefix}-static-site"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = data.aws_s3_bucket.cms_cloudfront_logs.arn
  }
}

resource "aws_cloudwatch_log_delivery" "this" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.this.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this.arn

  s3_delivery_configuration {
    suffix_path = "/AWSLogs/${data.aws_caller_identity.this.account_id}/Cloudfront/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
  }
}