# ==============================================================================
# Terraform Outputs - Printed after `terraform apply`
# ==============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket for generated reports"
  value       = aws_s3_bucket.reports.bucket
}

output "sqs_queue_url" {
  description = "URL of the main SQS report queue (used by Backend and Report Worker)"
  value       = aws_sqs_queue.report_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the main SQS report queue"
  value       = aws_sqs_queue.report_queue.arn
}

output "sqs_dlq_url" {
  description = "URL of the SQS Dead-Letter Queue for failed report jobs"
  value       = aws_sqs_queue.report_dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN of the SQS Dead-Letter Queue"
  value       = aws_sqs_queue.report_dlq.arn
}
