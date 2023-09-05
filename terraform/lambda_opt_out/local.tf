locals {
  lambda_src = "${path.module}/lambda/main"
  lambda_zip = "${path.module}/lambda/lambda.zip"
  lambda_name = "dpcOptOutImportLambda-${var.env}"
  common_security_groups = [
    data.aws_security_group.vpn.id,
    data.aws_security_group.tools.id,
    data.aws_security_group.management.id,
    data.aws_security_group.efs.id
  ]
  vpc_id           = data.aws_vpc.main.id
  subnets          = [data.aws_subnet.az1.id, data.aws_subnet.az2.id]
}