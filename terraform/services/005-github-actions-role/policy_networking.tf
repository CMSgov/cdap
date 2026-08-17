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
  statement {
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
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
