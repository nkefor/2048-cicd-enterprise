# Variables for Enterprise Healthcare DevOps Platform

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "allowed_countries" {
  description = "List of allowed country codes for WAF geo-blocking"
  type        = list(string)
  default     = ["US", "CA"]
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Healthcare-IT"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevOps-Team"
}

variable "organization_id" {
  description = "AWS Organization ID for SCPs"
  type        = string
  default     = ""
}

variable "allowed_regions" {
  description = "List of allowed AWS regions for SCP"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# HIPAA Compliance Settings
variable "enable_hipaa_compliance" {
  description = "Enable HIPAA compliance features"
  type        = bool
  default     = true
}

variable "audit_log_retention_days" {
  description = "CloudTrail audit log retention (HIPAA requires 6 years = 2190 days)"
  type        = number
  default     = 2190
}

variable "encryption_key_rotation_enabled" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

variable "mfa_required" {
  description = "Require MFA for all users"
  type        = bool
  default     = true
}

# Alerting Configuration
variable "security_alert_email" {
  description = "Email address for security alerts"
  type        = string
}

variable "compliance_alert_email" {
  description = "Email address for compliance alerts"
  type        = string
}

variable "operational_alert_email" {
  description = "Email address for operational alerts"
  type        = string
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be PROVISIONED or PAY_PER_REQUEST."
  }
}

# Step Functions Configuration
variable "enable_step_functions" {
  description = "Enable AWS Step Functions for workflow orchestration"
  type        = bool
  default     = true
}

# Comprehend Medical Configuration
variable "enable_comprehend_medical" {
  description = "Enable Amazon Comprehend Medical for AI-driven data extraction"
  type        = bool
  default     = true
}

# Verified Access Configuration
variable "enable_verified_access" {
  description = "Enable AWS Verified Access for Zero-Trust"
  type        = bool
  default     = true
}

variable "verified_access_trust_provider" {
  description = "Identity provider for Verified Access (okta, azure-ad, jamf)"
  type        = string
  default     = "okta"
}

# Backup Configuration
variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 35
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = true
}

variable "backup_region" {
  description = "Secondary region for backup replication"
  type        = string
  default     = "us-west-2"
}
