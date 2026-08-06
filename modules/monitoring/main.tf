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
  description = "Name prefix for log groups"
  type        = string
}

variable "retention_in_days" {
  description = "CloudWatch Logs retention"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}

locals {
  log_groups = {
    api         = "/cloudsearch/${var.name}/api"
    ingestion   = "/cloudsearch/${var.name}/ingestion"
    frontend    = "/cloudsearch/${var.name}/frontend"
    eks_cluster = "/aws/eks/${var.name}/cluster"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_groups

  name              = each.value
  retention_in_days = var.retention_in_days

  tags = merge(var.tags, {
    Name    = each.value
    Service = each.key
  })
}

output "log_group_names" {
  description = "Map of service key to log group name"
  value       = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}

output "log_group_arns" {
  description = "Map of service key to log group ARN"
  value       = { for k, g in aws_cloudwatch_log_group.this : k => g.arn }
}
