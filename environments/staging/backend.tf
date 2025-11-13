# Backend Configuration for Staging Environment
# This stores Terraform state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "2048-cicd-terraform-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-staging"

    # Workspace configuration
    workspace_key_prefix = "workspaces"
  }
}

# State locking prevents concurrent modifications
# DynamoDB table must be created before using this backend
# Table name: terraform-state-lock-staging
# Primary key: LockID (String)
