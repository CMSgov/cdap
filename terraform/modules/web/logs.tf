resource "aws_cloudwatch_log_delivery_source" "this" {
  name         = "${var.platform.app}-${var.platform.env}"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  name          = "${var.platform.app}-${var.platform.env}"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = var.platform.splunk_logging_bucket.arn
  }
}

resource "aws_cloudwatch_log_delivery" "this" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.this.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this.arn

  s3_delivery_configuration {
    suffix_path = "/AWSLogs/${data.aws_caller_identity.this.account_id}/Cloudfront/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
  }
}