# DynamoDB table for tasks
resource "aws_dynamodb_table" "tasks" {
  name         = "${var.project_name}-tasks-${var.environment}"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "taskId"
  range_key    = "createdAt"

  attribute {
    name = "taskId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  # Global Secondary Index for querying by status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying by userId
  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption with KMS
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.task_encryption.arn
  }

  # Enable DynamoDB Streams for event-driven processing
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # TTL for automatic cleanup of old tasks
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-tasks"
  }
}

# DynamoDB auto-scaling for read capacity (if using provisioned mode)
resource "aws_appautoscaling_target" "dynamodb_read_target" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.tasks.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_read_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  name               = "${var.project_name}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_read_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_read_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_read_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

# DynamoDB auto-scaling for write capacity (if using provisioned mode)
resource "aws_appautoscaling_target" "dynamodb_write_target" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.tasks.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_write_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  name               = "${var.project_name}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_write_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_write_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_write_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}
