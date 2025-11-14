# Service Control Policies (SCPs) for Healthcare Compliance
# Organizational compliance boundaries for HIPAA, HITRUST, and NIST 800-53

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# HIPAA Compliance Policy
resource "aws_organizations_policy" "hipaa_compliance" {
  name        = "HIPAA-Compliance-Policy"
  description = "Enforces HIPAA compliance requirements across the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireEncryptionAtRest"
        Effect = "Deny"
        Action = [
          "s3:PutObject",
          "dynamodb:CreateTable",
          "rds:CreateDBInstance",
          "ebs:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = ["aws:kms", "AES256"]
          }
        }
      },
      {
        Sid    = "RequireEncryptionInTransit"
        Effect = "Deny"
        Action = [
          "s3:*",
          "dynamodb:*",
          "rds:*"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyPublicAccessToHealthcareData"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = ["public-read", "public-read-write"]
          }
        }
      },
      {
        Sid    = "RequireCloudTrailLogging"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "RequireMFAForSensitiveActions"
        Effect = "Deny"
        Action = [
          "iam:DeleteUser",
          "iam:DeleteRole",
          "kms:ScheduleKeyDeletion",
          "rds:DeleteDBInstance",
          "dynamodb:DeleteTable"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "HIPAA-Compliance-Policy"
    Compliance  = "HIPAA"
    Environment = var.environment
  }
}

# Data Residency Policy
resource "aws_organizations_policy" "data_residency" {
  name        = "Data-Residency-Policy"
  description = "Restricts PHI data to approved regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictRegionsForPHI"
        Effect = "Deny"
        Action = [
          "s3:CreateBucket",
          "dynamodb:CreateTable",
          "rds:CreateDBInstance",
          "ec2:RunInstances",
          "lambda:CreateFunction"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
        }
      }
    ]
  })

  tags = {
    Name        = "Data-Residency-Policy"
    Compliance  = "HIPAA"
    Environment = var.environment
  }
}

# Audit and Monitoring Policy
resource "aws_organizations_policy" "audit_monitoring" {
  name        = "Audit-And-Monitoring-Policy"
  description = "Prevents disabling of security and audit services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventDisablingSecurityServices"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "securityhub:DisableSecurityHub",
          "securityhub:DeleteInsight",
          "config:DeleteConfigurationRecorder",
          "config:StopConfigurationRecorder",
          "access-analyzer:DeleteAnalyzer"
        ]
        Resource = "*"
      },
      {
        Sid    = "RequireVPCFlowLogs"
        Effect = "Deny"
        Action = [
          "ec2:DeleteFlowLogs"
        ]
        Resource = "*"
      },
      {
        Sid    = "PreventCloudWatchLogsDeletion"
        Effect = "Deny"
        Action = [
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Compliance" = "HIPAA"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "Audit-And-Monitoring-Policy"
    Compliance  = "HIPAA"
    Environment = var.environment
  }
}

# NIST 800-53 Compliance Policy
resource "aws_organizations_policy" "nist_compliance" {
  name        = "NIST-800-53-Compliance-Policy"
  description = "Enforces NIST 800-53 security controls"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequirePrivateSubnetsForPHI"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "rds:PubliclyAccessible" = "true"
          }
        }
      },
      {
        Sid    = "RequireBackupRetention"
        Effect = "Deny"
        Action = [
          "rds:ModifyDBInstance",
          "dynamodb:UpdateContinuousBackups"
        ]
        Resource = "*"
        Condition = {
          NumericLessThan = {
            "rds:BackupRetentionPeriod" = "7"
          }
        }
      },
      {
        Sid    = "RequirePointInTimeRecovery"
        Effect = "Deny"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:UpdateContinuousBackups"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "dynamodb:PointInTimeRecoveryEnabled" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "NIST-800-53-Compliance-Policy"
    Compliance  = "NIST-800-53"
    Environment = var.environment
  }
}

# Access Control Policy
resource "aws_organizations_policy" "access_control" {
  name        = "Access-Control-Policy"
  description = "Enforces strict access control and tagging requirements"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventRootAccountUsage"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      },
      {
        Sid    = "RequireTagsForResources"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "s3:CreateBucket",
          "dynamodb:CreateTable",
          "rds:CreateDBInstance"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:RequestTag/Environment"  = "true"
            "aws:RequestTag/DataCategory" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "Access-Control-Policy"
    Compliance  = "HIPAA"
    Environment = var.environment
  }
}

# Attach policies to organizational units
resource "aws_organizations_policy_attachment" "hipaa_compliance_attachment" {
  count     = length(var.organizational_unit_ids)
  policy_id = aws_organizations_policy.hipaa_compliance.id
  target_id = var.organizational_unit_ids[count.index]
}

resource "aws_organizations_policy_attachment" "data_residency_attachment" {
  count     = length(var.organizational_unit_ids)
  policy_id = aws_organizations_policy.data_residency.id
  target_id = var.organizational_unit_ids[count.index]
}

resource "aws_organizations_policy_attachment" "audit_monitoring_attachment" {
  count     = length(var.organizational_unit_ids)
  policy_id = aws_organizations_policy.audit_monitoring.id
  target_id = var.organizational_unit_ids[count.index]
}

resource "aws_organizations_policy_attachment" "nist_compliance_attachment" {
  count     = length(var.organizational_unit_ids)
  policy_id = aws_organizations_policy.nist_compliance.id
  target_id = var.organizational_unit_ids[count.index]
}

resource "aws_organizations_policy_attachment" "access_control_attachment" {
  count     = length(var.organizational_unit_ids)
  policy_id = aws_organizations_policy.access_control.id
  target_id = var.organizational_unit_ids[count.index]
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "allowed_regions" {
  description = "List of allowed AWS regions for PHI data"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "organizational_unit_ids" {
  description = "List of organizational unit IDs to attach policies to"
  type        = list(string)
  default     = []
}

# Outputs
output "hipaa_compliance_policy_id" {
  description = "ID of the HIPAA compliance policy"
  value       = aws_organizations_policy.hipaa_compliance.id
}

output "data_residency_policy_id" {
  description = "ID of the data residency policy"
  value       = aws_organizations_policy.data_residency.id
}

output "audit_monitoring_policy_id" {
  description = "ID of the audit and monitoring policy"
  value       = aws_organizations_policy.audit_monitoring.id
}

output "nist_compliance_policy_id" {
  description = "ID of the NIST 800-53 compliance policy"
  value       = aws_organizations_policy.nist_compliance.id
}
