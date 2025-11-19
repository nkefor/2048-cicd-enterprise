variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Domain name for the resume website (e.g., resume.yourdomain.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cloud-resume"
}
