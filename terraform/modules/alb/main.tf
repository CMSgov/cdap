locals {
  alb_name   = var.name_override != null ? var.name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}-alb"
  managed_sg = length(var.security_group_ids) == 0

  internal_fqdn = var.internal ? "${var.internal_record_name}.${data.aws_route53_zone.internal[0].name}" : null

  # Support explicitly provided subnets, or fall back to the platform's private subnets
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : (
    var.internal
    ? [for s in var.platform.private_subnets : s.id]
    : [for s in var.platform.public_subnets : s.id]
  )
}

# -------------------------------------------------------
# Application Load Balancer
# -------------------------------------------------------
resource "aws_lb" "this" {
  name               = local.alb_name
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = local.subnet_ids
  security_groups    = local.managed_sg ? [aws_security_group.alb[0].id] : var.security_group_ids

  enable_deletion_protection = var.internal ? false : true

  tags = { Name = local.alb_name }

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------------------------------------
# HTTPS Listener (port 443)
# Default action is a 404 fixed response — apps can attach
# their own listener rules with path/host conditions.
# -------------------------------------------------------
resource "aws_lb_listener" "https" {
  count             = var.listener_certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# -------------------------------------------------------
# HTTP Listener (port 80) redirect
# -------------------------------------------------------
resource "aws_lb_listener" "http_redirect" {
  count = var.enable_http_redirect ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -------------------------------------------------------
# Security Group
# -------------------------------------------------------
resource "aws_security_group" "alb" {
  count       = local.managed_sg ? 1 : 0
  name        = "${local.alb_name}-sg"
  description = "Security group for ${local.alb_name}"
  vpc_id      = var.platform.vpc_id

  tags = {
    Name = "${local.alb_name}-sg"
  }
}

# -------------------------------------------------------
# Route53
# -------------------------------------------------------

data "aws_route53_zone" "internal" {
  count        = var.internal_record_name ? 1 : 0
  name         = "${var.platform.env}.${var.platform.app}.internal.cms.gov"
  private_zone = true
  vpc_id       = var.platform.vpc_id
}

resource "aws_route53_record" "internal_alb" {
  count   = var.internal_record_name ? 1 : 0
  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${var.internal_record_name}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "zscaler" {
  count        = var.create_zscaler_dns_record ? 1 : 0
  name         = "${var.platform.env}.${var.platform.app}.cmscloud.local"
  private_zone = true
  vpc_id       = var.platform.vpc_id
}

resource "aws_route53_record" "zscaler_alb" {
  count   = var.create_zscaler_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.zscaler[0].zone_id
  name    = "${var.internal_record_name}.${data.aws_route53_zone.zscaler[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
