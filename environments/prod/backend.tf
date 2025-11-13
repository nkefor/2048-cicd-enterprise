# Backend Configuration for Production Environment
# This stores Terraform state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "2048-cicd-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-prod"

    # Workspace configuration
    workspace_key_prefix = "workspaces"

    # Additional security for production
    versioning = true

    # Prevent accidental deletion
    lifecycle {
      prevent_destroy = true
    }
  }
}

# State locking prevents concurrent modifications
# DynamoDB table must be created before using this backend
# Table name: terraform-state-lock-prod
# Primary key: LockID (String)
#
# IMPORTANT: Production state is critical
# - Enable S3 versioning
# - Enable S3 bucket encryption
# - Restrict access with IAM policies
# - Enable MFA delete protection
