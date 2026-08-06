terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cloudsearch"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.name_prefix
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project     = "cloudsearch"
    Environment = "prod"
  }
}

module "networking" {
  source = "../../modules/networking"

  name                 = local.name
  cidr_block           = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = false
  tags                 = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = "${local.name}-eks"
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.networking.vpc_id
  subnet_ids          = concat(module.networking.private_subnet_ids, module.networking.public_subnet_ids)
  node_subnet_ids     = module.networking.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_disk_size      = 100
  tags                = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name                       = local.name
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  allowed_cidr_blocks        = [module.networking.vpc_cidr_block]
  instance_class             = var.rds_instance_class
  allocated_storage          = var.rds_allocated_storage
  max_allocated_storage      = 500
  multi_az                   = true
  backup_retention_period    = 14
  skip_final_snapshot        = false
  tags                       = local.tags
}

module "redis" {
  source = "../../modules/redis"

  name                       = local.name
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  node_type                  = var.redis_node_type
  num_cache_nodes            = 2
  tags                       = local.tags
}

module "s3" {
  source = "../../modules/s3"

  bucket_name       = var.docs_bucket_name
  force_destroy     = false
  enable_versioning = true
  tags              = local.tags
}

module "sqs" {
  source = "../../modules/sqs"

  name                       = local.name
  visibility_timeout_seconds = 600
  max_receive_count          = 5
  tags                       = local.tags
}

module "iam" {
  source = "../../modules/iam"

  name              = local.name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "cloudsearch"
  s3_bucket_arn     = module.s3.bucket_arn
  sqs_queue_arn     = module.sqs.queue_arn
  sqs_dlq_arn       = module.sqs.dlq_arn
  tags              = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name              = local.name
  retention_in_days = 30
  tags              = local.tags
}
