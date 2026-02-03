# ============================================================
# Terraform Configuration - Root Module
# ============================================================
# Provisions the complete AWS infrastructure for the 2048 game
# CI/CD platform with blue/green deployment support.
#
# Usage:
#   cd infra
#   terraform init
#   terraform plan -var-file="environments/prod.tfvars"
#   terraform apply -var-file="environments/prod.tfvars"
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state storage - uncomment and configure for production
  # backend "s3" {
  #   bucket         = "game-2048-terraform-state"
  #   key            = "game-2048/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "game-2048-terraform-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "nkefor/2048-cicd-enterprise"
    }
  }
}

# Current AWS account and region info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Use first 2 AZs for multi-AZ deployment
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Common name prefix for all resources
  name_prefix = var.project_name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
