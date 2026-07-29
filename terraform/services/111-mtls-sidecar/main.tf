resource "aws_ssm_parameter" "mtls_sidecar_image_tag" {
  name   = "/cdap/${var.env}/nonsensitive/mtls-sidecar/image-tag"
  type   = "String"
  value  = "initial"

  lifecycle {
    ignore_changes = [value]
  }
}
