data "aws_iam_policy_document" "ecr_access_policy" {
  statement {
    sid = "ECRDiscovery"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    # DescribeRepositories has no resource-level scoping, so discovery
    # must be account-wide. Deletion below IS scoped.
    resources = ["*"]
  }

  statement {
    sid     = "ECRImageDelete"
    actions = ["ecr:BatchDeleteImage"]
    resources = [
      for repo in local.opted_in_repos :
      "arn:aws:ecr:${module.platform.primary_region.name}:${module.platform.account_id}:repository/${repo}"
    ] # images with opt-in only
  }
}

data "aws_iam_policy_document" "ecs_access_policy" {
  statement {
    sid = "ECSReadAccess"
    actions = [
      "ecs:ListClusters",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecr_cleanup" {
  source_policy_documents = [
    data.aws_iam_policy_document.ecr_access_policy.json,
    data.aws_iam_policy_document.ecs_access_policy.json,
  ]
}
