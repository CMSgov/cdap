output "arn" {
  description = "ARN for the queue"
  value       = aws_sqs_queue.this.arn
}
