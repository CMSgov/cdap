module "table_key" {
  source      = "../key"
  name        = "${var.name}-table"
  description = "For ${var.name} DynamoDB table"
}

resource "aws_dynamodb_table" "this" {
  name     = var.name
  hash_key = "LockID"

  billing_mode = "PAY_PER_REQUEST"

  server_side_encryption {
    enabled     = true
    kms_key_arn = module.table_key.arn
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}
