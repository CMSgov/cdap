data "aws_iam_policy_document" "github_actions_messaging" {
  # EventBridge
  statement {
    actions = [
      "events:DescribeRule",
      "events:List*",
      "events:PutRule",
      "events:PutTargets",
      "events:TagResource",
      "events:UntagResource",
    ]
    resources = ["*"]
  }

  # Lambda
  statement {
    actions = [
      "lambda:AddPermission",
      "lambda:CreateEventSourceMapping",
      "lambda:CreateFunction",
      "lambda:Get*",
      "lambda:InvokeFunction",
      "lambda:List*",
      "lambda:TagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "sqs:CreateQueue",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
    ]
    resources = [
      "*" #FIXME arn:aws:sqs:*:*:${var.app}-${var.env}-*
    ]
  }

  statement {
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:List*",
    ]
    resources = ["*"]
  }
  # SNS
  statement {
    actions = [
      "sns:GetSubscriptionAttributes",
      "sns:GetTopicAttributes",
      "sns:List*",
    ]
    resources = ["*"]
  }
}
