data "aws_iam_policy_document" "github_actions_messaging" {
  # EventBridge
  statement {
    sid = "EventbridgeRead"
    actions = [
      "events:DescribeRule",
      "events:List*",
    ]
    resources = ["*"]
  }

  # EventBridge Write
  statement {
    sid = "EventbridgeWrite"
    actions = [
      "events:DeleteRule",
      "events:DisableRule",
      "events:EnableRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:TagResource",
      "events:UntagResource",
    ]
    resources = [
      "arn:aws:events:*:*:rule/${var.app}-${var.env}-*",
    ]
  }

  # EventBridge Scheduler Read
  statement {
    sid = "SchedulerRead"
    actions = [
      "scheduler:GetSchedule",
      "scheduler:ListSchedules",
      "scheduler:ListTagsForResource",
    ]
    resources = [
      "arn:aws:scheduler:*:*:schedule/default/${var.app}-${var.env}-*",
    ]
  }

  # Scheduler Write
  statement {
    sid = "SchedulerWrite"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:DeleteSchedule",
      "scheduler:TagResource",
      "scheduler:UntagResource",
      "scheduler:UpdateSchedule",
    ]
    resources = [
      "arn:aws:scheduler:*:*:schedule/default/${var.app}-${var.env}-*",
    ]
  }

  # Lambda Read
  statement {
    sid = "LambdaRead"
    actions = [
      "lambda:Get*",
      "lambda:List*",
    ]
    resources = [
      "arn:aws:lambda:*:*:function:${var.app}-${var.env}-*",
    ]
  }

  # Lambda Write
  statement {
    sid = "LambdaWrite"
    actions = [
      "lambda:AddPermission",
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:InvokeFunction",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
    ]
    resources = [
      "arn:aws:lambda:*:*:function:${var.app}-${var.env}-*",
    ]
  }

  # Lambda Event Source Mappings — use UUID-based ARNs, cannot be name-scoped
  statement {
    sid = "LambdaEventSourceMapping"
    actions = [
      "lambda:CreateEventSourceMapping",
      "lambda:DeleteEventSourceMapping",
      "lambda:GetEventSourceMapping",
      "lambda:ListEventSourceMappings",
      "lambda:UpdateEventSourceMapping",
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
      "arn:aws:sqs:*:*:${var.app}-${var.env}-*"
    ]
  }

  # SQS Read — own queues
  statement {
    sid = "SqsRead"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:List*",
    ]
    resources = [
      "arn:aws:sqs:*:*:${var.app}-${var.env}-*",
      "arn:aws:sqs:*:*:${local.cdap_env}-alarm-to-slack",
    ]
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
    resources = ["arn:aws:sns:*:*:${var.app}-${var.env}-*"]
  }
}
