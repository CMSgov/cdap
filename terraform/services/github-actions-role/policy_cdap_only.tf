# policy_cdap.tf

data "aws_iam_policy_document" "github_actions_cdap" {
  # CodeBuild - managed by CDAP terraservice
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

  # Secrets Manager - only CDAP uses this
  statement {
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteResourcePolicy",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
    ]
    resources = ["*"]
  }

  # Add other CDAP-only services here as needed...
}

resource "aws_iam_policy" "github_actions_cdap" {
  count  = var.app == "cdap" ? 1 : 0
  name   = "${var.app}-${var.env}-github-actions-cdap"
  path   = "/delegatedadmin/developer/"
  policy = data.aws_iam_policy_document.github_actions_cdap.json
}
