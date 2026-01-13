# Backend configuration for production environment
# Usage: terraform init -backend-config=environments/prod/backend.hcl

bucket         = "terraform-state-2048-cicd-prod"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-prod"
encrypt        = true
