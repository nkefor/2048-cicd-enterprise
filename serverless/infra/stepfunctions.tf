# Step Functions state machine for task approval workflow
resource "aws_sfn_state_machine" "task_approval" {
  name     = "${var.project_name}-task-approval-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Task approval workflow with human approval step"
    StartAt = "ValidateTask"
    States = {
      ValidateTask = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.get_task.arn
          Payload = {
            "taskId.$" = "$.detail.taskId"
          }
        }
        ResultPath = "$.taskValidation"
        Next       = "CheckPriority"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "TaskValidationFailed"
            ResultPath  = "$.error"
          }
        ]
      }

      CheckPriority = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.detail.priority"
            StringEquals  = "high"
            Next          = "WaitForApproval"
          },
          {
            Variable      = "$.detail.priority"
            StringEquals  = "medium"
            Next          = "AutoApproveTask"
          }
        ]
        Default = "AutoApproveTask"
      }

      WaitForApproval = {
        Type    = "Task"
        Resource = "arn:aws:states:::aws-sdk:dynamodb:updateItem"
        Parameters = {
          TableName = aws_dynamodb_table.tasks.name
          Key = {
            taskId = {
              "S.$" = "$.detail.taskId"
            }
            createdAt = {
              "S.$" = "$.detail.createdAt"
            }
          }
          UpdateExpression = "SET #status = :pending"
          ExpressionAttributeNames = {
            "#status" = "status"
          }
          ExpressionAttributeValues = {
            ":pending" = {
              S = "pending_approval"
            }
          }
        }
        ResultPath = "$.updateResult"
        Next       = "WaitForManualApproval"
      }

      WaitForManualApproval = {
        Type    = "Wait"
        Seconds = 300
        Next    = "CheckApprovalStatus"
      }

      CheckApprovalStatus = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.get_task.arn
          Payload = {
            "taskId.$" = "$.detail.taskId"
          }
        }
        ResultPath = "$.approvalCheck"
        Next       = "IsApproved"
      }

      IsApproved = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.approvalCheck.Payload.status"
            StringEquals  = "approved"
            Next          = "ProcessApprovedTask"
          },
          {
            Variable      = "$.approvalCheck.Payload.status"
            StringEquals  = "rejected"
            Next          = "TaskRejected"
          }
        ]
        Default = "WaitForManualApproval"
      }

      AutoApproveTask = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.update_task.arn
          Payload = {
            "taskId.$" = "$.detail.taskId"
            status     = "approved"
          }
        }
        ResultPath = "$.approvalResult"
        Next       = "ProcessApprovedTask"
      }

      ProcessApprovedTask = {
        Type = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              Source      = "task-manager"
              DetailType  = "TaskApproved"
              EventBusName = aws_cloudwatch_event_bus.task_events.name
              Detail = {
                "taskId.$"    = "$.detail.taskId"
                "status"      = "approved"
                "timestamp.$" = "$$.State.EnteredTime"
              }
            }
          ]
        }
        Next = "TaskApprovalComplete"
      }

      TaskApprovalComplete = {
        Type = "Succeed"
      }

      TaskRejected = {
        Type = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              Source      = "task-manager"
              DetailType  = "TaskRejected"
              EventBusName = aws_cloudwatch_event_bus.task_events.name
              Detail = {
                "taskId.$"    = "$.detail.taskId"
                "status"      = "rejected"
                "timestamp.$" = "$$.State.EnteredTime"
              }
            }
          ]
        }
        Next = "TaskRejectionComplete"
      }

      TaskRejectionComplete = {
        Type = "Fail"
        Cause = "Task was rejected during approval process"
      }

      TaskValidationFailed = {
        Type = "Fail"
        Cause = "Task validation failed"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = var.enable_xray_tracing
  }

  tags = {
    Name = "${var.project_name}-task-approval"
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.project_name}-task-approval-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}
