# Terraform configuration for Cloud Resume Challenge

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloud-resume-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloud-resume-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Cloud-Resume-Challenge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ACM Certificate must be in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "Cloud-Resume-Challenge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
