data "aws_iam_policy_document" "github_actions_networking" {
  # CloudFront
  statement {
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListDistributions",
    ]
    resources = ["*"]
  }

  # ElastiCache
  statement {
    actions   = ["elasticache:Describe*"]
    resources = ["*"]
  }

  # EFS
  statement {
    actions   = ["elasticfilesystem:Describe*"]
    resources = ["*"]
  }
  # ELB
  # NOTE: ALB naming is inconsistent across apps so scoping to app prefix only:
  #   ab2d: ${app}-${env}-${service}
  #   bcda: ${app}-${service}-${env}[-${index}]
  #   dpc:  ${app}-${service}-${env}-${index}
  # FIXME: tighten to ${app}-${env}-* once naming is standardized
  statement {
    sid = "ElbRead"
    actions = [
      "elasticloadbalancing:Describe*",
    ]
    resources = ["*"]
  }
  statement {
    sid = "ElbWrite"
    actions = [
      # Load Balancer
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      # Listeners
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:RemoveListenerCertificates",
      # Rules
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:SetRulePriorities",
      # Target Groups
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/${var.app}-*",
      "arn:aws:elasticloadbalancing:*:*:targetgroup/${var.app}-*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/${var.app}-*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/${var.app}-*",
    ]
  }

  statement {
    sid = "ElbTagging"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = ["*"]
  }

  # RAM
  statement {
    actions = [
      "ram:GetResourceShares",
      "ram:ListResources",
    ]
    resources = ["*"]
  }

  # Route53 Read — all apps need to look up their hosted zones
  statement {
    sid = "Route53Read"
    actions = [
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"] # Hosted zone IDs are auto-generated
  }

  # Route53 Write — teams manage records in their own zones
  # CDAP manages zone creation
  statement {
    sid = "Route53Write"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["*"]
    # FIXME: Scope to specific hosted zone ARNs once teams are actively
    #        using Route53. Zone ARNs follow:
    #        arn:aws:route53:::hostedzone/ZONEID
    #        Zones in use:
    #          ${var.env}.${var.app}.cmscloud.local
    #          ${var.env}.${var.app}.internal.cms.gov
    #          ${var.app}-${var.env}.local (deprecated)
  }

  # WAF Read
  statement {
    sid = "WafRead"
    actions = [
      "wafv2:GetIPSet",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:List*",
    ]
    resources = ["*"] # List* must be *
  }

  # WAF Write — app/env scoped + shared external-services IP sets
  statement {
    sid = "WafWrite"
    actions = [
      "wafv2:AssociateWebACL",
      "wafv2:CreateIPSet",
      "wafv2:CreateWebACL",
      "wafv2:DeleteIPSet",
      "wafv2:DeleteWebACL",
      "wafv2:DisassociateWebACL",
      "wafv2:TagResource",
      "wafv2:UntagResource",
      "wafv2:UpdateIPSet",
      "wafv2:UpdateWebACL",
    ]
    resources = [
      # App/env scoped WAF resources
      "arn:aws:wafv2:*:*:regional/webacl/${var.app}-${var.env}-*",
      "arn:aws:wafv2:*:*:regional/ipset/${var.app}-${var.env}-*",
      "arn:aws:wafv2:*:*:global/webacl/${var.app}-${var.env}-*",
      "arn:aws:wafv2:*:*:global/ipset/${var.app}-${var.env}-*",
      # Shared external-services IP sets — regional and global
      "arn:aws:wafv2:*:*:regional/ipset/external-services*",
      "arn:aws:wafv2:*:*:global/ipset/external-services*",
      # NOTE: RegSamQuickACLEnforcing and SamQuickACLEnforcing are currently
      #       in use by teams but are not self-managed. To restrict to
      #       self-managed WAFs only, remove these two lines:
      "arn:aws:wafv2:*:*:regional/webacl/RegSamQuickACLEnforcing*",
      "arn:aws:wafv2:*:*:regional/webacl/SamQuickACLEnforcing*",
    ]
  }
}
