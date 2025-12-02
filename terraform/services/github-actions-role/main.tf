locals {
  provider_domain = "token.actions.githubusercontent.com"
  repos = {
    ab2d = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/ab2d-website:*",
      "repo:CMSgov/ab2d:*",
    ]
    bcda = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/bcda-app:*",
      "repo:CMSgov/bcda-ssas-app:*",
      "repo:CMSgov/bcda-static-site:*",
    ]
    dpc = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/dpc-app:*",
      "repo:CMSgov/dpc-static-site:*",
    ]
    cdap = [
      "repo:CMSgov/cdap:*",
    ]
  }
  admin_app = "bcda"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_role" "admin" {
  name = "ct-ado-${local.admin_app}-application-admin"
}

data "aws_iam_policy_document" "github_actions_role_assume" {
  # Allow access from the admin role
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn]
    }
  }

  # Allow access from GitHub-hosted runners via OIDC
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sts:TagSession",
    ]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_domain}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.provider_domain}:sub"
      values   = local.repos[var.app]
    }
  }

  # Allow for use as an instance profile for packer, etc.
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "poweruser_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

data "aws_iam_policy_document" "github_actions_policy" {
  # Certificate Manager
  statement {
    actions = [
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListCertificates",
    ]
    resources = ["*"]
  }
  # EC2 Autoscaling
  statement {
    actions = [
      "autoscaling:DeleteNotificationConfiguration",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeNotificationConfigurations",
      "autoscaling:DescribePolicies",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:PutNotificationConfiguration",
      "autoscaling:StartInstanceRefresh",
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = ["*"]
  }
  # Backup
  statement {
    actions = [
      "backup:CreateBackupPlan",
      "backup:CreateBackupSelection",
      "backup:DescribeBackupVault",
      "backup:GetBackupPlan",
      "backup:GetBackupSelection"
    ]
    resources = ["*"]
  }
  # CloudFront
  statement {
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListDistributions"
    ]
    resources = ["*"]
  }
  # CloudWatch
  statement {
    actions = [
      "cloudwatch:DescribeAlarms"
    ]
    resources = ["*"]
  }
  # EC2
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateImage",
      "ec2:CreateKeyPair",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeManagedPrefixLists",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:ModifyImageAttribute",
      "ec2:GetManagedPrefixListEntries",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances"
    ]
    resources = ["*"]
  }
  # ECR
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }
  # ECS
  statement {
    actions = [
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }
  # ElastiCache
  statement {
    actions = [
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeCacheSubnetGroups",
      "elasticache:DescribeReplicationGroups"
    ]
    resources = ["*"]
  }
  # EFS
  statement {
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeLifecycleConfiguration",
      "elasticfilesystem:DescribeMountTargetSecurityGroups",
      "elasticfilesystem:DescribeMountTargets"
    ]
    resources = ["*"]
  }
  # ELB
  statement {
    actions = [
      "elasticloadbalancing:DescribeCapacityReservation",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets"
    ]
    resources = ["*"]
  }
  # EventBridge
  statement {
    actions = [
      "events:DescribeRule",
      "events:ListTargetsByRule",
      "events:PutRule",
      "events:PutTargets"
    ]
    resources = ["*"]
  }
  # KMS
  statement {
    sid = "KmsUsage"
    actions = [
      "kms:ListAliases",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:EnableKeyRotation",
      "kms:CreateAlias",
      "kms:CreateKey"
    ]
    resources = ["*"]
  }
  statement {
    sid = "KmsSpecificKeyUsage"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = concat(
      [data.aws_kms_alias.environment_key.arn],
      var.app == "ab2d" ? concat(
        data.aws_kms_alias.ab2d_ecr[*].arn,
        data.aws_kms_alias.ab2d_tfstate_bucket[*].arn,
      ) : [],
      var.app == "bcda" ? concat(
        data.aws_kms_alias.bcda_aco_creds[*].arn,
        data.aws_kms_alias.bcda_app_config[*].arn,
        data.aws_kms_alias.bcda_insights_data_sampler[*].arn,
      ) : [],
      var.app == "dpc" ? concat(
        [for key in data.aws_kms_alias.dpc_cloudwatch_keys : key.arn],
        data.aws_kms_alias.dpc_app_config[*].arn,
        data.aws_kms_alias.dpc_ecr[*].arn,
        data.aws_kms_alias.dpc_sns_topic[*].arn
      ) : []
    )
  }
  # Kinesis
  statement {
    actions = [
      "firehose:CreateDeliveryStream",
      "firehose:DescribeDeliveryStream",
      "firehose:StartDeliveryStreamEncryption"
    ]
    resources = ["*"]
  }
  # IAM
  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAccountAliases",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListOpenIDConnectProviders",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint"
    ]
    resources = ["*"]
  }
  # Lambda
  statement {
    actions = [
      "lambda:CreateEventSourceMapping",
      "lambda:UpdateFunctionCode",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetPolicy",
      "lambda:GetFunction",
      "lambda:ListVersionsByFunction",
      "lambda:GetEventSourceMapping",
      "lambda:UpdateFunctionConfiguration",
      "lambda:CreateFunction",
      "lambda:AddPermission"
    ]
    resources = ["*"]
  }
  # CloudWatch Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeSubscriptionFilters",
      "logs:PutRetentionPolicy"
    ]
    resources = ["*"]
  }
  # RDS
  statement {
    actions = [
      "rds:AddSourceIdentifierToSubscription",
      "rds:CreateDBParameterGroup",
      "rds:CreateDBSubnetGroup",
      "rds:DescribeDBClusterEndpoints",
      "rds:DescribeDBClusterParameterGroups",
      "rds:DescribeDBClusterParameters",
      "rds:DescribeDBClusters",
      "rds:DescribeDBInstances",
      "rds:DescribeDBParameterGroups",
      "rds:DescribeDBParameters",
      "rds:DescribeDBSubnetGroups",
      "rds:DescribeEventSubscriptions",
      "rds:DescribeGlobalClusters",
      "rds:ModifyDBClusterParameterGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:ModifyDBParameterGroup"
    ]
    resources = ["*"]
  }
  # Route 53
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
  # S3
  statement {
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:PutBucketLogging",
      "s3:PutBucketNotification",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration"
    ]
    resources = ["*"]
  }
  # Secrets Manager
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue"
    ]
    resources = ["*"]
  }
  # SQS
  statement {
    actions = [
      "sqs:CreateQueue",
      "sqs:SetQueueAttributes"
    ]
    resources = ["*"]
  }
  # SNS
  statement {
    actions = [
      "sns:ListTopics",
      "sns:ListTagsForResource",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:GetSubscriptionAttributes"
    ]
    resources = ["*"]
  }
  # Systems Manager
  statement {
    actions = [
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:PutParameter",
      "ssm:StartSession",
      "ssm:TerminateSession"
    ]
    resources = ["*"]
  }
  # STS
  statement {
    actions = [
      "sts:GetCallerIdentity"
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
      "wafv2:ListIPSets",
      "wafv2:ListWebACLs",
      "wafv2:UpdateIPSet"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.app}-${var.env}-github-actions"
  path = "/delegatedadmin/developer/"

  assume_role_policy   = data.aws_iam_policy_document.github_actions_role_assume.json
  permissions_boundary = data.aws_iam_policy.poweruser_boundary.arn
}

resource "aws_iam_role_policy" "github_actions_role_policy" {
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.github_actions_policy.json
}

resource "aws_iam_instance_profile" "github_actions_role" {
  name = "${var.app}-${var.env}-github-actions"
  path = "/delegatedadmin/developer/"
  role = aws_iam_role.github_actions.name
}
