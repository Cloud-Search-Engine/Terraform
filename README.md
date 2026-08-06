# CloudSearch Terraform

Provisions **AWS infrastructure** for Cloud Search Engine. Application manifests live in the **Kubernetes** repo. Local AWS emulation uses docker-compose + LocalStack (not this repo).

## What’s in this repo

| Path | Purpose |
| --- | --- |
| `modules/networking` | VPC, subnets, IGW, NAT |
| `modules/eks` | EKS cluster, OIDC, node group |
| `modules/rds` | PostgreSQL (apply pgvector via Database migrations) |
| `modules/redis` | ElastiCache Redis |
| `modules/s3` | Documentation / raw ingest bucket |
| `modules/sqs` | Ingestion queue + DLQ |
| `modules/iam` | IRSA roles for API & ingestion |
| `modules/monitoring` | CloudWatch log groups |
| `environments/dev` | Smaller / cheaper defaults |
| `environments/prod` | Multi-AZ / larger sizing |

## Prerequisites

- Terraform **>= 1.5**
- AWS credentials with rights to create VPC/EKS/RDS/etc.
- Optional: remote state bucket (see `backend.tf` placeholders)

## How to start (dev)

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit docs_bucket_name (must be globally unique)

terraform init
terraform plan
terraform apply
```

After apply:

1. Apply **Database** migrations to the RDS endpoint.
2. Create Kubernetes secrets from Terraform outputs.
3. Deploy workloads: `kubectl apply -k` from the **Kubernetes** repo.

## Useful outputs → Kubernetes

| Output | Used as |
| --- | --- |
| `rds_database_url` | Secret `DATABASE_URL` |
| `redis_url` | Secret `REDIS_URL` |
| `sqs_queue_url` | Secret `SQS_QUEUE_URL` |
| `docs_bucket_name` | Secret `S3_BUCKET` |
| `api_irsa_role_arn` | API ServiceAccount annotation |
| `ingestion_irsa_role_arn` | Ingestion ServiceAccount annotation |

## Local vs AWS

| Environment | Tooling |
| --- | --- |
| Laptop | `docker compose` + LocalStack (parent folder) |
| AWS | **This Terraform** → EKS ← **Kubernetes** manifests |
