import json
import os
import boto3
from datetime import datetime

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

def handler(event, context):
    """
    Handler for TaskUpdated events from EventBridge

    Tracks task updates and sends notifications
    Publishes custom CloudWatch metrics
    """
    try:
        print(f"Received TaskUpdated event: {json.dumps(event)}")

        # Extract task details from event
        detail = event.get('detail', {})
        task_id = detail.get('taskId')
        old_status = detail.get('oldStatus')
        new_status = detail.get('newStatus')
        user_id = detail.get('userId')

        if not task_id:
            print("Error: taskId not found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid event structure'})
            }

        # Log task update
        print(f"Task {task_id} updated: {old_status} -> {new_status}")

        # Publish custom CloudWatch metric for task status changes
        try:
            cloudwatch.put_metric_data(
                Namespace=f'TaskManager/{ENVIRONMENT}',
                MetricData=[
                    {
                        'MetricName': 'TaskUpdates',
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow(),
                        'Dimensions': [
                            {
                                'Name': 'Status',
                                'Value': new_status
                            },
                            {
                                'Name': 'Environment',
                                'Value': ENVIRONMENT
                            }
                        ]
                    }
                ]
            )
            print(f"Published CloudWatch metric for task update")
        except Exception as e:
            print(f"Error publishing CloudWatch metric: {e}")

        # Send notification based on status change
        if new_status == 'in_progress':
            print(f"Notification: Task {task_id} is now in progress")
        elif new_status == 'blocked':
            print(f"Alert: Task {task_id} is blocked and needs attention")
        elif new_status == 'completed':
            print(f"Success: Task {task_id} has been completed")

        # Track task lifecycle metrics
        print(f"Analytics: Task update recorded for user {user_id}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'TaskUpdated event processed successfully',
                'taskId': task_id,
                'statusChange': f'{old_status} -> {new_status}'
            })
        }

    except Exception as e:
        print(f"Error processing TaskUpdated event: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process event'})
        }
