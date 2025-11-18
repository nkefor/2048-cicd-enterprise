# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution" {
  name = "${local.prefix}-lambda-execution"

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

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-lambda-execution"
      Purpose = "Lambda-Execution-Role"
    }
  )
}

# IAM Policy for Lambda Basic Execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Compliance Evidence Collection
resource "aws_iam_policy" "compliance_evidence_collection" {
  name        = "${local.prefix}-evidence-collection"
  description = "Policy for SOC 2 compliance evidence collection"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read-only access to AWS services for evidence collection
      {
        Sid    = "ReadOnlyAWSServices"
        Effect = "Allow"
        Action = [
          # IAM
          "iam:ListUsers",
          "iam:ListRoles",
          "iam:ListPolicies",
          "iam:GetAccountPasswordPolicy",
          "iam:GetCredentialReport",
          "iam:ListMFADevices",
          "iam:ListAccessKeys",
          "iam:GetAccountSummary",

          # CloudTrail
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:LookupEvents",
          "cloudtrail:GetEventSelectors",

          # Config
          "config:DescribeConfigurationRecorders",
          "config:DescribeConfigurationRecorderStatus",
          "config:DescribeDeliveryChannels",
          "config:DescribeComplianceByConfigRule",
          "config:GetComplianceDetailsByConfigRule",

          # GuardDuty
          "guardduty:ListDetectors",
          "guardduty:GetDetector",
          "guardduty:ListFindings",
          "guardduty:GetFindings",

          # Security Hub
          "securityhub:GetFindings",
          "securityhub:DescribeHub",
          "securityhub:GetEnabledStandards",

          # EC2
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeFlowLogs",

          # S3
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetBucketLogging",
          "s3:GetBucketEncryption",
          "s3:GetBucketPublicAccessBlock",

          # RDS
          "rds:DescribeDBInstances",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterSnapshots",

          # KMS
          "kms:ListKeys",
          "kms:ListAliases",
          "kms:DescribeKey",
          "kms:GetKeyRotationStatus",

          # CloudWatch
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricStatistics",
          "logs:DescribeLogGroups",
          "logs:DescribeMetricFilters",

          # Lambda
          "lambda:ListFunctions",
          "lambda:GetFunction",
          "lambda:GetPolicy",

          # ECS
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",

          # ELB
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",

          # VPC
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways"
        ]
        Resource = "*"
      },
      # S3 Evidence Bucket Access
      {
        Sid    = "S3EvidenceBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.evidence.arn,
          "${aws_s3_bucket.evidence.arn}/*"
        ]
      },
      # DynamoDB Access
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.compliance_evidence.arn,
          aws_dynamodb_table.audit_findings.arn,
          aws_dynamodb_table.control_status.arn,
          aws_dynamodb_table.policy_violations.arn,
          "${aws_dynamodb_table.compliance_evidence.arn}/index/*",
          "${aws_dynamodb_table.audit_findings.arn}/index/*",
          "${aws_dynamodb_table.control_status.arn}/index/*",
          "${aws_dynamodb_table.policy_violations.arn}/index/*"
        ]
      },
      # KMS Access
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.compliance.arn
      },
      # SNS Publish
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.compliance_alerts.arn
      },
      # CloudWatch Metrics
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "SOC2/Compliance"
          }
        }
      },
      # Multi-Account Assume Role (if configured)
      {
        Sid    = "AssumeComplianceRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          for account_id in var.target_accounts :
          "arn:aws:iam::${account_id}:role/${var.assume_role_name}"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_compliance" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.compliance_evidence_collection.arn
}

# IAM Policy for X-Ray Tracing (optional)
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# IAM Role for EventBridge to invoke Lambda
resource "aws_iam_role" "eventbridge_lambda" {
  name = "${local.prefix}-eventbridge-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-eventbridge-lambda"
    }
  )
}

resource "aws_iam_role_policy" "eventbridge_lambda" {
  name = "eventbridge-invoke-lambda"
  role = aws_iam_role.eventbridge_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.evidence_collector.arn,
          aws_lambda_function.policy_validator.arn,
          aws_lambda_function.audit_scanner.arn,
          aws_lambda_function.report_generator.arn
        ]
      }
    ]
  })
}
