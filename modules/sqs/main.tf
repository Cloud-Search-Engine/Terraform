terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" {
  description = "Base name for the ingestion queue"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for the main queue"
  type        = number
  default     = 300
}

variable "message_retention_seconds" {
  description = "Message retention for the main queue"
  type        = number
  default     = 345600 # 4 days
}

variable "dlq_message_retention_seconds" {
  description = "Message retention for the DLQ"
  type        = number
  default     = 1209600 # 14 days
}

variable "max_receive_count" {
  description = "Receives before message is moved to DLQ"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-ingestion-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = merge(var.tags, { Name = "${var.name}-ingestion-dlq" })
}

resource "aws_sqs_queue" "ingestion" {
  name                       = "${var.name}-ingestion"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, { Name = "${var.name}-ingestion" })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.ingestion.arn]
  })
}

output "queue_url" {
  description = "Ingestion queue URL"
  value       = aws_sqs_queue.ingestion.url
}

output "queue_arn" {
  description = "Ingestion queue ARN"
  value       = aws_sqs_queue.ingestion.arn
}

output "queue_name" {
  description = "Ingestion queue name"
  value       = aws_sqs_queue.ingestion.name
}

output "dlq_url" {
  description = "Dead-letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "Dead-letter queue ARN"
  value       = aws_sqs_queue.dlq.arn
}
