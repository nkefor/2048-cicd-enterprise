# Monitoring Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS Key ARN for encryption"
  type        = string
}

variable "cloudtrail_s3_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub"
  type        = bool
  default     = true
}

variable "security_standards" {
  description = "List of security standards to enable"
  type        = list(string)
  default     = []
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_macie" {
  description = "Enable Amazon Macie"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

variable "enable_log_encryption" {
  description = "Enable CloudWatch log encryption"
  type        = bool
  default     = true
}
