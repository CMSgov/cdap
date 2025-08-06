data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "current" {}

data "aws_iam_policy_document" "cdap_vault_key_policy" {
  statement {
    sid    = "Enable IAM policy usage for key management"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = [
      "*"
    ]
  }
}

data "aws_iam_role" "backup_service_role" {
  name = "AWSServiceRoleForBackup"
}
