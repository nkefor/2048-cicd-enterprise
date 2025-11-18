terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "soc2-compliance-terraform-state"
    key            = "compliance/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "soc2-compliance-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SOC2-Compliance-Automation"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Security-Compliance"
      Compliance  = "SOC2-Type-II"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local variables
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  prefix     = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Compliance  = "SOC2"
  }
}
