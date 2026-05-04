# TODO: To Deprecate cdap mgmt remove this for each as we can assume the only environment is CDAP
data "aws_ssm_parameter" "github_token" {
  for_each = var.app == "cdap" ? toset([var.env]) : toset([])
  name     = "/cdap/${var.env}/codebuild-projects/sensitive/github-token"
}

data "aws_security_group" "security_tools" {
  vpc_id = var.app == "bcda" ? module.vpc[0].id : module.standards.cdap_vpc.id
  name   = "cmscloud-security-tools"
}

data "aws_security_group" "security_validation_egress" {
  count  = var.app == "bcda" ? 1 : 0
  vpc_id = module.vpc[0].id
  name   = "cms-cloud-security-validation-egress"
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_iam_policy" "secrets_manager_read_write" {
  arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

data "aws_iam_policy" "ssm_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = [
        "sts:AssumeRole",
        "sts:TagSession" ]
  }
}

data "aws_iam_policy_document" "codebuild" {

  # Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:us-east-1:${module.standards.account_id}:log-group:/aws/codebuild/*"]
  }

  # S3
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
    ]

    resources = ["arn:aws:s3:::codepipeline-us-east-1-*"]
  }

  # CodeBuild
  statement {
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages"
    ]

    resources = ["arn:aws:codebuild:us-east-1:${module.standards.account_id}:report-group/*"]
  }

  # EC2
  statement {
    actions   = ["ec2:DescribeImages"]
    resources = ["*"]
  }

  # VPC
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateNetworkInterfacePermission",
    ]

    resources = ["arn:aws:ec2:us-east-1:${module.standards.account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values = [
        for subnet in module.subnets.ids : "arn:aws:ec2:us-east-1:${module.standards.account_id}:subnet/${subnet}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }
}
