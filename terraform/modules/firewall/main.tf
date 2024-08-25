//TODO: 
// - Add rate limiting rule to match BCDA's config
// - SQL Injection ruleset
// - Cloudfront distribution (?)
resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  default_action {
    allow {}
  }

  rule {
    name     = "CommonRuleset"
    priority = 0
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "CommonRuleset"
        vendor_name = "AWS"

        rule_action_override {
          name = "Example"
          action_to_use {
            allow {}
          }

        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.name
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.associated_resource_arn != "" ? 1 : 0

  resource_arn = var.associated_resource_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
