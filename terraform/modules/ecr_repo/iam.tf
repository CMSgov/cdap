data "aws_iam_policy_document" "cross_account_pull" {
  count = length(var.external_account_share) > 0 ? 1 : 0

  statement {
    sid    = "CrossAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for account_id in var.external_account_share : "arn:aws:iam::${account_id}:root"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "cross_account" {
  count      = length(var.external_account_share) > 0 ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.cross_account_pull[0].json
}
