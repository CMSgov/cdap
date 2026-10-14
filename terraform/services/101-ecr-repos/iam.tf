locals {
  cross_ecr_access_account_ids = [
    for account_id in var.cross_ecr_access_account_ids : "arn:aws:iam::${account_id}:root"
  ]

  enable_cross_account_policy = var.permitted_cross_accounts && length(local.cross_ecr_access_account_ids) > 0
}

data "aws_iam_policy_document" "cross_account" {
  count = local.enable_cross_account_policy ? 1 : 0

  statement {
    sid    = "AllowCrossAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.cross_ecr_access_account_ids
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]

    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_ecr_repository_policy" "cross_account" {
  count      = local.enable_cross_account_policy ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.cross_account[0].json
}