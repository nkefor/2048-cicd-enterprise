# AWS Verified Access - Zero-Trust Access Implementation
# Provides secure, zero-trust access to healthcare applications

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Verified Access Instance
resource "aws_verifiedaccess_instance" "healthcare" {
  description = "Zero-Trust Access for Healthcare Applications"

  tags = {
    Name        = "${var.environment}-healthcare-verified-access"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Verified Access Trust Provider (OIDC with Cognito)
resource "aws_verifiedaccess_trust_provider" "cognito_oidc" {
  policy_reference_name    = "CognitoHealthcareProvider"
  trust_provider_type      = "user"
  user_trust_provider_type = "oidc"

  oidc_options {
    client_id              = aws_cognito_user_pool_client.healthcare_client.id
    client_secret          = aws_cognito_user_pool_client.healthcare_client.client_secret
    issuer                 = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.healthcare.id}"
    authorization_endpoint = "https://${aws_cognito_user_pool_domain.healthcare.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/authorize"
    token_endpoint         = "https://${aws_cognito_user_pool_domain.healthcare.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
    user_info_endpoint     = "https://${aws_cognito_user_pool_domain.healthcare.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/userInfo"
    scope                  = "openid email profile"
  }

  tags = {
    Name        = "${var.environment}-cognito-trust-provider"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Verified Access Trust Provider (Device Trust)
resource "aws_verifiedaccess_trust_provider" "device_trust" {
  policy_reference_name    = "DeviceTrustProvider"
  trust_provider_type      = "device"
  device_trust_provider_type = "crowdstrike"

  device_options {
    tenant_id = var.crowdstrike_tenant_id
  }

  tags = {
    Name        = "${var.environment}-device-trust-provider"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Attach Trust Providers to Instance
resource "aws_verifiedaccess_instance_trust_provider_attachment" "cognito_attachment" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.healthcare.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.cognito_oidc.id
}

resource "aws_verifiedaccess_instance_trust_provider_attachment" "device_attachment" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.healthcare.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.device_trust.id
}

# Verified Access Group
resource "aws_verifiedaccess_group" "healthcare_applications" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.healthcare.id
  description                = "Access group for healthcare applications"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireAuthenticatedUser"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringEquals = {
            "verified-access:user-authenticated" = "true"
            "verified-access:device-trusted"     = "true"
          }
        }
      },
      {
        Sid    = "RequireMFA"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringEquals = {
            "verified-access:mfa-authenticated" = "true"
          }
        }
      },
      {
        Sid    = "RequireHealthcareRole"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringLike = {
            "verified-access:user-groups" = [
              "Healthcare_Administrators",
              "Healthcare_Providers",
              "Healthcare_Staff"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-healthcare-applications-group"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Verified Access Endpoint for API Gateway
resource "aws_verifiedaccess_endpoint" "api_gateway" {
  application_domain       = var.api_gateway_domain
  attachment_type          = "vpc"
  domain_certificate_arn   = var.certificate_arn
  endpoint_domain_prefix   = "healthcare-api"
  endpoint_type           = "network-interface"
  verified_access_group_id = aws_verifiedaccess_group.healthcare_applications.id
  description             = "Verified Access endpoint for Healthcare API Gateway"

  network_interface_options {
    network_interface_id = var.api_gateway_network_interface_id
    port                = 443
    protocol            = "https"
  }

  load_balancer_options {
    load_balancer_arn = var.alb_arn
    port             = 443
    protocol         = "https"
    subnet_ids       = var.private_subnet_ids
  }

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowHealthcareAPIAccess"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringEquals = {
            "verified-access:user-authenticated" = "true"
            "verified-access:device-trusted"     = "true"
          }
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Sid    = "DenyUnencryptedConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-api-gateway-endpoint"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Verified Access Endpoint for Web Application
resource "aws_verifiedaccess_endpoint" "web_application" {
  application_domain       = var.web_app_domain
  attachment_type          = "vpc"
  domain_certificate_arn   = var.certificate_arn
  endpoint_domain_prefix   = "healthcare-portal"
  endpoint_type           = "load-balancer"
  verified_access_group_id = aws_verifiedaccess_group.healthcare_applications.id
  description             = "Verified Access endpoint for Healthcare Web Portal"

  load_balancer_options {
    load_balancer_arn = var.web_alb_arn
    port             = 443
    protocol         = "https"
    subnet_ids       = var.private_subnet_ids
  }

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowHealthcarePortalAccess"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringEquals = {
            "verified-access:user-authenticated" = "true"
            "verified-access:device-trusted"     = "true"
            "verified-access:mfa-authenticated"  = "true"
          }
        }
      },
      {
        Sid    = "RestrictAccessByRole"
        Effect = "Allow"
        Principal = "*"
        Action = "verified-access:connect"
        Resource = "*"
        Condition = {
          StringLike = {
            "verified-access:user-groups" = [
              "Healthcare_Providers",
              "Healthcare_Administrators"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-web-portal-endpoint"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# CloudWatch Log Group for Verified Access Logs
resource "aws_cloudwatch_log_group" "verified_access_logs" {
  name              = "/aws/verifiedaccess/${var.environment}-healthcare"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.environment}-verified-access-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Verified Access Instance Logging Configuration
resource "aws_verifiedaccess_instance_logging_configuration" "healthcare" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.healthcare.id

  access_logs {
    cloudwatch_logs {
      enabled   = true
      log_group = aws_cloudwatch_log_group.verified_access_logs.name
    }

    s3 {
      enabled     = true
      bucket_name = var.access_logs_bucket
      prefix      = "verified-access-logs/"
    }

    kinesis_data_firehose {
      enabled         = true
      delivery_stream = var.log_delivery_stream_arn
    }
  }
}

# CloudWatch Alarms for Verified Access
resource "aws_cloudwatch_metric_alarm" "access_denied" {
  alarm_name          = "${var.environment}-verified-access-denied"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AccessDenied"
  namespace           = "AWS/VerifiedAccess"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when access is denied frequently"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    VerifiedAccessInstanceId = aws_verifiedaccess_instance.healthcare.id
  }
}

resource "aws_cloudwatch_metric_alarm" "untrusted_device_attempts" {
  alarm_name          = "${var.environment}-untrusted-device-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UntrustedDeviceAttempts"
  namespace           = "AWS/VerifiedAccess"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when untrusted devices attempt access"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    VerifiedAccessInstanceId = aws_verifiedaccess_instance.healthcare.id
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "api_gateway_domain" {
  description = "Domain name for API Gateway"
  type        = string
}

variable "web_app_domain" {
  description = "Domain name for web application"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of ACM certificate"
  type        = string
}

variable "alb_arn" {
  description = "ARN of Application Load Balancer for API"
  type        = string
}

variable "web_alb_arn" {
  description = "ARN of Application Load Balancer for web app"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs"
  type        = string
}

variable "log_delivery_stream_arn" {
  description = "ARN of Kinesis Data Firehose delivery stream"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of SNS topic for alarms"
  type        = string
}

variable "crowdstrike_tenant_id" {
  description = "CrowdStrike tenant ID for device trust"
  type        = string
  default     = ""
}

variable "api_gateway_network_interface_id" {
  description = "Network interface ID for API Gateway"
  type        = string
}

# Outputs
output "verified_access_instance_id" {
  description = "ID of the Verified Access instance"
  value       = aws_verifiedaccess_instance.healthcare.id
}

output "verified_access_group_id" {
  description = "ID of the Verified Access group"
  value       = aws_verifiedaccess_group.healthcare_applications.id
}

output "api_endpoint_domain" {
  description = "Domain name for API endpoint"
  value       = aws_verifiedaccess_endpoint.api_gateway.endpoint_domain
}

output "web_endpoint_domain" {
  description = "Domain name for web endpoint"
  value       = aws_verifiedaccess_endpoint.web_application.endpoint_domain
}
