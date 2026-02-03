# ============================================================
# CloudWatch: Log Groups, Alarms, Dashboard, and SNS
# ============================================================

# ------------------------------
# Log Group for ECS Tasks
# ------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-ecs-logs"
  }
}

# ------------------------------
# SNS Topic for Alarm Notifications
# ------------------------------
resource "aws_sns_topic" "deploy_notifications" {
  name = "${local.name_prefix}-deploy-notifications"

  tags = {
    Name = "${local.name_prefix}-sns-deploy"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.deploy_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ------------------------------
# Alarm: Blue Service High CPU
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "blue_cpu_high" {
  alarm_name          = "${local.name_prefix}-blue-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Blue service CPU utilization > ${var.cpu_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]
  ok_actions          = [aws_sns_topic.deploy_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.blue.name
  }

  tags = {
    Name = "${local.name_prefix}-alarm-blue-cpu"
  }
}

# ------------------------------
# Alarm: Green Service High CPU
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "green_cpu_high" {
  alarm_name          = "${local.name_prefix}-green-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Green service CPU utilization > ${var.cpu_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]
  ok_actions          = [aws_sns_topic.deploy_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.green.name
  }

  tags = {
    Name = "${local.name_prefix}-alarm-green-cpu"
  }
}

# ------------------------------
# Alarm: Blue Service High Memory
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "blue_memory_high" {
  alarm_name          = "${local.name_prefix}-blue-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "Blue service memory utilization > ${var.memory_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.blue.name
  }

  tags = {
    Name = "${local.name_prefix}-alarm-blue-memory"
  }
}

# ------------------------------
# Alarm: Green Service High Memory
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "green_memory_high" {
  alarm_name          = "${local.name_prefix}-green-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "Green service memory utilization > ${var.memory_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.green.name
  }

  tags = {
    Name = "${local.name_prefix}-alarm-green-memory"
  }
}

# ------------------------------
# Alarm: ALB 5xx Errors
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB returning more than 10 5xx errors in 5 minutes"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${local.name_prefix}-alarm-alb-5xx"
  }
}

# ------------------------------
# Alarm: ALB Target Response Time
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${local.name_prefix}-alb-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "p95"
  threshold           = 2.0
  alarm_description   = "ALB p95 response time > 2 seconds"
  alarm_actions       = [aws_sns_topic.deploy_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${local.name_prefix}-alarm-latency"
  }
}

# ------------------------------
# CloudWatch Dashboard
# ------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU Utilization"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.blue.name, { label = "Blue Service" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.green.name, { label = "Green Service" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS Memory Utilization"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.blue.name, { label = "Blue Service" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.green.name, { label = "Green Service" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "Total Requests" }]
          ]
          period = 60
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Response Time (p95)"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "p95", label = "p95 Latency" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", label = "Avg Latency" }]
          ]
          period = 60
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "ALB HTTP Error Codes"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "4xx Errors" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "5xx Errors" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Recent ECS Logs"
          query  = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region = var.aws_region
        }
      }
    ]
  })
}
