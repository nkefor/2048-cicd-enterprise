# S3 Module for Secure Healthcare Data Storage
# Implements HIPAA-compliant storage with encryption, versioning, and cross-region replication

# Random suffix for globally unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Raw Data Bucket (for ingested healthcare data)
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_name}-raw-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-raw-data"
    DataType    = "PHI"
    Encryption  = "Enabled"
    Compliance  = "HIPAA"
  }
}

# Processed Data Bucket (for cleaned and de-identified data)
resource "aws_s3_bucket" "processed_data" {
  bucket = "${var.project_name}-processed-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name       = "${var.project_name}-processed-data"
    DataType   = "De-identified"
    Encryption = "Enabled"
  }
}

# Quarantine Bucket (for non-compliant data)
resource "aws_s3_bucket" "quarantine" {
  bucket = "${var.project_name}-quarantine-${random_id.bucket_suffix.hex}"

  tags = {
    Name       = "${var.project_name}-quarantine"
    DataType   = "Quarantined"
    Encryption = "Enabled"
  }
}

# Audit Bucket (for CloudTrail and access logs)
resource "aws_s3_bucket" "audit" {
  bucket = "${var.project_name}-audit-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name       = "${var.project_name}-audit-logs"
    DataType   = "Audit"
    Encryption = "Enabled"
  }
}

# ML Models Bucket (for SageMaker)
resource "aws_s3_bucket" "ml_models" {
  bucket = "${var.project_name}-ml-models-${random_id.bucket_suffix.hex}"

  tags = {
    Name       = "${var.project_name}-ml-models"
    DataType   = "ML-Models"
    Encryption = "Enabled"
  }
}

# Databricks Storage Bucket
resource "aws_s3_bucket" "databricks" {
  bucket = "${var.project_name}-databricks-${random_id.bucket_suffix.hex}"

  tags = {
    Name       = "${var.project_name}-databricks"
    DataType   = "Analytics"
    Encryption = "Enabled"
  }
}

# Enable Versioning (HIPAA requirement for data integrity)
resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "processed_data" {
  bucket = aws_s3_bucket.processed_data.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_versioning" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id

  versioning_configuration {
    status = "Enabled"  # Always enabled for audit logs
  }
}

# Server-Side Encryption (KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_data" {
  bucket = aws_s3_bucket.processed_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_models" {
  bucket = aws_s3_bucket.ml_models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "databricks" {
  bucket = aws_s3_bucket.databricks.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Block Public Access (HIPAA requirement)
resource "aws_s3_bucket_public_access_block" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed_data" {
  bucket = aws_s3_bucket.processed_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "ml_models" {
  bucket = aws_s3_bucket.ml_models.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "databricks" {
  bucket = aws_s3_bucket.databricks.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rules for Cost Optimization and Compliance
resource "aws_s3_bucket_lifecycle_configuration" "raw_data" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.raw_data.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      transition {
        days          = rule.value.transition_days
        storage_class = rule.value.transition_storage_class
      }

      expiration {
        days = rule.value.expiration_days
      }

      noncurrent_version_expiration {
        noncurrent_days = 90
      }
    }
  }
}

# S3 Bucket Logging (Access Logs)
resource "aws_s3_bucket_logging" "raw_data" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.raw_data.id

  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "raw-data-access-logs/"
}

resource "aws_s3_bucket_logging" "processed_data" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.processed_data.id

  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "processed-data-access-logs/"
}

# Cross-Region Replication for DR
resource "aws_s3_bucket_replication_configuration" "raw_data" {
  count = var.enable_replication ? 1 : 0

  depends_on = [aws_s3_bucket_versioning.raw_data]
  bucket     = aws_s3_bucket.raw_data.id
  role       = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = "arn:aws:s3:::${var.project_name}-raw-data-dr-${random_id.bucket_suffix.hex}"
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = var.kms_key_id
      }
    }
  }
}

# IAM Role for Replication
resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-policy"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.raw_data.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.raw_data.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.project_name}-raw-data-dr-${random_id.bucket_suffix.hex}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Effect   = "Allow"
        Resource = [var.kms_key_id]
      }
    ]
  })
}

# S3 Event Notifications
resource "aws_s3_bucket_notification" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  eventbridge = true
}

# Bucket Policies for Least Privilege Access
resource "aws_s3_bucket_policy" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.raw_data.arn,
          "${aws_s3_bucket.raw_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.audit.arn,
          "${aws_s3_bucket.audit.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Outputs
output "raw_data_bucket_name" {
  description = "Name of the raw data bucket"
  value       = aws_s3_bucket.raw_data.bucket
}

output "raw_data_bucket_arn" {
  description = "ARN of the raw data bucket"
  value       = aws_s3_bucket.raw_data.arn
}

output "processed_data_bucket_name" {
  description = "Name of the processed data bucket"
  value       = aws_s3_bucket.processed_data.bucket
}

output "processed_data_bucket_arn" {
  description = "ARN of the processed data bucket"
  value       = aws_s3_bucket.processed_data.arn
}

output "quarantine_bucket_name" {
  description = "Name of the quarantine bucket"
  value       = aws_s3_bucket.quarantine.bucket
}

output "quarantine_bucket_arn" {
  description = "ARN of the quarantine bucket"
  value       = aws_s3_bucket.quarantine.arn
}

output "audit_bucket_name" {
  description = "Name of the audit logs bucket"
  value       = aws_s3_bucket.audit.bucket
}

output "audit_bucket_arn" {
  description = "ARN of the audit logs bucket"
  value       = aws_s3_bucket.audit.arn
}

output "ml_bucket_name" {
  description = "Name of the ML models bucket"
  value       = aws_s3_bucket.ml_models.bucket
}

output "ml_bucket_arn" {
  description = "ARN of the ML models bucket"
  value       = aws_s3_bucket.ml_models.arn
}

output "databricks_bucket_name" {
  description = "Name of the Databricks bucket"
  value       = aws_s3_bucket.databricks.bucket
}

output "databricks_bucket_arn" {
  description = "ARN of the Databricks bucket"
  value       = aws_s3_bucket.databricks.arn
}
