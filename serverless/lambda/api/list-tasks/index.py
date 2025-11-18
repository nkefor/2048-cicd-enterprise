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
    Lambda function to list tasks with optional filtering

    Query parameters:
    - status: Filter by status
    - userId: Filter by userId
    - limit: Number of items to return (default: 20)
    """
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}

        status = query_params.get('status')
        user_id = query_params.get('userId')
        limit = int(query_params.get('limit', 20))

        # Determine which query to use based on filters
        if status:
            # Use StatusIndex GSI
            response = table.query(
                IndexName='StatusIndex',
                KeyConditionExpression='#status = :status',
                ExpressionAttributeNames={
                    '#status': 'status'
                },
                ExpressionAttributeValues={
                    ':status': status
                },
                ScanIndexForward=False,
                Limit=limit
            )
        elif user_id:
            # Use UserIdIndex GSI
            response = table.query(
                IndexName='UserIdIndex',
                KeyConditionExpression='userId = :userId',
                ExpressionAttributeValues={
                    ':userId': user_id
                },
                ScanIndexForward=False,
                Limit=limit
            )
        else:
            # Scan table (less efficient, but works for demo)
            response = table.scan(
                Limit=limit
            )

        tasks = response.get('Items', [])

        # Return tasks
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'tasks': tasks,
                'count': len(tasks),
                'lastEvaluatedKey': response.get('LastEvaluatedKey')
            }, default=str)
        }

    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to list tasks'})
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
