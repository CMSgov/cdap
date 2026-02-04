data "aws_ram_resource_share" "pace_ca" {
  resource_owner = "OTHER-ACCOUNTS"
  name           = "pace-ca-g1"
}

data "aws_acmpca_certificate_authority" "pace" {
  arn = one(data.aws_ram_resource_share.pace_ca.resource_arns)
}

data "aws_kms_alias" "kms_key" {
  name = "alias/cdap-${var.platform.env}"
}
