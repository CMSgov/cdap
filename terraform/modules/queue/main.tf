data "aws_kms_alias" "kms_key" {
  name = "alias/${var.app}-${var.env}"
}

resource "aws_sqs_queue" "dead_letter" {
  name              = "${var.name}-dead-letter"
  kms_master_key_id = data.aws_kms_alias.kms_key.arn
}

resource "aws_sqs_queue" "this" {
  name              = var.name
  kms_master_key_id = data.aws_kms_alias.kms_key.arn

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

data "aws_iam_policy_document" "this" {
  source_policy_documents = var.policy_documents
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.this[0].json
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.this.arn
  function_name    = var.function_name
  batch_size       = 1
  enabled          = true
}
