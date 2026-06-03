module "platform" {
  providers = { aws = aws, aws.secondary = aws.secondary }

  source      = "../../modules/platform"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/hosted-zones"
  service     = "hosted-zones"
}

resource "aws_route53_zone" "internal" {
  name = "${var.env}.${var.app}.cmscloud.internal"

  vpc {
    vpc_id = module.platform.vpc_id
  }
}

resource "aws_route53_zone" "zscaler" {
  name = "${var.env}.${var.app}.cmscloud.local"

  vpc {
    vpc_id = module.platform.vpc_id
  }
}
