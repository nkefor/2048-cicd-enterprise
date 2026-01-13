terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration should be provided via backend config file
    # Example: terraform init -backend-config=environments/prod/backend.hcl
    key            = "2048-cicd/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "2048-cicd-enterprise"
    }
  }
}

# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name          = var.project_name
  environment           = var.environment
  image_tag_mutability  = var.ecr_image_tag_mutability
  scan_on_push          = var.ecr_scan_on_push
  lifecycle_policy      = var.ecr_lifecycle_policy
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_http2            = var.alb_enable_http2
  enable_access_logs      = var.alb_enable_access_logs
  access_logs_bucket      = var.alb_access_logs_bucket
  ssl_certificate_arn     = var.ssl_certificate_arn
  enable_https            = var.enable_https
}

# ECS Module with Blue-Green Deployment Support
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  ecr_repository_url          = module.ecr.repository_url
  alb_target_group_blue_arn   = module.alb.target_group_blue_arn
  alb_target_group_green_arn  = module.alb.target_group_green_arn
  alb_security_group_id       = module.alb.alb_security_group_id

  # Task configuration
  task_cpu                    = var.ecs_task_cpu
  task_memory                 = var.ecs_task_memory
  container_port              = var.container_port
  desired_count               = var.ecs_desired_count
  min_capacity                = var.ecs_min_capacity
  max_capacity                = var.ecs_max_capacity

  # Auto-scaling configuration
  cpu_target_value            = var.ecs_cpu_target_value
  memory_target_value         = var.ecs_memory_target_value

  # Deployment configuration
  deployment_controller_type  = var.deployment_controller_type
  enable_blue_green           = var.enable_blue_green_deployment
  health_check_grace_period   = var.health_check_grace_period

  # CloudWatch logging
  log_retention_days          = var.log_retention_days
}
