data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}


resource "aws_iam_role" "runner" {
  name = "github-actions-runner-role"
  path = "/delegatedadmin/developer/"

  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn

  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = var.runner_arn
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "all_within_boundary"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}
