locals {
  base_name = "${var.platform.app}-${var.platform.env}-${var.platform.service}"
  alb_name  = var.name_override != null ? var.name_override : "${local.base_name}-alb"
  nlb_name  = "${substr(local.base_name, 0, 28)}-nlb"

  managed_sg          = length(var.security_group_ids) == 0
  private_record_name = var.private_record_name != null ? var.private_record_name : var.platform.service

  privatelink_requires_alb = var.enable_privatelink && var.nlb_mode == "front_alb"
  privatelink_owner_arn    = sensitive("arn:aws:iam::${var.platform.account_id}:root")

  enable_alb_deletion_protection = coalesce(var.enable_deletion_protection, !var.internal)

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

  enable_deletion_protection = local.enable_alb_deletion_protection

  # Mitigates HTTP request smuggling via malformed/ambiguous headers
  drop_invalid_header_fields = true

  # AWS default is "defensive"; "strictest" is the safer posture for a
  # load balancer that may take traffic from the open internet
  desync_mitigation_mode = "strictest"

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
  for_each = var.create_alb ? var.https_listeners : {}

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = "HTTPS"
  certificate_arn   = each.value.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-3-2021-06"

  default_action {
    type             = each.value.default_action_type
    target_group_arn = each.value.default_action_type == "forward" ? each.value.default_target_group_arn : null

    dynamic "fixed_response" {
      for_each = each.value.default_action_type == "fixed-response" ? [1] : []
      content {
        status_code  = tostring(each.value.default_fixed_response_status_code)
        content_type = "text/plain"
        message_body = "Not Found"
      }
    }
  }
}

# -------------------------------------------------------
# HTTP Listener (port 80) redirect
# -------------------------------------------------------

resource "aws_lb_listener" "http" {
  count = var.create_alb ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = tostring(var.http_redirect_target_port)
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -------------------------------------------------------
# Security Group
# -------------------------------------------------------
resource "aws_security_group" "alb" {
  count = (var.create_alb && local.managed_sg) ? 1 : 0

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
  count = (var.create_alb && var.create_internal_dns_record != null) ? 1 : 0

  name         = "${var.platform.env}.${var.platform.app}.internal.cms.gov."
  private_zone = true
  vpc_id       = var.platform.vpc_id
}

resource "aws_route53_record" "internal_alb" {
  count = (var.create_alb && var.create_internal_dns_record != null) ? 1 : 0

  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${local.private_record_name}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "zscaler" {
  count        = (var.create_alb && var.create_zscaler_dns_record) ? 1 : 0
  name         = "${var.platform.env}.${var.platform.app}.cmscloud.local"
  private_zone = true
  vpc_id       = var.platform.vpc_id
}

resource "aws_route53_record" "zscaler_alb" {
  count   = (var.create_alb && var.create_zscaler_dns_record) ? 1 : 0
  zone_id = data.aws_route53_zone.zscaler[0].zone_id
  name    = "${local.private_record_name}.${data.aws_route53_zone.zscaler[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}

# -------------------------------------------------------
# Network Load Balancer
# -------------------------------------------------------
resource "aws_lb" "network" {
  count = var.create_nlb ? 1 : 0

  name               = local.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = local.subnet_ids
  security_groups    = [aws_security_group.nlb[0].id]

  tags = { Name = local.nlb_name }

  lifecycle {
    create_before_destroy = true
    precondition {
      condition     = !var.enable_privatelink || var.internal
      error_message = "PrivateLink requires this module's internal setting to be true (var.internal = true)."
    }
    precondition {
      condition     = !local.privatelink_requires_alb || var.create_alb
      error_message = "enable_privatelink with nlb_mode = \"front_alb\" requires create_alb = true."
    }
  }
}

resource "aws_security_group" "nlb" {
  count = var.create_nlb ? 1 : 0

  name        = "${local.nlb_name}-sg"
  description = "Security group for ${local.nlb_name}"
  vpc_id      = var.platform.vpc_id

  tags = { Name = "${local.nlb_name}-sg" }
}

# -------------------------------------------------------
# NLB -> ALB (front_alb mode only)
# -------------------------------------------------------
resource "aws_lb_target_group" "network_to_alb" {
  count = (var.create_nlb && var.nlb_mode == "front_alb") ? 1 : 0

  name        = "${substr(local.base_name, 0, 23)}-nlb-tg"
  port        = var.privatelink_target_port
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.platform.vpc_id

  health_check {
    protocol = "HTTPS"
    port     = tostring(var.privatelink_target_port)
    path     = var.privatelink_health_check_path
    matcher  = "200-399"
  }

  lifecycle {
    create_before_destroy = true
    precondition {
      condition     = contains([for l in var.https_listeners : l.port], var.privatelink_target_port)
      error_message = "privatelink_target_port (${var.privatelink_target_port}) must match a port in var.https_listeners."
    }
  }
}

resource "aws_lb_target_group_attachment" "network_to_alb" {
  count = (var.create_nlb && var.nlb_mode == "front_alb") ? 1 : 0

  target_group_arn = aws_lb_target_group.network_to_alb[0].arn
  target_id        = aws_lb.this[0].arn
  port             = var.privatelink_target_port
}

resource "aws_lb_listener" "network" {
  count = (var.create_nlb && var.nlb_mode == "front_alb") ? 1 : 0

  load_balancer_arn = aws_lb.network[0].arn
  port              = var.privatelink_target_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.network_to_alb[0].arn
  }
}

# -------------------------------------------------------
# PrivateLink Endpoint Service
# Points at the NLB regardless of nlb_mode and works whether the NLB
# fronts this module's ALB today, or something else once "direct"
# mode is actually in use.
# -------------------------------------------------------
resource "aws_vpc_endpoint_service" "this" {
  count = var.enable_privatelink ? 1 : 0

  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.network[0].arn]
  # Allows this AWS account to generate vpc endpoints for this service
  allowed_principals = [local.privatelink_owner_arn]

  # Leave null unless a verifiable public DNS path exists for this
  # domain. Most internal.cms.gov / cmscloud.local zones are private-only
  # and cannot pass AWS's public-DNS-based verification check.
  private_dns_name = var.privatelink_private_dns_name

  tags = { Name = "${local.base_name}-privatelink" }
}

resource "aws_vpc_endpoint_service_private_dns_verification" "this" {
  count = (var.enable_privatelink && var.privatelink_private_dns_name != null) ? 1 : 0

  service_id = aws_vpc_endpoint_service.this[0].id
}

