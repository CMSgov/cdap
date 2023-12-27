data "aws_region" "current" {}

output "backend_config" {
  description = "Text for the tfbackend file"
  value       = <<EOT
bucket         = "${aws_s3_bucket.this.id}"
dynamodb_table = "${aws_dynamodb_table.this.id}"
EOT
}
