# Remote state backend (uncomment and configure before terraform init in CI / shared teams).
#
# terraform {
#   backend "s3" {
#     bucket         = "cloudsearch-terraform-state"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "cloudsearch-terraform-locks"
#     encrypt        = true
#   }
# }

# Until a remote backend is enabled, Terraform uses local state in this directory.
# Do not commit *.tfstate files.
