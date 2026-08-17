data "aws_iam_policy_document" "github_actions_messaging" {
  # EventBridge
  statement {
    actions = [
      "events:DescribeRule",
      "events:List*",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
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
      "lambda:RemovePermission",
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
      "sqs:GetQueueUrl",
      "sqs:List*",
    ]
    resources = ["*"]
  }
  # SNS
  statement {
    sid = "SnsRead"
    actions = [
      "sns:GetSubscriptionAttributes",
      "sns:GetTopicAttributes",
      "sns:List*",
    ]
    resources = ["*"]
  }

  # SNS Write
  statement {
    sid = "SnsWrite"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:SetSubscriptionAttributes",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = ["*"]
  }
}
