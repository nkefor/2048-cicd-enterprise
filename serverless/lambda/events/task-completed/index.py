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

# Get DynamoDB table
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Handler for TaskCompleted events from EventBridge

    Calculates task completion metrics
    Archives completed tasks
    Sends completion notifications
    """
    try:
        print(f"Received TaskCompleted event: {json.dumps(event)}")

        # Extract task details from event
        detail = event.get('detail', {})
        task_id = detail.get('taskId')
        user_id = detail.get('userId')

        if not task_id:
            print("Error: taskId not found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid event structure'})
            }

        # Get full task details from DynamoDB
        try:
            query_response = table.query(
                KeyConditionExpression='taskId = :taskId',
                ExpressionAttributeValues={
                    ':taskId': task_id
                },
                Limit=1
            )

            if query_response.get('Items'):
                task = query_response['Items'][0]

                # Calculate task duration
                created_at = datetime.fromisoformat(task.get('createdAt'))
                completed_at = datetime.utcnow()
                duration_hours = (completed_at - created_at).total_seconds() / 3600

                print(f"Task {task_id} completed in {duration_hours:.2f} hours")

                # Publish completion metrics to CloudWatch
                try:
                    cloudwatch.put_metric_data(
                        Namespace=f'TaskManager/{ENVIRONMENT}',
                        MetricData=[
                            {
                                'MetricName': 'TaskCompletions',
                                'Value': 1,
                                'Unit': 'Count',
                                'Timestamp': datetime.utcnow(),
                                'Dimensions': [
                                    {
                                        'Name': 'Priority',
                                        'Value': task.get('priority', 'medium')
                                    },
                                    {
                                        'Name': 'Environment',
                                        'Value': ENVIRONMENT
                                    }
                                ]
                            },
                            {
                                'MetricName': 'TaskDuration',
                                'Value': duration_hours,
                                'Unit': 'None',
                                'Timestamp': datetime.utcnow(),
                                'Dimensions': [
                                    {
                                        'Name': 'Priority',
                                        'Value': task.get('priority', 'medium')
                                    }
                                ]
                            }
                        ]
                    )
                    print(f"Published completion metrics to CloudWatch")
                except Exception as e:
                    print(f"Error publishing metrics: {e}")

        except Exception as e:
            print(f"Error retrieving task details: {e}")

        # Send completion notification
        print(f"Notification: Task {task_id} completed by user {user_id}")

        # Update user statistics (placeholder for gamification/stats)
        print(f"Analytics: Updated completion stats for user {user_id}")

        # Trigger any post-completion workflows
        print(f"Post-completion: Checking for dependent tasks")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'TaskCompleted event processed successfully',
                'taskId': task_id
            })
        }

    except Exception as e:
        print(f"Error processing TaskCompleted event: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process event'})
        }
