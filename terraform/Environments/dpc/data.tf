data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = local.lambda_zip
  source_file = local.lambda_src
}