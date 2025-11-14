# Enterprise Healthcare DevOps Platform - Main Terraform Configuration
# HIPAA/HITRUST/NIST 800-53 Compliant Infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "healthcare-devops-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project             = "Healthcare-DevOps-Platform"
      Environment         = var.environment
      ManagedBy          = "Terraform"
      ComplianceFramework = "HIPAA-HITRUST-NIST-800-53"
      DataClassification  = "PHI"
      CostCenter         = var.cost_center
      Owner              = var.owner
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Local variables
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project     = "Healthcare-DevOps-Platform"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  environment         = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_flow_logs   = true
  enable_vpc_endpoints = true
}

# Security Module
module "security" {
  source = "./modules/security"

  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  account_id     = local.account_id
  domain_name    = var.domain_name

  # Cognito configuration
  cognito_user_pool_name = "${var.environment}-healthcare-users"
  mfa_configuration      = "ON"

  # WAF configuration
  enable_waf             = true
  waf_rate_limit        = 2000
  allowed_countries     = var.allowed_countries
}

# Compute Module
module "compute" {
  source = "./modules/compute"

  environment           = var.environment
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  security_group_ids   = [module.security.lambda_security_group_id]
  kms_key_arn          = module.security.kms_key_arn

  # API Gateway configuration
  api_gateway_name     = "${var.environment}-healthcare-api"
  cognito_user_pool_arn = module.security.cognito_user_pool_arn
}

# Data Module
module "data" {
  source = "./modules/data"

  environment    = var.environment
  kms_key_arn    = module.security.kms_key_arn

  # DynamoDB configuration
  enable_point_in_time_recovery = true
  enable_deletion_protection     = var.environment == "production" ? true : false

  # S3 configuration
  enable_versioning              = true
  enable_object_lock            = var.environment == "production" ? true : false
  lifecycle_rules_enabled       = true
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  environment    = var.environment
  account_id     = local.account_id
  region         = local.region
  kms_key_arn    = module.security.kms_key_arn

  # CloudTrail configuration
  enable_cloudtrail           = true
  cloudtrail_s3_bucket       = module.data.cloudtrail_bucket_name

  # GuardDuty configuration
  enable_guardduty            = true

  # Security Hub configuration
  enable_security_hub         = true
  security_standards          = ["aws-foundational-security-best-practices", "cis-aws-foundations-benchmark", "pci-dss", "nist-800-53"]

  # Config configuration
  enable_config               = true

  # Macie configuration
  enable_macie                = true

  # CloudWatch configuration
  log_retention_days         = 365
  enable_log_encryption      = true
}

# AI/ML Module
module "ai_ml" {
  source = "./modules/ai-ml"

  environment = var.environment
  region      = local.region
}

# Governance Module
module "governance" {
  source = "./modules/governance"

  environment         = var.environment
  organization_id     = var.organization_id
  allowed_regions     = var.allowed_regions
  require_mfa         = true
  require_encryption  = true
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.compute.api_gateway_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.security.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.security.cognito_user_pool_client_id
  sensitive   = true
}

output "dynamodb_table_names" {
  description = "DynamoDB table names"
  value       = module.data.dynamodb_table_names
}

output "s3_bucket_names" {
  description = "S3 bucket names"
  value       = module.data.s3_bucket_names
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${var.environment}-healthcare-dashboard"
}

output "security_hub_url" {
  description = "Security Hub Console URL"
  value       = "https://console.aws.amazon.com/securityhub/home?region=${local.region}"
}
