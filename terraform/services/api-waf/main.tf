locals {
  load_balancers = {
    ab2d = {
      name = var.env == "dev" ? "ab2d-dev" : "api-${var.app}-east-${var.env}"
    }
    bcda = {
      name = var.env == "sbx" ? "${var.app}-api-opensbx-01" : "${var.app}-api-${var.env}-01"
    }
    dpc = {
      name = var.env == "sbx" ? "${var.app}-prod-sbx-1" : "${var.app}-${var.env}-1"
    }
  }
}

data "aws_lb" "api_lb" {
  name = local.load_balancers[var.app].name
}

module "aws_waf" {
  source = "../../modules/firewall"

  app             = var.app
  env             = var.env
  aws_lb_arn      = data.aws_lb.api_lb.arn
  rate_based_rule = var.rate_based_rule
  ip_sets_rule    = var.ip_sets_rule
  region          = var.region
}
