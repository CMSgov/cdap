data "archive_file" "zip-archive-format-dpc-logs" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/dpc-bfd-cwlog-basic-flatten-json.py"
  output_path = "${path.module}/lambda_src/${local.this_env}/dpc-bfd-cwlog-basic-flatten-json.zip"
}

# Lambda Function to process logs from Firehose
resource "aws_lambda_function" "lambda-function-format-dpc-logs" {
  architectures = [
    "x86_64",
  ]
  description                    = "Extracts and flattens JSON messages from CloudWatch log subscriptions"
  function_name                  = "${local.stack_prefix}-cw-to-flattened-json"
  filename                       = data.archive_file.zip-archive-format-dpc-logs.output_path
  handler                        = "dpc-bfd-cwlog-basic-flatten-json.lambda_handler"
  layers                         = []
  memory_size                    = 256
  package_type                   = "Zip"
  reserved_concurrent_executions = -1
  role                           = aws_iam_role.iam-role-firehose-lambda.arn

  runtime          = "python3.12"
  source_code_hash = data.archive_file.zip-archive-format-dpc-logs.output_base64sha256

  tags = { "lambda-console:blueprint" = "kinesis-firehose-cloudwatch-logs-processor-python" }

  timeout = 300

  ephemeral_storage {
    size = 512
  }

  timeouts {}

  tracing_config {
    mode = "PassThrough"
  }
}
