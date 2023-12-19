data "aws_region" "current" {}

output "backend_config" {
  description = "Text for the tfbackend file"
  value       = <<EOT
bucket         = "${aws_s3_bucket.this.id}"
dynamodb_table = "${aws_dynamodb_table.this.id}"
region         = "${data.aws_region.current.name}"
encrypt        = true
kms_key_id     = "${aws_kms_alias.this.name}"
EOT
}
