data "aws_iam_policy_document" "github_actions_compute" {
  # Certificate Manager
  statement {
    sid = "AcmRead"
    actions = [
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
    ]
    resources = ["*"]
  }

  # ACM — write operations
  statement {
    sid = "AcmWrite"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:ImportCertificate", # public path for CMS-signed cert
      "acm:RemoveTagsFromCertificate",
      "acm:RenewCertificate",
      "acm:RequestCertificate", # private path for PCA-issued cert
      "acm:UpdateCertificateOptions",
    ]
    resources = ["*"]
  }

  # ACM Private CA
  # Needed to describe the shared PCA used for private cert issuance
  # Actual issuance is handled by ACM internally, no acm-pca:IssueCertificate needed
  statement {
    sid = "AcmPcaRead"
    actions = [
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:GetCertificateAuthorityCertificate",
      "acm-pca:ListCertificateAuthorities",
    ]
    resources = ["*"]
  }

  # Application Auto Scaling Read (used by ECS service scaling)
  statement {
    sid = "AppAutoscalingRead"
    actions = [
      "application-autoscaling:Describe*",
      "application-autoscaling:ListTagsForResource",
    ]
    resources = ["*"] # Describe* cannot be resource-scoped
  }

  # Application Auto Scaling Write
  # Resource format: arn:aws:application-autoscaling:region:account:scalable-target/id
  # The scalable target ID is auto-generated so scoping by name isn't possible
  # However we can scope by service namespace in the resource
  statement {
    sid = "AppAutoscalingWrite"
    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
    ]
    resources = ["*"]
    # FIXME: application-autoscaling ARNs use auto-generated IDs
    #        Scoping is possible via resource_id which follows
    #        service/{cluster}/{service} for ECS — but the ARN itself
    #        uses an opaque ID. Consider tagging as compensating control.
  }

  # EC2 - Security Groups & VPC inspection only (no instance launching)
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:Describe*",
      "ec2:GetManagedPrefixListEntries",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["*"]
  }

  # ECR
  # ECR Read — auth token is account-level, must be *
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR Read — scoped to app (not env — ECR repos are shared across envs)
  statement {
    sid = "EcrRead"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:Describe*",
      "ecr:GetLifecyclePolicy",
      "ecr:List*",
    ]
    resources = [
      "arn:aws:ecr:*:*:repository/${var.app}*",
      "arn:aws:ecr:*:*:repository/cdap-mtls-sidecar",
    ]
  }

  # ECR Write — scoped to app
  statement {
    sid = "EcrWrite"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:aws:ecr:*:*:repository/${var.app}*",
    ]
  }
  # ECS
  # ECS Read
  statement {
    sid = "EcsRead"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "servicediscovery:GetNamespace",
      "servicediscovery:ListTagsForResource",
    ]
    resources = ["*"] # Describe*/List* cannot be resource-scoped
  }

  # ECS Write — scoped to app/env
  statement {
    sid = "EcsWrite"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:TagResource",
      "ecs:UpdateService",
    ]
    resources = [
      # Clusters — app-env or app-env-service
      "arn:aws:ecs:*:*:cluster/${var.app}-${var.env}*",
      # Services
      "arn:aws:ecs:*:*:service/${var.app}-${var.env}*/${var.app}-${var.env}*",
      # Task definitions
      "arn:aws:ecs:*:*:task-definition/${var.app}-${var.env}*",
      "arn:aws:ecs:*:*:task-definition/${var.app}-${var.env}*:*",
    ]
  }

  # ECS actions that require * — either called against * by the provider
  # or resource doesn't exist at call time
  statement {
    sid = "EcsRequiresWildcard"
    actions = [
      "ecs:DeregisterTaskDefinition", # provider calls against *
      "ecs:RegisterTaskDefinition",   # resource doesn't exist at call time
    ]
    resources = ["*"]
  }
}
