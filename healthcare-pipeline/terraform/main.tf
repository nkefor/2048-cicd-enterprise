# Secure Healthcare Data Pipeline - Main Terraform Configuration
# Implements AWS Well-Architected Framework for HIPAA-compliant data processing

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.28"
    }
  }

  backend "s3" {
    bucket         = "healthcare-pipeline-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "terraform-state-lock"
  }
}

# Primary Region Provider
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project             = "Healthcare-PII-Pipeline"
      Environment         = var.environment
      ManagedBy           = "Terraform"
      CostCenter          = "Healthcare-IT"
      Compliance          = "HIPAA"
      DataClassification  = "PHI"
      Owner               = var.owner_email
      BackupPolicy        = "Daily"
      DisasterRecovery    = "Multi-Region"
    }
  }
}

# DR Region Provider
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project             = "Healthcare-PII-Pipeline"
      Environment         = var.environment
      ManagedBy           = "Terraform"
      CostCenter          = "Healthcare-IT"
      Compliance          = "HIPAA"
      DataClassification  = "PHI"
      Owner               = var.owner_email
      BackupPolicy        = "Daily"
      DisasterRecovery    = "Multi-Region"
    }
  }
}

# Databricks Provider
provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

# KMS Key for Encryption
resource "aws_kms_key" "main" {
  description             = "KMS key for healthcare data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.main.key_id
}

# VPC Module - Primary Region
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_flow_logs    = true
  flow_logs_retention = 90
}

# VPC Module - DR Region
module "vpc_dr" {
  source = "./modules/vpc"
  providers = {
    aws = aws.dr
  }

  project_name        = "${var.project_name}-dr"
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr_dr
  availability_zones  = var.availability_zones_dr
  enable_flow_logs    = true
  flow_logs_retention = 90
}

# S3 Module for Data Storage
module "s3" {
  source = "./modules/s3"

  project_name           = var.project_name
  environment            = var.environment
  kms_key_id             = aws_kms_key.main.arn
  enable_versioning      = true
  enable_replication     = true
  replication_region     = var.dr_region
  lifecycle_rules        = var.s3_lifecycle_rules
  enable_access_logging  = true
}

# Lambda Module for Data Processing
module "lambda" {
  source = "./modules/lambda"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  kms_key_arn            = aws_kms_key.main.arn
  raw_data_bucket        = module.s3.raw_data_bucket_name
  processed_data_bucket  = module.s3.processed_data_bucket_name
  quarantine_bucket      = module.s3.quarantine_bucket_name
  secrets_manager_arn    = module.security.secrets_manager_arn
}

# Amazon Comprehend Medical Module
module "comprehend" {
  source = "./modules/comprehend"

  project_name    = var.project_name
  environment     = var.environment
  lambda_role_arn = module.lambda.lambda_role_arn
}

# FHIR API Gateway Module
module "fhir_api" {
  source = "./modules/fhir-api"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_cluster_name   = "${var.project_name}-fhir-cluster"
  image_uri          = var.fhir_api_image_uri
}

# Patient Consent API Module
module "consent_api" {
  source = "./modules/consent-api"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  database_name      = "${var.project_name}_consent"
  kms_key_arn        = aws_kms_key.main.arn
}

# SageMaker Module for ML-based Fraud Detection
module "sagemaker" {
  source = "./modules/sagemaker"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kms_key_arn        = aws_kms_key.main.arn
  ml_bucket          = module.s3.ml_bucket_name
}

# Databricks Integration Module
module "databricks" {
  source = "./modules/databricks"

  project_name              = var.project_name
  environment               = var.environment
  databricks_account_id     = var.databricks_account_id
  processed_data_bucket     = module.s3.processed_data_bucket_name
  databricks_workspace_name = "${var.project_name}-analytics"
  enable_unity_catalog      = true
}

# Monitoring Module (Grafana, Prometheus, CloudWatch)
module "monitoring" {
  source = "./modules/monitoring"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  enable_grafana        = true
  enable_prometheus     = true
  enable_datadog        = var.enable_datadog
  datadog_api_key       = var.datadog_api_key
  splunk_hec_endpoint   = var.splunk_hec_endpoint
  splunk_hec_token      = var.splunk_hec_token
}

# Security Module (GuardDuty, Security Hub, WAF)
module "security" {
  source = "./modules/security"

  project_name            = var.project_name
  environment             = var.environment
  enable_guardduty        = true
  enable_security_hub     = true
  enable_waf              = true
  enable_config           = true
  enable_cloudtrail       = true
  cloudtrail_bucket       = module.s3.audit_bucket_name
  kms_key_arn             = aws_kms_key.main.arn
}

# SNS Topics for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = aws_kms_key.main.id

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "pii_detection_errors" {
  alarm_name          = "${var.project_name}-pii-detection-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when PII detection Lambda errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = module.lambda.pii_detection_function_name
  }
}

# EventBridge Rule for S3 Data Ingestion
resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "${var.project_name}-s3-upload"
  description = "Trigger on S3 object creation in raw data bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.s3.raw_data_bucket_name]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.s3_upload.name
  target_id = "InvokeDataIngestionLambda"
  arn       = module.lambda.data_ingestion_function_arn
}

# Step Functions for Orchestration
resource "aws_sfn_state_machine" "data_processing" {
  name     = "${var.project_name}-data-processing"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Healthcare Data Processing Pipeline"
    StartAt = "ValidateInput"
    States = {
      ValidateInput = {
        Type     = "Task"
        Resource = module.lambda.validation_function_arn
        Next     = "CheckConsent"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "QuarantineData"
        }]
      }
      CheckConsent = {
        Type     = "Task"
        Resource = module.consent_api.check_consent_function_arn
        Next     = "DetectPII"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "QuarantineData"
        }]
      }
      DetectPII = {
        Type     = "Task"
        Resource = module.lambda.pii_detection_function_arn
        Next     = "CheckComplianceRules"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "QuarantineData"
        }]
      }
      CheckComplianceRules = {
        Type     = "Task"
        Resource = module.lambda.compliance_check_function_arn
        Next     = "FraudDetection"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "QuarantineData"
        }]
      }
      FraudDetection = {
        Type     = "Task"
        Resource = module.sagemaker.fraud_detection_endpoint_arn
        Next     = "ProcessAndStore"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "QuarantineData"
        }]
      }
      ProcessAndStore = {
        Type     = "Task"
        Resource = module.lambda.data_storage_function_arn
        Next     = "SendToDatabricks"
      }
      SendToDatabricks = {
        Type     = "Task"
        Resource = module.lambda.databricks_sync_function_arn
        Next     = "Success"
      }
      QuarantineData = {
        Type     = "Task"
        Resource = module.lambda.quarantine_function_arn
        Next     = "SendAlert"
      }
      SendAlert = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.alerts.arn
          Message  = "Data quarantined due to compliance violation"
        }
        Next = "Fail"
      }
      Success = {
        Type = "Succeed"
      }
      Fail = {
        Type = "Fail"
      }
    }
  })
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project_name}-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          module.lambda.validation_function_arn,
          module.consent_api.check_consent_function_arn,
          module.lambda.pii_detection_function_arn,
          module.lambda.compliance_check_function_arn,
          module.lambda.data_storage_function_arn,
          module.lambda.databricks_sync_function_arn,
          module.lambda.quarantine_function_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [aws_sns_topic.alerts.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = [module.sagemaker.fraud_detection_endpoint_arn]
      }
    ]
  })
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "raw_data_bucket" {
  description = "S3 bucket for raw healthcare data"
  value       = module.s3.raw_data_bucket_name
}

output "processed_data_bucket" {
  description = "S3 bucket for processed data"
  value       = module.s3.processed_data_bucket_name
}

output "fhir_api_endpoint" {
  description = "FHIR API Gateway endpoint"
  value       = module.fhir_api.api_endpoint
}

output "consent_api_endpoint" {
  description = "Patient Consent API endpoint"
  value       = module.consent_api.api_endpoint
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = module.databricks.workspace_url
}

output "grafana_dashboard_url" {
  description = "Grafana dashboard URL"
  value       = module.monitoring.grafana_url
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.data_processing.arn
}
