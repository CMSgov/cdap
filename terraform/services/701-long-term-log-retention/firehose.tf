locals {
  firehose_name = "${var.app}-${var.env}-long-term-log-retention"

  # Writes outside these prefixes are not granted to the delivery role
  firehose_data_prefix  = "cloudwatch/"
  firehose_error_prefix = "firehose-errors/"
}

data "aws_ssm_parameter" "cloudwatch_alarms_topic_arn" {
  name = "/${module.platform.app}/${module.platform.env}/cdap-alarm-topic/nonsensitive/alarms-topic-arn"
}

# Firehose -> S3 delivery role, write access limited to the data/error prefixes
data "aws_iam_policy_document" "firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [module.platform.account_id]
    }
  }
}

data "aws_iam_policy_document" "firehose_delivery" {
  statement {
    sid = "BucketMetadata"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [module.log_bucket.arn]
  }
  statement {
    sid = "PrefixLimitedWrites"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "${module.log_bucket.arn}/${local.firehose_data_prefix}*",
      "${module.log_bucket.arn}/${local.firehose_error_prefix}*",
    ]
  }

  statement {
    sid = "EncryptWithDedicatedKey"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.log_retention.arn]
  }

  statement {
    sid       = "DeliveryErrorLogging"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.firehose.arn}:log-stream:*"]
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${local.firehose_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

resource "aws_iam_role_policy" "firehose" {
  name   = "s3-delivery"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_delivery.json
}

# Delivery failure diagnostics from Firehose itself
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.firehose_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "firehose_s3_delivery" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_kinesis_firehose_delivery_stream" "log_retention" {
  name        = local.firehose_name
  destination = "extended_s3"

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = aws_kms_key.log_retention.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = module.log_bucket.arn

    # Dynamic partitioning requires a 64MB minimum buffer
    buffering_size     = 64
    buffering_interval = 300 # seconds
    compression_format = "GZIP"

    kms_key_arn = aws_kms_key.log_retention.arn

    dynamic_partitioning_configuration {
      enabled = true
    }

    # Subscription filter records arrive gzipped. decompress the CloudWatch
    # envelope in-stream to avoid double-zipping, making the data queryable by Athena,
    # and partition S3 keys by source log group
    processing_configuration {
      enabled = true

      processors {
        type = "Decompression"
        parameters {
          parameter_name  = "CompressionFormat"
          parameter_value = "GZIP"
        }
      }

      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{log_group: (.logGroup | ltrimstr(\"/\"))}"
        }
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
      }

      processors {
        type = "AppendDelimiterToRecord"
        parameters {
          parameter_name  = "Delimiter"
          parameter_value = "\\n"
        }
      }
    }

    prefix              = "${local.firehose_data_prefix}!{partitionKeyFromQuery:log_group}/!{timestamp:yyyy/MM/dd}/"
    error_output_prefix = "${local.firehose_error_prefix}!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3_delivery.name
    }
  }
}

# CloudWatch Logs -> Firehose role, assumed by subscription filters
data "aws_iam_policy_document" "cloudwatch_to_firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${module.platform.primary_region.region}:${module.platform.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_to_firehose" {
  statement {
    sid = "PutToLogRetentionFirehose"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
    ]
    resources = [aws_kinesis_firehose_delivery_stream.log_retention.arn]
  }
}

resource "aws_iam_role" "cloudwatch_to_firehose" {
  name               = "${local.firehose_name}-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_to_firehose_assume.json
}

resource "aws_iam_role_policy" "cloudwatch_to_firehose" {
  name   = "firehose-put"
  role   = aws_iam_role.cloudwatch_to_firehose.id
  policy = data.aws_iam_policy_document.cloudwatch_to_firehose.json
}

# Discovery for the CloudWatch log group common module's subscription filters
resource "aws_ssm_parameter" "firehose_arn" {
  name  = "/cdap/${var.env}/common/nonsensitive/long-term-log-retention/firehose-arn"
  type  = "String"
  value = aws_kinesis_firehose_delivery_stream.log_retention.arn
}

resource "aws_ssm_parameter" "cloudwatch_to_firehose_role_arn" {
  name  = "/cdap/${var.env}/common/nonsensitive/long-term-log-retention/subscription-role-arn"
  type  = "String"
  value = aws_iam_role.cloudwatch_to_firehose.arn
}

# Failure alerting to CDAP
resource "aws_cloudwatch_metric_alarm" "firehose_delivery_failure" {
  alarm_name          = "${local.firehose_name}-s3-delivery-failure"
  alarm_description   = "Firehose is failing to deliver log records to the long-term retention bucket"
  namespace           = "AWS/Firehose"
  metric_name         = "DeliveryToS3.Success"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.log_retention.name
  }

  alarm_actions = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
  ok_actions    = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
}

resource "aws_cloudwatch_metric_alarm" "firehose_data_freshness" {
  alarm_name          = "${local.firehose_name}-data-freshness"
  alarm_description   = "Oldest undelivered record in the log retention Firehose exceeds 15 minutes"
  namespace           = "AWS/Firehose"
  metric_name         = "DeliveryToS3.DataFreshness"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 900
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.log_retention.name
  }

  alarm_actions = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
  ok_actions    = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
}

# Catches partial failures that DeliveryToS3.Success (an average) can dilute
resource "aws_cloudwatch_metric_alarm" "firehose_throttled_records" {
  alarm_name          = "${local.firehose_name}-throttled-records"
  alarm_description   = "Log producers are being throttled writing to the log retention Firehose"
  namespace           = "AWS/Firehose"
  metric_name         = "ThrottledRecords"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.log_retention.name
  }

  alarm_actions = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
  ok_actions    = [data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value]
}
