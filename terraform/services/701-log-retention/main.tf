locals {
  # "shared" marks resources other teams write to or reference
  # "cdap" marks resources created, managed, and used only by CDAP
  shared_name = "shared-${var.env}-log-retention"
  cdap_name   = "cdap-${var.env}-log-retention"

  # Writes outside these prefixes are not granted to the delivery role
  firehose_data_prefix  = "cloudwatch/"
  firehose_error_prefix = "firehose-errors/"
}

# Dedicated CMK so log encryption is managed and rotated independently of the
# app-env keys
resource "aws_kms_key" "log_retention" {
  description             = "Dedicated encryption key for the log retention pipeline (bucket, Firehose, diagnostics log group)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.log_retention_kms.json
}

resource "aws_kms_alias" "log_retention" {
  name          = "alias/${local.cdap_name}"
  target_key_id = aws_kms_key.log_retention.key_id
}

module "log_bucket" {
  source = "../../modules/bucket"

  app  = module.platform.app
  env  = var.env
  name = local.shared_name

  kms_key_arn        = aws_kms_key.log_retention.arn
  use_custom_kms_key = true

  # Compliance-mode WORM in prod only: objects cannot be deleted or overwritten
  # for 6 years by anyone, including root (HIPAA retention requirement).
  # No lock in test environments
  object_lock = var.env == "prod" ? {
    mode  = "COMPLIANCE"
    years = 6
  } : null
  force_destroy = false

  # Writers are limited to the Firehose role and prefix-scoped log delivery
  # services. all other principals are denied
  additional_bucket_policies = [data.aws_iam_policy_document.log_bucket_writes.json]

  # GLACIER_IR keeps objects queryable via Athena, unlike GLACIER or
  # DEEP_ARCHIVE which require restore before read
  # TODO: determine if we should use GLACIER_IR or GLACIER for long-term storage
  transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    },
    {
      days          = 365
      storage_class = "GLACIER_IR"
    },
  ]

  # Expire objects once the 6-year HIPAA retention has elapsed
  # in prod this is also past the Object Lock retain-until date. Noncurrent
  # versions and delete markers are cleaned up by the bucket module shortly after.
  expiration_days = 2200

  ssm_parameter = "/${module.platform.app}/${module.platform.env}/common/nonsensitive/log-retention/bucket"
}

data "aws_ssm_parameter" "cloudwatch_alarms_topic_arn" {
  name = "/${module.platform.app}/${module.platform.env}/cdap-alarm-topic/nonsensitive/alarms-topic-arn"
}

# Delivery failure diagnostics from Firehose itself
module "firehose_log_group" {
  source = "../../modules/cloudwatch_log_group"

  name               = "/aws/kinesisfirehose/${local.shared_name}"
  kms_key_id         = aws_kms_key.log_retention.arn
  log_retention_days = 30
}

resource "aws_cloudwatch_log_stream" "firehose_s3_delivery" {
  name           = "DestinationDelivery"
  log_group_name = module.firehose_log_group.this.name
}

resource "aws_kinesis_firehose_delivery_stream" "log_retention" {
  name        = local.shared_name
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
      log_group_name  = module.firehose_log_group.this.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3_delivery.name
    }
  }
}

# Discovery for the CloudWatch log group common module's subscription filters
resource "aws_ssm_parameter" "firehose_arn" {
  name  = "/${module.platform.app}/${module.platform.env}/common/nonsensitive/log-retention/firehose-arn"
  type  = "String"
  value = aws_kinesis_firehose_delivery_stream.log_retention.arn
}

resource "aws_ssm_parameter" "cloudwatch_to_firehose_role_arn" {
  name  = "/${module.platform.app}/${module.platform.env}/common/nonsensitive/log-retention/subscription-role-arn"
  type  = "String"
  value = aws_iam_role.cloudwatch_to_firehose.arn
}

# Failure alerting to CDAP
resource "aws_cloudwatch_metric_alarm" "firehose_delivery_failure" {
  alarm_name          = "${local.cdap_name}-s3-delivery-failure"
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
  alarm_name          = "${local.cdap_name}-data-freshness"
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
  alarm_name          = "${local.cdap_name}-throttled-records"
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
