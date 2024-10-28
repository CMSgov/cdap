# Firehose Data Stream
resource "aws_kinesis_firehose_delivery_stream" "firehose-ingester-agg" {
  name        = "${local.stack_prefix}-firehose-ingester-agg"
  destination = "extended_s3"

  extended_s3_configuration {
    bucket_arn          = aws_s3_bucket.dpc-insights-bucket.arn
    buffering_interval  = 300
    buffering_size      = 128
    error_output_prefix = "databases/${local.agg_profile}/filter_errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    # kms_key_arn         = data.aws_kms_key.kms_key.arn
    # prefix              = "databases/${local.agg_profile}/destination_table=!{partitionKeyFromLambda}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    kms_key_arn        = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/dcafa12b-bece-45f6-9f4a-d74631656fc9"
    prefix             = "databases/${local.agg_profile}/generic_table/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    role_arn           = aws_iam_role.iam-role-firehose.arn
    s3_backup_mode     = "Disabled"
    compression_format = "UNCOMPRESSED" # Must be UNCOMPRESSED when format_conversion is turned on

    cloudwatch_logging_options {
      enabled = false
    }

    dynamic_partitioning_configuration {
      enabled = "true"
    }


    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${resource.aws_lambda_function.lambda-function-format-dpc-logs.arn}:$LATEST"
        }
      }
    }

    # data_format_conversion_configuration {
    #   input_format_configuration {
    #     deserializer {
    #       hive_json_ser_de {}
    #     }
    #   }

    #   output_format_configuration {
    #     serializer {
    #       parquet_ser_de {
    #         compression = "SNAPPY"
    #       }
    #     }
    #   }

    #   schema_configuration {
    #     database_name = "${local.stack_prefix}-db"
    #     role_arn      = resource.aws_iam_role.iam-role-firehose.arn
    #     table_name    = "!{partitionKeyFromLambda}"
    #   }
    # }
  }

  # server_side_encryption {
  #   enabled  = true
  #   key_type = "AWS_OWNED_CMK"
  # }
}

# resource "aws_glue_catalog_database" "agg" {
#   name        = "${local.stack_prefix}-db"
#   description = "DPC Insights database"
# }

# resource "aws_glue_security_configuration" "main" {
#   name        = var.database

#   encryption_configuration {
#     cloudwatch_encryption {
#       cloudwatch_encryption_mode = "DISABLED"
#     }

#     job_bookmarks_encryption {
#       job_bookmarks_encryption_mode = "DISABLED"
#     }

#     s3_encryption {
#       kms_key_arn        = data.aws_kms_key.bucket_cmk.arn
#       s3_encryption_mode = "SSE-KMS"
#     }
#   }
# }

# CloudWatch Log Subscription
resource "aws_cloudwatch_log_subscription_filter" "cloudwatch-agg-log-subscription" {
  name = "${local.stack_prefix}-agg-subscription"
  # Set the log group name so that if we use an environment ending in "-dev", it will get logs from
  # the "real" log group for that environment. So we could make an environment "prod-sbx-dev" that
  # we can use for development, and it will read from the "prod-sbx" environment.
  log_group_name  = "/aws/ecs/fargate/dpc-${var.env}-aggregation"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose-ingester-agg.arn
  role_arn        = aws_iam_role.iam-role-cloudwatch-logs.arn
}
