# Governance Module - Service Control Policies (SCPs) for HIPAA Compliance

# SCP: Require Encryption in Transit
resource "aws_organizations_policy" "require_encryption_in_transit" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-require-encryption-in-transit"
  description = "Deny all requests that don't use HTTPS/TLS"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireEncryptionInTransit"
        Effect = "Deny"
        Action = "*"
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
    Name       = "${var.environment}-require-encryption-in-transit"
    Compliance = "HIPAA"
  }
}

# SCP: Require Encryption at Rest
resource "aws_organizations_policy" "require_encryption_at_rest" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-require-encryption-at-rest"
  description = "Require encryption at rest for all storage services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedS3Objects"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedDynamoDBTables"
        Effect = "Deny"
        Action = "dynamodb:CreateTable"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "dynamodb:Encryption" = "true"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedRDSInstances"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:CreateDBCluster"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedEBSVolumes"
        Effect = "Deny"
        Action = "ec2:CreateVolume"
        Resource = "*"
        Condition = {
          Bool = {
            "ec2:Encrypted" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-require-encryption-at-rest"
    Compliance = "HIPAA"
  }
}

# SCP: Restrict to Approved Regions
resource "aws_organizations_policy" "restrict_regions" {
  count = var.organization_id != "" && length(var.allowed_regions) > 0 ? 1 : 0

  name        = "${var.environment}-restrict-regions"
  description = "Restrict operations to approved AWS regions for data residency compliance"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictRegions"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "organizations:*",
          "route53:*",
          "cloudfront:*",
          "support:*",
          "budgets:*",
          "ce:*",
          "health:*",
          "trustedadvisor:*"
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
    Name       = "${var.environment}-restrict-regions"
    Compliance = "HIPAA-DataResidency"
  }
}

# SCP: Prevent Public S3 Buckets
resource "aws_organizations_policy" "prevent_public_s3_buckets" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-prevent-public-s3-buckets"
  description = "Prevent creation of public S3 buckets to protect PHI"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3Buckets"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyPublicS3Objects"
        Effect = "Deny"
        Action = [
          "s3:PutObjectAcl",
          "s3:PutBucketAcl"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-prevent-public-s3-buckets"
    Compliance = "HIPAA"
  }
}

# SCP: Require MFA for Sensitive Operations
resource "aws_organizations_policy" "require_mfa" {
  count = var.organization_id != "" && var.require_mfa ? 1 : 0

  name        = "${var.environment}-require-mfa"
  description = "Require MFA for sensitive operations"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireMFAForSensitiveOperations"
        Effect = "Deny"
        Action = [
          "iam:DeleteUser",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "kms:ScheduleKeyDeletion",
          "kms:DeleteAlias",
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "dynamodb:DeleteTable",
          "ec2:TerminateInstances"
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
    Name       = "${var.environment}-require-mfa"
    Compliance = "HIPAA"
  }
}

# SCP: Require CloudTrail Logging
resource "aws_organizations_policy" "require_cloudtrail" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-require-cloudtrail"
  description = "Prevent disabling CloudTrail for audit compliance"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-require-cloudtrail"
    Compliance = "HIPAA-AuditControls"
  }
}

# SCP: Require VPC Endpoints for AWS Services
resource "aws_organizations_policy" "require_vpc_endpoints" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-require-vpc-endpoints"
  description = "Require VPC endpoints for AWS services to prevent internet exposure"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireVPCEndpointsForS3"
        Effect = "Deny"
        Action = [
          "s3:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:SourceVpc" = ["*"]
          }
          Null = {
            "aws:SourceVpce" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-require-vpc-endpoints"
    Compliance = "HIPAA-NetworkSecurity"
  }
}

# SCP: Prevent Removal of Security Controls
resource "aws_organizations_policy" "protect_security_controls" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-protect-security-controls"
  description = "Prevent disabling of security services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectSecurityServices"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:StopMonitoringMembers",
          "securityhub:DisableSecurityHub",
          "securityhub:DisassociateFromMasterAccount",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "macie2:DisableMacie"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-protect-security-controls"
    Compliance = "HIPAA"
  }
}

# SCP: Enforce Tag Requirements
resource "aws_organizations_policy" "enforce_tags" {
  count = var.organization_id != "" ? 1 : 0

  name        = "${var.environment}-enforce-tags"
  description = "Enforce required tags for compliance and cost allocation"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireTagsForResources"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "s3:CreateBucket",
          "dynamodb:CreateTable",
          "rds:CreateDBInstance",
          "lambda:CreateFunction"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:RequestTag/Environment" = "true",
            "aws:RequestTag/CostCenter"  = "true",
            "aws:RequestTag/Owner"       = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name       = "${var.environment}-enforce-tags"
    Compliance = "HIPAA"
  }
}

# SCP Attachment (if organization is configured)
resource "aws_organizations_policy_attachment" "encryption_in_transit" {
  count     = var.organization_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.require_encryption_in_transit[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "encryption_at_rest" {
  count     = var.organization_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.require_encryption_at_rest[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "restrict_regions" {
  count     = var.organization_id != "" && length(var.allowed_regions) > 0 ? 1 : 0
  policy_id = aws_organizations_policy.restrict_regions[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "prevent_public_s3" {
  count     = var.organization_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.prevent_public_s3_buckets[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "require_mfa" {
  count     = var.organization_id != "" && var.require_mfa ? 1 : 0
  policy_id = aws_organizations_policy.require_mfa[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "require_cloudtrail" {
  count     = var.organization_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.require_cloudtrail[0].id
  target_id = var.organization_id
}

resource "aws_organizations_policy_attachment" "protect_security_controls" {
  count     = var.organization_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.protect_security_controls[0].id
  target_id = var.organization_id
}
