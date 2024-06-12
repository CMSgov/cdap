module "queue_key" {
  source      = "../key"
  name        = "${var.name}-queue"
  description = "For ${var.name} SQS queue"
  sns_topics  = var.sns_topic_arn != "None" ? [var.sns_topic_arn] : []
}

resource "aws_sqs_queue" "dead_letter" {
  name              = "${var.name}-dead-letter"
  kms_master_key_id = module.queue_key.id
}

resource "aws_sqs_queue" "this" {
  name              = var.name
  kms_master_key_id = module.queue_key.id

  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "this" {
  queue_url = aws_sqs_queue.dead_letter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

data "aws_iam_policy_document" "sns_send_message" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  statement {
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_sqs_queue.this.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.sns_topic_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sns_send_message" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.sns_send_message[0].json
}

resource "aws_sns_topic_subscription" "this" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  endpoint  = aws_sqs_queue.this.arn
  protocol  = "sqs"
  topic_arn = var.sns_topic_arn
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.this.arn
  function_name    = var.function_name
}
