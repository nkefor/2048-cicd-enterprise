# Security Module - HIPAA/HITRUST/NIST 800-53 Compliance

# KMS Key for PHI Encryption
resource "aws_kms_key" "phi_encryption" {
  description             = "${var.environment} PHI Encryption Key - HIPAA Compliant"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true

  tags = {
    Name        = "${var.environment}-phi-encryption-key"
    Compliance  = "HIPAA"
    DataType    = "PHI"
    Purpose     = "EncryptionAtRest"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:*:${var.account_id}:*"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "phi_encryption" {
  name          = "alias/${var.environment}-phi-encryption"
  target_key_id = aws_kms_key.phi_encryption.key_id
}

# Amazon Cognito User Pool for Healthcare Authentication
resource "aws_cognito_user_pool" "healthcare" {
  name = var.cognito_user_pool_name

  # Password Policy - NIST 800-63B Compliant
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }

  # MFA Configuration - HIPAA Required
  mfa_configuration = var.mfa_configuration

  # User Attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = false
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    name                = "department"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 100
    }
  }

  schema {
    name                = "license_number"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # Device Tracking
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User Pool Add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Lambda Triggers for Custom Validation
  lambda_config {
    pre_authentication       = aws_lambda_function.pre_auth_trigger.arn
    post_authentication      = aws_lambda_function.post_auth_trigger.arn
    pre_token_generation     = aws_lambda_function.pre_token_trigger.arn
  }

  tags = {
    Name       = "${var.environment}-healthcare-user-pool"
    Compliance = "HIPAA"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "healthcare" {
  name         = "${var.environment}-healthcare-client"
  user_pool_id = aws_cognito_user_pool.healthcare.id

  generate_secret     = true
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Session Timeout - HIPAA Requires 15 minutes
  refresh_token_validity = 1
  access_token_validity  = 15
  id_token_validity      = 15
  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  prevent_user_existence_errors = "ENABLED"

  read_attributes = [
    "email",
    "email_verified",
    "custom:role",
    "custom:department",
    "custom:license_number"
  ]

  write_attributes = [
    "email"
  ]
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "healthcare" {
  identity_pool_name               = "${var.environment}_healthcare_identity_pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.healthcare.id
    provider_name           = aws_cognito_user_pool.healthcare.endpoint
    server_side_token_check = true
  }
}

# WAF Web ACL for API Gateway
resource "aws_wafv2_web_acl" "api_protection" {
  name  = "${var.environment}-healthcare-api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Rate Limiting
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Core Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: SQL Injection Protection
  rule {
    name     = "SQLInjectionProtection"
    priority = 3

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionProtection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Geographic Restriction
  rule {
    name     = "GeoBlockingRule"
    priority = 4

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = var.allowed_countries
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockingRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: Known Bad Inputs
  rule {
    name     = "KnownBadInputsRule"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-healthcare-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name       = "${var.environment}-healthcare-api-waf"
    Compliance = "HIPAA"
  }
}

# Lambda Security Group
resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-lambda-sg-"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services"
  }

  tags = {
    Name = "${var.environment}-lambda-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Functions for Cognito Triggers
resource "aws_lambda_function" "pre_auth_trigger" {
  filename      = "${path.module}/lambda/pre_auth.zip"
  function_name = "${var.environment}-cognito-pre-auth"
  role          = aws_iam_role.cognito_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  kms_key_arn = aws_kms_key.phi_encryption.arn

  tags = {
    Name = "${var.environment}-cognito-pre-auth"
  }
}

resource "aws_lambda_function" "post_auth_trigger" {
  filename      = "${path.module}/lambda/post_auth.zip"
  function_name = "${var.environment}-cognito-post-auth"
  role          = aws_iam_role.cognito_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  kms_key_arn = aws_kms_key.phi_encryption.arn

  tags = {
    Name = "${var.environment}-cognito-post-auth"
  }
}

resource "aws_lambda_function" "pre_token_trigger" {
  filename      = "${var.environment}-cognito-pre-token"
  function_name = "${var.environment}-cognito-pre-token"
  role          = aws_iam_role.cognito_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  kms_key_arn = aws_kms_key.phi_encryption.arn

  tags = {
    Name = "${var.environment}-cognito-pre-token"
  }
}

# IAM Role for Cognito Lambda Triggers
resource "aws_iam_role" "cognito_lambda" {
  name = "${var.environment}-cognito-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-cognito-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "cognito_lambda_basic" {
  role       = aws_iam_role.cognito_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Permission for Cognito
resource "aws_lambda_permission" "cognito_pre_auth" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_auth_trigger.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.healthcare.arn
}

resource "aws_lambda_permission" "cognito_post_auth" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_auth_trigger.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.healthcare.arn
}

resource "aws_lambda_permission" "cognito_pre_token" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_trigger.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.healthcare.arn
}
