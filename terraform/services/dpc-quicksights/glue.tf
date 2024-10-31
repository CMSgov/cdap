locals {

  serde_format = "parquet"

  table_parameters = {
    json = {
      EXTERNAL = "TRUE"
    },
    parquet = {
      classification        = "parquet"
      EXTERNAL              = "TRUE"
      "parquet.compression" = "SNAPPY"
    }
  }

  table_partitions = [
    {
      name    = "year"
      type    = "string"
      comment = "Year of request"
    },
    {
      name    = "month"
      type    = "string"
      comment = "Month of request"
    }
  ]

  storage_options = {
    json = {
      input_format  = "org.apache.hadoop.mapred.TextInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    },
    parquet = {
      input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    }
  }

  serde_options = {
    json = {
      library = "org.apache.hive.hcatalog.data.JsonSerDe"
      params = {
        "ignore.malformed.json" = true,
        "dots.in.keys"          = true,
        "timestamp.formats"     = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS,yyyy-MM-dd'T'HH:mm:ss.SSS,yyyy-MM-dd'T'HH:mm:ss,yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z',yyyy-MM-dd'T'HH:mm:ss.SSS'Z',yyyy-MM-dd'T'HH:mm:ss'Z'"
      }
    },
    grok = {
      library = "com.amazonaws.glue.serde.GrokSerDe"
      params = {
        "ignore.malformed.json" = true,
        "dots.in.keys"          = true,
        "timestamp.formats"     = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS,yyyy-MM-dd'T'HH:mm:ss.SSS,yyyy-MM-dd'T'HH:mm:ss,yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z',yyyy-MM-dd'T'HH:mm:ss.SSS'Z',yyyy-MM-dd'T'HH:mm:ss'Z'"
      }
    },
    parquet = {
      #library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      library = "org.openx.data.jsonserde.JsonSerDe"
      #library = "com.amazon.ionhiveserde.IonHiveSerDe"
      params = {
        "serialization.format" = 1
      }
    }
  }

  agg_columns = [

    {
      "name"    = "metadata",
      "type"    = "string",
      "comment" = "JSON {metric_table, timestamp}"
    },
    {
      "name"    = "data",
      "type"    = "string",
      "comment" = "flattened JSON log item"
    }
  ]

  api_columns = [

    {
      "name"    = "metadata",
      "type"    = "string",
      "comment" = "JSON {metric_table, timestamp}"
    },
    {
      "name"    = "data",
      "type"    = "string",
      "comment" = "flattened JSON log item"
    }
  ]

}

resource "aws_glue_catalog_table" "agg_metric_table" {
  name          = local.agg_profile
  database_name = aws_glue_catalog_database.agg.name
  description   = "CW Table for DPC Aggregation"
  table_type    = "EXTERNAL_TABLE"
  owner         = "dpc"

  # parameters = local.table_parameters["json"]
  parameters = local.table_parameters["parquet"]

  dynamic "partition_keys" {
    for_each = local.table_partitions

    content {
      name    = partition_keys.value.name
      type    = partition_keys.value.type
      comment = partition_keys.value.comment
    }
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.dpc-insights-bucket.id}/databases/${local.agg_profile}/metric_table"
    #input_format  = local.storage_options["json"].input_format
    input_format  = local.storage_options["parquet"].input_format
    output_format = local.storage_options["parquet"].output_format
    compressed    = true

    dynamic "columns" {
      for_each = local.agg_columns

      content {
        name    = columns.value.name
        type    = columns.value.type
        comment = columns.value.comment
      }
    }

    ser_de_info {
      name                  = local.agg_profile
      serialization_library = local.serde_options[local.serde_format].library
      parameters            = local.serde_options[local.serde_format].params
    }
  }

  # These things get changed by the Crawler (if there is one), and we don't
  # need to undo whatever changes the Crawler makes
  lifecycle {
    ignore_changes = [
      # TODO: Consider removing everything here
      parameters
    ]
  }
}

# add crawler for metadata inspection
# Crawler for the API Requests table
resource "aws_glue_crawler" "glue_crawler_agg_metrics" {
  classifiers   = []
  database_name = aws_glue_catalog_database.agg.name
  configuration = jsonencode(
    {
      CrawlerOutput = {
        Partitions = {
          AddOrUpdateBehavior = "InheritFromTable"
        }
      }
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      Version = 1
    }
  )
  name = local.agg_profile
  role = aws_iam_role.iam-role-glue.arn

  catalog_target {
    database_name = aws_glue_catalog_database.agg.name
    tables = [
      aws_glue_catalog_table.agg_metric_table.name,
    ]
  }

  lineage_configuration {
    crawler_lineage_settings = "DISABLE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  depends_on = [aws_glue_catalog_table.agg_metric_table]
}

# resource "aws_glue_catalog_table" "api_metric_table" {

#   name          = local.api_profile
#   database_name = "${local.stack_prefix}-db"
#   description   = "CW Table for DPC API"
#   table_type    = "EXTERNAL_TABLE"
#   owner         = "dpc"

#   parameters = local.table_parameters["json"]

#   dynamic "partition_keys" {
#     for_each = local.table_partitions

#     content {
#       name    = partition_keys.value.name
#       type    = partition_keys.value.type
#       comment = partition_keys.value.comment
#     }
#   }

#   storage_descriptor {
#     location      = "s3://${data.aws_s3_bucket.dpc-insights-bucket.id}/databases/"
#     input_format  = local.storage_options["json"].input_format
#     output_format = local.storage_options["json"].output_format
#     compressed    = true

#     dynamic "columns" {
#       for_each = local.agg_columns

#       content {
#         name    = columns.value.name
#         type    = columns.value.type
#         comment = columns.value.comment
#       }
#     }

#     ser_de_info {
#       name                  = var.table
#       serialization_library = local.serde_options[var.serde_format].library
#       parameters            = local.serde_options[var.serde_format].params
#     }
#   }

#   # These things get changed by the Crawler (if there is one), and we don't
#   # need to undo whatever changes the Crawler makes
#   lifecycle {
#     ignore_changes = [
#       # TODO: Consider removing everything here
#       parameters
#     ]
#   }
# }
