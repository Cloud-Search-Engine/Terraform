output "vpc_id" {
  value = module.networking.vpc_id
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "rds_database_url" {
  value     = module.rds.database_url
  sensitive = true
}

output "redis_url" {
  value = module.redis.redis_url
}

output "docs_bucket_name" {
  value = module.s3.bucket_id
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_dlq_url" {
  value = module.sqs.dlq_url
}

output "api_irsa_role_arn" {
  value = module.iam.api_role_arn
}

output "ingestion_irsa_role_arn" {
  value = module.iam.ingestion_role_arn
}

output "log_group_names" {
  value = module.monitoring.log_group_names
}
