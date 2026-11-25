# ==============================================================================
# Terraform Input Variables for XEV 9S AWS Simulation (LocalStack)
# ==============================================================================

variable "aws_region" {
  description = "AWS region simulated by LocalStack"
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack gateway URL for simulated AWS APIs"
  type        = string
  default     = "http://localhost:4566"
}

variable "report_bucket_name" {
  description = "Name of the S3 bucket that stores generated PDF/CSV trip reports"
  type        = string
  default     = "xev9s-reports"
}

variable "report_queue_name" {
  description = "Name of the primary SQS queue for asynchronous report requests"
  type        = string
  default     = "xev9s-report-queue"
}

variable "report_dlq_name" {
  description = "Name of the SQS Dead-Letter Queue (DLQ) for failed report jobs"
  type        = string
  default     = "xev9s-report-dlq"
}

variable "max_receive_count" {
  description = "Number of failed processing attempts before moving a job to the DLQ"
  type        = number
  default     = 3
}
