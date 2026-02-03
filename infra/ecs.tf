# ============================================================
# ECS Fargate Cluster, Task Definition, and Blue/Green Services
# ============================================================

# ------------------------------
# ECS Cluster
# ------------------------------
resource "aws_ecs_cluster" "main" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

# ------------------------------
# Task Definition
# Shared by both blue and green services.
# The CI/CD pipeline updates the image tag via force-new-deployment,
# which causes ECS to pull the latest image matching the tag.
# ------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${var.container_port}/health || exit 1"]
        interval    = 15
        timeout     = 3
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "DEPLOY_ENV"
          value = "default"
        }
      ]
    }
  ])

  # The CI/CD pipeline manages the image tag, not Terraform.
  # Without this, Terraform would revert the image on every apply.
  lifecycle {
    ignore_changes = [container_definitions]
  }

  tags = {
    Name = "${local.name_prefix}-task-def"
  }
}

# ------------------------------
# ECS Service: Blue
# ------------------------------
resource "aws_ecs_service" "blue" {
  name            = "${var.project_name}-blue"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.project_name
    container_port   = var.container_port
  }

  deployment_configuration {
    minimum_healthy_percent = 50
    maximum_percent         = 200
  }

  # Allow ECS to manage desired count via auto-scaling
  # and task definition via CI/CD pipeline
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${local.name_prefix}-service-blue"
    Environment = "blue"
  }
}

# ------------------------------
# ECS Service: Green
# ------------------------------
resource "aws_ecs_service" "green" {
  name            = "${var.project_name}-green"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = var.project_name
    container_port   = var.container_port
  }

  deployment_configuration {
    minimum_healthy_percent = 50
    maximum_percent         = 200
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${local.name_prefix}-service-green"
    Environment = "green"
  }
}

# ------------------------------
# Auto Scaling: Blue Service
# ------------------------------
resource "aws_appautoscaling_target" "blue" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.blue.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "blue_cpu" {
  name               = "${local.name_prefix}-blue-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.blue.resource_id
  scalable_dimension = aws_appautoscaling_target.blue.scalable_dimension
  service_namespace  = aws_appautoscaling_target.blue.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ------------------------------
# Auto Scaling: Green Service
# ------------------------------
resource "aws_appautoscaling_target" "green" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.green.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "green_cpu" {
  name               = "${local.name_prefix}-green-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.green.resource_id
  scalable_dimension = aws_appautoscaling_target.green.scalable_dimension
  service_namespace  = aws_appautoscaling_target.green.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
