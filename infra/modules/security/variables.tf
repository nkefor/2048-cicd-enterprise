# Security Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "mfa_configuration" {
  description = "MFA configuration (ON, OFF, OPTIONAL)"
  type        = string
  default     = "ON"
  validation {
    condition     = contains(["ON", "OFF", "OPTIONAL"], var.mfa_configuration)
    error_message = "MFA configuration must be ON, OFF, or OPTIONAL."
  }
}

variable "enable_waf" {
  description = "Enable WAF for API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "allowed_countries" {
  description = "List of allowed country codes"
  type        = list(string)
  default     = ["US", "CA"]
}
