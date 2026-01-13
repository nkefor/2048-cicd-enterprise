# Backend configuration for development environment
# Usage: terraform init -backend-config=environments/dev/backend.hcl

bucket         = "terraform-state-2048-cicd-dev"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-dev"
encrypt        = true
