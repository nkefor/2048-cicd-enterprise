# DynamoDB Tables for Healthcare Data
# HIPAA-compliant, encrypted storage for patient data, lab results, and billing

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Patients Table
resource "aws_dynamodb_table" "patients" {
  name           = "${var.environment}-patients"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "phoneNumber"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "PhoneNumberIndex"
    hash_key        = "phoneNumber"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name         = "${var.environment}-patients"
    Environment  = var.environment
    Compliance   = "HIPAA"
    DataCategory = "PHI"
  }
}

# Lab Results Table
resource "aws_dynamodb_table" "lab_results" {
  name           = "${var.environment}-lab-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  range_key      = "testId"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "testId"
    type = "S"
  }

  attribute {
    name = "orderDate"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "OrderDateIndex"
    hash_key        = "patientId"
    range_key       = "orderDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "orderDate"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name         = "${var.environment}-lab-results"
    Environment  = var.environment
    Compliance   = "HIPAA"
    DataCategory = "PHI"
  }
}

# Billing Table
resource "aws_dynamodb_table" "billing" {
  name           = "${var.environment}-billing"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  range_key      = "billingId"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "billingId"
    type = "S"
  }

  attribute {
    name = "billingDate"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "BillingDateIndex"
    hash_key        = "patientId"
    range_key       = "billingDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "billingDate"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name         = "${var.environment}-billing"
    Environment  = var.environment
    Compliance   = "HIPAA"
    DataCategory = "PHI"
  }
}

# Medical Entities Table (Comprehend Medical results)
resource "aws_dynamodb_table" "medical_entities" {
  name           = "${var.environment}-medical-entities"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  range_key      = "timestamp"

  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name         = "${var.environment}-medical-entities"
    Environment  = var.environment
    Compliance   = "HIPAA"
    DataCategory = "PHI"
  }
}

# Audit Log Table
resource "aws_dynamodb_table" "audit_log" {
  name           = "${var.environment}-audit-log"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "auditId"
  range_key      = "timestamp"

  attribute {
    name = "auditId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "action"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "ActionIndex"
    hash_key        = "action"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name         = "${var.environment}-audit-log"
    Environment  = var.environment
    Compliance   = "HIPAA"
    DataCategory = "AuditLog"
  }
}

# DynamoDB Backup Plan
resource "aws_backup_plan" "dynamodb_backup" {
  name = "${var.environment}-dynamodb-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.dynamodb_vault.name
    schedule          = "cron(0 5 * * ? *)" # Daily at 5 AM UTC

    lifecycle {
      delete_after = 90 # Retain for 90 days
    }

    recovery_point_tags = {
      Environment = var.environment
      Compliance  = "HIPAA"
    }
  }

  tags = {
    Name        = "${var.environment}-dynamodb-backup-plan"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Backup Vault
resource "aws_backup_vault" "dynamodb_vault" {
  name        = "${var.environment}-dynamodb-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = {
    Name        = "${var.environment}-dynamodb-backup-vault"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Backup Selection
resource "aws_backup_selection" "dynamodb_selection" {
  name         = "${var.environment}-dynamodb-backup-selection"
  plan_id      = aws_backup_plan.dynamodb_backup.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = [
    aws_dynamodb_table.patients.arn,
    aws_dynamodb_table.lab_results.arn,
    aws_dynamodb_table.billing.arn,
    aws_dynamodb_table.medical_entities.arn,
    aws_dynamodb_table.audit_log.arn
  ]
}

# Backup IAM Role
resource "aws_iam_role" "backup_role" {
  name = "${var.environment}-dynamodb-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-dynamodb-backup-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# CloudWatch Alarms for DynamoDB
resource "aws_cloudwatch_metric_alarm" "patients_table_errors" {
  alarm_name          = "${var.environment}-patients-table-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when patients table has errors"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    TableName = aws_dynamodb_table.patients.name
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
}

# Outputs
output "patients_table_name" {
  value = aws_dynamodb_table.patients.name
}

output "patients_table_arn" {
  value = aws_dynamodb_table.patients.arn
}

output "lab_results_table_name" {
  value = aws_dynamodb_table.lab_results.name
}

output "billing_table_name" {
  value = aws_dynamodb_table.billing.name
}

output "medical_entities_table_name" {
  value = aws_dynamodb_table.medical_entities.name
}
