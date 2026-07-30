locals {
  alb_name   = var.name_override != null ? var.name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}-alb"
  managed_sg = length(var.security_group_ids) == 0

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

  tags = { Name = local.alb_name }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.internal || var.name_override == null
      error_message = <<-EOT
        name_override is set on an internet-facing ALB.
        Changing the ALB name forces recreation and may break
        any CMS-managed DNS records pointing at this ALB.
        If you must rename, coordinate with the CMS DNS team first.
      EOT
    }
  }
}

# -------------------------------------------------------
# HTTPS Listener (port 443)
# Default action is a 404 fixed response — apps can attach
# their own listener rules with path/host conditions.
# -------------------------------------------------------
resource "aws_lb_listener" "https" {
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
