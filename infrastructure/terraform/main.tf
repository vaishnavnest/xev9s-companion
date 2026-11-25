# ==============================================================================
# XEV 9S Companion Platform - AWS Simulation Infrastructure (LocalStack)
# Provisions:
#   1. Amazon S3 Bucket (xev9s-reports) for generated PDF/CSV reports
#   2. Amazon SQS Dead-Letter Queue (xev9s-report-dlq) for failed jobs
#   3. Amazon SQS Main Queue (xev9s-report-queue) with retry & redrive policy
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider to talk to LocalStack instead of real AWS.
# Credentials are supplied via AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars.
provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Required so S3 calls use http://localhost:4566/<bucket> instead of <bucket>.localhost
  s3_use_path_style = true

  endpoints {
    s3  = var.localstack_endpoint
    sqs = var.localstack_endpoint
  }
}

# 1. S3 Bucket for storing generated vehicle trip & energy reports
resource "aws_s3_bucket" "reports" {
  bucket        = var.report_bucket_name
  force_destroy = true

  tags = {
    Project     = "xev9s-companion"
    Environment = "aws-simulation"
    ManagedBy   = "terraform"
  }
}

# 2. Dead-Letter Queue (receives messages that fail processing max_receive_count times)
resource "aws_sqs_queue" "report_dlq" {
  name                      = var.report_dlq_name
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Project     = "xev9s-companion"
    Environment = "aws-simulation"
    ManagedBy   = "terraform"
  }
}

# 3. Main SQS Queue for report generation requests
resource "aws_sqs_queue" "report_queue" {
  name                       = var.report_queue_name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 10    # Enable long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.report_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Project     = "xev9s-companion"
    Environment = "aws-simulation"
    ManagedBy   = "terraform"
  }
}
