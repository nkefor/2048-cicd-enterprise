import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']

# Get DynamoDB table
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Lambda function to get a task by ID

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

        # Query DynamoDB for the task
        # Note: We need createdAt for the range key, so we'll query by taskId
        response = table.query(
            KeyConditionExpression='taskId = :taskId',
            ExpressionAttributeValues={
                ':taskId': task_id
            },
            ScanIndexForward=False,
            Limit=1
        )

        # Check if task exists
        if not response.get('Items'):
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Task not found'})
            }

        task = response['Items'][0]

        # Return task
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'task': task
            }, default=str)
        }

    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to retrieve task'})
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
