locals {
 # Set conditional logic or affirm another way sensitive values are flagged in code and can't be committed
}

resource "aws_ssm_parameter" "bucket" {
  name  = "/${var.app}/${var.env}/${var.sensitivity}/${var.key_name}"
  value = var.value
  overwrite = var.overwrite
  type  = var.type
}
