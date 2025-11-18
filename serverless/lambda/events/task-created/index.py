import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
stepfunctions = boto3.client('stepfunctions')
dynamodb = boto3.resource('dynamodb')

# Environment variables
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']
TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']

def handler(event, context):
    """
    Handler for TaskCreated events from EventBridge

    Triggers Step Functions workflow for high-priority tasks
    Logs task creation for analytics
    """
    try:
        print(f"Received TaskCreated event: {json.dumps(event)}")

        # Extract task details from event
        detail = event.get('detail', {})
        task_id = detail.get('taskId')
        priority = detail.get('priority')
        user_id = detail.get('userId')

        if not task_id:
            print("Error: taskId not found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid event structure'})
            }

        # Log task creation
        print(f"Task {task_id} created by user {user_id} with priority {priority}")

        # For high-priority tasks, initiate Step Functions workflow
        if priority == 'high':
            try:
                execution_response = stepfunctions.start_execution(
                    stateMachineArn=STATE_MACHINE_ARN,
                    name=f"approval-{task_id}",
                    input=json.dumps({
                        'detail': detail,
                        'source': event.get('source'),
                        'detailType': event.get('detail-type')
                    })
                )
                print(f"Started Step Functions execution: {execution_response['executionArn']}")
            except ClientError as e:
                if e.response['Error']['Code'] == 'ExecutionAlreadyExists':
                    print(f"Execution already exists for task {task_id}")
                else:
                    print(f"Error starting Step Functions execution: {e}")
                    raise

        # Send notification (placeholder - could integrate SNS/SES)
        print(f"Notification: New {priority} priority task created")

        # Update analytics/metrics (placeholder - could use CloudWatch Metrics)
        print(f"Analytics: Task creation recorded for user {user_id}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'TaskCreated event processed successfully',
                'taskId': task_id
            })
        }

    except Exception as e:
        print(f"Error processing TaskCreated event: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process event'})
        }
