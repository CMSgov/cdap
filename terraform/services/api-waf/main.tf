module "aws_waf" {
  source = "../../modules/firewall"

  app = var.app
  env = var.env
  aws_lb_arn = var.aws_lb_arn
  rate_based_rule = var.rate_based_rule
  ip_sets_rule = var.ip_sets_rule
}
