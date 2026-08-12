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

  # Application Auto Scaling (used by ECS service scaling)
  statement {
    sid = "ApplicationAutoscaling"
    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:Describe*",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
    ]
    resources = ["*"]
  }
  # CodeBuild
  statement {
    actions = [
      "codebuild:BatchGetProjects",
      "codebuild:CreateProject",
      "codebuild:CreateWebhook",
      "codebuild:DeleteProject",
      "codebuild:DeleteWebhook",
      "codebuild:List*",
      "codebuild:UpdateProject",
      "codebuild:UpdateProjectVisibility",
      "codebuild:UpdateWebhook",
    ]
    resources = ["*"]
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
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:Describe*",
      "ecr:GetAuthorizationToken",
      "ecr:GetLifecyclePolicy",
      "ecr:InitiateLayerUpload",
      "ecr:List*",
      "ecr:PutImage",
      "ecr:TagResource",
      "ecr:UploadLayerPart",
    ]
    resources = ["*"]
  }

  # ECS
  statement {
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeregisterTaskDefinition",
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UpdateService",
      "servicediscovery:GetNamespace",
      "servicediscovery:ListTagsForResource",
    ]
    resources = ["*"]
  }
}
