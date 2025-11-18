# CloudWatch Dashboard for Compliance Monitoring
resource "aws_cloudwatch_dashboard" "compliance" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Compliance Score Widget
      {
        type = "metric"
        properties = {
          metrics = [
            ["SOC2/Compliance", "ComplianceScore", { stat = "Average", period = 3600 }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Overall Compliance Score (%)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # Active Findings by Severity
      {
        type = "metric"
        properties = {
          metrics = [
            ["SOC2/Compliance", "CriticalFindings", { stat = "Sum" }],
            [".", "HighFindings", { stat = "Sum" }],
            [".", "MediumFindings", { stat = "Sum" }],
            [".", "LowFindings", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Active Findings by Severity"
        }
      },
      # Evidence Collection Success Rate
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Total Scans" }],
            [".", "Errors", { stat = "Sum", label = "Failed Scans" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.aws_region
          title  = "Evidence Collection Metrics"
        }
      },
      # Trust Principles Compliance
      {
        type = "metric"
        properties = {
          metrics = [
            ["SOC2/Compliance", "SecurityScore", { stat = "Average" }],
            [".", "AvailabilityScore", { stat = "Average" }],
            [".", "ProcessingIntegrityScore", { stat = "Average" }],
            [".", "ConfidentialityScore", { stat = "Average" }],
            [".", "PrivacyScore", { stat = "Average" }]
          ]
          period = 3600
          stat   = "Average"
          region = var.aws_region
          title  = "Trust Service Criteria Scores"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # Policy Violations Over Time
      {
        type = "metric"
        properties = {
          metrics = [
            ["SOC2/Compliance", "PolicyViolations", { stat = "Sum", period = 3600 }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.aws_region
          title  = "Policy Violations (24h)"
        }
      },
      # Lambda Function Performance
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Evidence Collector" }],
            ["...", { stat = "Average", label = "Policy Validator" }],
            ["...", { stat = "Average", label = "Audit Scanner" }],
            ["...", { stat = "Average", label = "Report Generator" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Function Duration (ms)"
        }
      },
      # Evidence Bucket Size
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", { stat = "Average", period = 86400 }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "Evidence Storage Size (GB)"
        }
      },
      # DynamoDB Consumed Capacity
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "DynamoDB Capacity Consumption"
        }
      },
      # Recent Lambda Errors
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/lambda/${local.prefix}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Lambda Errors"
        }
      }
    ]
  })
}

# Custom CloudWatch Metrics (published by Lambda functions)
# These are referenced in the dashboard and alarms

# Compliance Score Alarm
resource "aws_cloudwatch_metric_alarm" "compliance_score_low" {
  alarm_name          = "${local.prefix}-compliance-score-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ComplianceScore"
  namespace           = "SOC2/Compliance"
  period              = 3600
  statistic           = "Average"
  threshold           = var.compliance_score_threshold
  alarm_description   = "Alert when overall compliance score drops below ${var.compliance_score_threshold}%"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# Control Coverage Alarm
resource "aws_cloudwatch_metric_alarm" "control_coverage_low" {
  alarm_name          = "${local.prefix}-control-coverage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ControlCoverage"
  namespace           = "SOC2/Compliance"
  period              = 3600
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Alert when control coverage drops below 90%"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# Evidence Collection Failures
resource "aws_cloudwatch_metric_alarm" "evidence_collection_failures" {
  alarm_name          = "${local.prefix}-evidence-collection-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EvidenceCollectionFailures"
  namespace           = "SOC2/Compliance"
  period              = 3600
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when evidence collection has >10 failures per hour"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  tags = local.common_tags
}
