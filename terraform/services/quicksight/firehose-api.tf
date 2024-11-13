# Firehose Data Stream
resource "aws_kinesis_firehose_delivery_stream" "ingester_api" {
  depends_on  = [aws_glue_catalog_table.api_metric_table]
  name        = "${local.stack_prefix}-ingester_api"
  destination = "extended_s3"

  extended_s3_configuration {
    bucket_arn          = local.dpc_glue_bucket_arn
    buffering_interval  = 300
    buffering_size      = 128
    error_output_prefix = "databases/${local.api_profile}/filter_errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    kms_key_arn         = local.dpc_glue_bucket_key_arn
    prefix              = "databases/${local.api_profile}/metric_table/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    role_arn            = aws_iam_role.iam-role-firehose.arn
    s3_backup_mode      = "Disabled"
    compression_format  = "UNCOMPRESSED" # Must be UNCOMPRESSED when format_conversion is turned on

    cloudwatch_logging_options {
      enabled = false
    }

    # dynamic_partitioning_configuration {
    #   enabled = "true"
    # }

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${resource.aws_lambda_function.format_dpc_logs.arn}:$LATEST"
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
    #     database_name = aws_glue_catalog_database.api.name
    #     role_arn      = resource.aws_iam_role.iam-role-firehose.arn
    #     table_name    = aws_glue_catalog_table.api_metric_table.name
    #   }
    # }
  }

  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }
}

resource "aws_glue_catalog_database" "api" {
  name        = "${local.stack_prefix}-db-api"
  description = "DPC API Insights database"
}

# CloudWatch Log Subscription
resource "aws_cloudwatch_log_subscription_filter" "quicksight-cloudwatch-api-log-subscription" {
  name = "${local.stack_prefix}-api-subscription"
  # Set the log group name so that if we use an environment ending in "-dev", it will get logs from
  # the "real" log group for that environment. So we could make an environment "prod-sbx-dev" that
  # we can use for development, and it will read from the "prod-sbx" environment.
  log_group_name  = "/aws/ecs/fargate/dpc-${local.this_env}-api"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.ingester_api.arn
  role_arn        = aws_iam_role.iam-role-cloudwatch-logs.arn
}
