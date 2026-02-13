data "aws_caller_identity" "current" {}

data "aws_kms_alias" "kms_key" {
  name = "alias/cdap-test"
}

data "aws_ram_resource_share" "pace_ca" {
  resource_owner = "OTHER-ACCOUNTS"
  name           = "pace-ca-g1"
}
