import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
eventbridge = boto3.client('events')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']

# Get DynamoDB table
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Lambda function to delete a task

    Expected path parameter: taskId
    """
    try:
        # Get taskId from path parameters
        path_params = event.get('pathParameters', {})
        task_id = path_params.get('taskId')

        if not task_id:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'taskId is required'})
            }

        # First, get the task to retrieve createdAt and other details
        query_response = table.query(
            KeyConditionExpression='taskId = :taskId',
            ExpressionAttributeValues={
                ':taskId': task_id
            },
            Limit=1
        )

        if not query_response.get('Items'):
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Task not found'})
            }

        task = query_response['Items'][0]

        # Delete the task
        table.delete_item(
            Key={
                'taskId': task_id,
                'createdAt': task['createdAt']
            }
        )

        # Publish TaskDeleted event
        try:
            eventbridge.put_events(
                Entries=[
                    {
                        'Source': 'task-manager',
                        'DetailType': 'TaskDeleted',
                        'Detail': json.dumps({
                            'taskId': task_id,
                            'userId': task.get('userId'),
                            'deletedAt': task.get('updatedAt')
                        }),
                        'EventBusName': EVENT_BUS_NAME
                    }
                ]
            )
            print(f"Published TaskDeleted event for task {task_id}")
        except ClientError as e:
            print(f"Error publishing event: {e}")

        # Return success response
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'message': 'Task deleted successfully',
                'taskId': task_id
            })
        }

    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to delete task'})
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_cors_headers():
    """Return CORS headers for API responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }
