resource "aws_athena_workgroup" "quicksight" {
  name = local.athena_profile

  depends_on = [ aws_s3_bucket_object.folder ]

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location     = "${local.dpc_athena_results_id}/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = local.dpc_athena_bucket_key_arn
      }
    }
  }
}

resource "aws_athena_database" "quicksight" {
  name   = local.athena_profile
  bucket = local.dpc_athena_bucket_id
}

resource "aws_athena_named_query" "total_benes_req" {
  name        = "${local.agg_profile}-total-benes"
  description = "total unique beneficiaries requested"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/total_benes_requested.sql.tfpl",
    {
      env          = "'${local.this_env}'",
      agg_profile  = "\"${aws_glue_catalog_database.agg.name}\".\"${aws_glue_catalog_table.agg_metric_table.name}\"",
      days_history = 7
    }
  )
}

resource "aws_athena_named_query" "unique_benes_served" {
  name        = "${local.agg_profile}-uniq-benes-served"
  description = "unique beneficiaries served"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/uniq_benes_served.sql.tfpl",
    {
      env          = "'${local.this_env}'",
      agg_profile  = "\"${aws_glue_catalog_database.agg.name}\".\"${aws_glue_catalog_table.agg_metric_table.name}\"",
      days_history = 7
    }
  )
}

resource "aws_athena_named_query" "group_requests" {
  name        = "${local.api_profile}-group-requests"
  description = "/Group requests made"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/group_requests.sql.tfpl",
    {
      env          = "'${local.this_env}'",
      api_profile  = "\"${aws_glue_catalog_database.api.name}\".\"${aws_glue_catalog_table.api_metric_table.name}\"",
      days_history = 7
    }
  )
}

resource "aws_athena_named_query" "bulk_calls_made" {
  name        = "${local.api_profile}-bulk-data-requests"
  description = "bulk data requests made"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/bulk_requests.sql.tfpl",
    {
      app          = "'dpc-api'",
      env          = "'${local.this_env}'",
      api_profile  = "\"${aws_glue_catalog_database.api.name}\".\"${aws_glue_catalog_table.api_metric_table.name}\"",
      days_history = 7
    }
  )
}

resource "aws_athena_named_query" "everything_calls_made" {
  name        = "${local.api_profile}-everything-data-requests"
  description = "data requests made with everything parameter"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/everything_requests.sql.tfpl",
    {
      app          = "'dpc-api'",
      env          = "'${local.this_env}'",
      api_profile  = "\"${aws_glue_catalog_database.api.name}\".\"${aws_glue_catalog_table.api_metric_table.name}\"",
      days_history = 7
    }
  )
}

resource "aws_athena_named_query" "since_calls_made" {
  name        = "${local.api_profile}-since-data-requests"
  description = "data requests made with _since parameter"
  workgroup   = aws_athena_workgroup.quicksight.id
  database    = aws_athena_database.quicksight.id
  query = templatefile("${path.module}/sql_templates/since_requests.sql.tfpl",
    {
      app          = "'dpc-api'",
      env          = "'${local.this_env}'",
      api_profile  = "\"${aws_glue_catalog_database.api.name}\".\"${aws_glue_catalog_table.api_metric_table.name}\"",
      days_history = 7
    }
  )
}