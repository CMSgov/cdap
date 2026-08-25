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

  # Route 53
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:List*",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # WAF
  statement {
    actions = [
      "wafv2:AssociateWebACL",
      "wafv2:CreateIPSet",
      "wafv2:CreateWebACL",
      "wafv2:GetIPSet",
      "wafv2:GetWebACLForResource",
      "wafv2:List*",
      "wafv2:UpdateIPSet",
    ]
    resources = ["*"]
  }
}
