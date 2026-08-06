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
  description = "Name prefix for IRSA roles"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer host path (without https://)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for ServiceAccounts"
  type        = string
  default     = "cloudsearch"
}

variable "api_service_account" {
  description = "API ServiceAccount name"
  type        = string
  default     = "cloudsearch-api"
}

variable "ingestion_service_account" {
  description = "Ingestion ServiceAccount name"
  type        = string
  default     = "cloudsearch-ingestion"
}

variable "s3_bucket_arn" {
  description = "Documents S3 bucket ARN"
  type        = string
}

variable "sqs_queue_arn" {
  description = "Ingestion SQS queue ARN"
  type        = string
}

variable "sqs_dlq_arn" {
  description = "Ingestion DLQ ARN"
  type        = string
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}

locals {
  api_sa_sub       = "system:serviceaccount:${var.namespace}:${var.api_service_account}"
  ingestion_sa_sub = "system:serviceaccount:${var.namespace}:${var.ingestion_service_account}"
}

data "aws_iam_policy_document" "api_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.api_sa_sub]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ingestion_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.ingestion_sa_sub]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${var.name}-api-irsa"
  assume_role_policy = data.aws_iam_policy_document.api_assume.json

  tags = merge(var.tags, { Name = "${var.name}-api-irsa" })
}

resource "aws_iam_role" "ingestion" {
  name               = "${var.name}-ingestion-irsa"
  assume_role_policy = data.aws_iam_policy_document.ingestion_assume.json

  tags = merge(var.tags, { Name = "${var.name}-ingestion-irsa" })
}

# API: read objects (search may fetch metadata / signed URLs later)
data "aws_iam_policy_document" "api" {
  statement {
    sid    = "S3ReadDocs"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "${var.name}-api-policy"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}

# Ingestion workers: S3 read/write + SQS consume/produce
data "aws_iam_policy_document" "ingestion" {
  statement {
    sid    = "S3Docs"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "SQSIngestion"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility",
      "sqs:SendMessage",
    ]
    resources = [
      var.sqs_queue_arn,
      var.sqs_dlq_arn,
    ]
  }
}

resource "aws_iam_role_policy" "ingestion" {
  name   = "${var.name}-ingestion-policy"
  role   = aws_iam_role.ingestion.id
  policy = data.aws_iam_policy_document.ingestion.json
}

output "api_role_arn" {
  description = "IRSA role ARN for cloudsearch-api ServiceAccount"
  value       = aws_iam_role.api.arn
}

output "ingestion_role_arn" {
  description = "IRSA role ARN for cloudsearch-ingestion ServiceAccount"
  value       = aws_iam_role.ingestion.arn
}

output "api_role_name" {
  description = "API IRSA role name"
  value       = aws_iam_role.api.name
}

output "ingestion_role_name" {
  description = "Ingestion IRSA role name"
  value       = aws_iam_role.ingestion.name
}
