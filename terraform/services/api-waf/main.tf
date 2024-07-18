locals {
  load_balancers = {
    ab2d = [
      "api-${var.app}-east-${var.env}",
    ]
    bcda = [
      "${var.app}-api-${var.env}-01",
    ]
    dpc = [
      "${var.app}-${var.env}-1",
    ]
  }
}

data "aws_lb" "aws_lb_arn" {
  name = local.load_balancers[var.app]
}

module "aws_waf" {
  source = "../../modules/firewall"

  app             = var.app
  env             = var.env
  aws_lb_arn      = aws_lb_arn.arn
  rate_based_rule = var.rate_based_rule
  ip_sets_rule    = var.ip_sets_rule
  region          = var.region
}
