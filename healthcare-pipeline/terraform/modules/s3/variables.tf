# S3 Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "replication_region" {
  description = "AWS region for cross-region replication"
  type        = string
  default     = "us-west-2"
}

variable "lifecycle_rules" {
  description = "S3 lifecycle rules"
  type = list(object({
    id                       = string
    enabled                  = bool
    transition_days          = number
    transition_storage_class = string
    expiration_days          = number
  }))
  default = []
}

variable "enable_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for S3 buckets"
  type        = bool
  default     = false
}
