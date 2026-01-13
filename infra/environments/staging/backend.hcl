# Backend configuration for staging environment
# Usage: terraform init -backend-config=environments/staging/backend.hcl

bucket         = "terraform-state-2048-cicd-staging"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-staging"
encrypt        = true
