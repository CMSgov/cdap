data "aws_region" "current" {}

output "backend_config" {
  description = "Text for the tfbackend file"
  value       = <<EOT
bucket         = "${module.tfstate_bucket.id}"
dynamodb_table = "${module.tfstate_table.id}"
EOT
}
