import json
import os
import uuid
from datetime import datetime, timedelta
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
eventbridge = boto3.client('events')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

# Get DynamoDB table
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Lambda function to create a new task

    Expected input:
    {
        "title": "Task title",
        "description": "Task description",
        "priority": "low|medium|high",
        "userId": "user123"
    }
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))

        # Validate required fields
        if not body.get('title'):
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Title is required'})
            }

        if not body.get('userId'):
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'userId is required'})
            }

        # Generate task ID and timestamp
        task_id = str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat()

        # Set TTL for 90 days (for completed tasks)
        ttl = int((datetime.utcnow() + timedelta(days=90)).timestamp())

        # Create task item
        task = {
            'taskId': task_id,
            'createdAt': created_at,
            'updatedAt': created_at,
            'title': body['title'],
            'description': body.get('description', ''),
            'priority': body.get('priority', 'medium'),
            'status': 'pending',
            'userId': body['userId'],
            'ttl': ttl,
            'tags': body.get('tags', []),
            'metadata': {
                'environment': ENVIRONMENT,
                'createdBy': 'api'
            }
        }

        # Save to DynamoDB
        table.put_item(Item=task)

        # Publish TaskCreated event to EventBridge
        try:
            eventbridge.put_events(
                Entries=[
                    {
                        'Source': 'task-manager',
                        'DetailType': 'TaskCreated',
                        'Detail': json.dumps({
                            'taskId': task_id,
                            'userId': body['userId'],
                            'priority': task['priority'],
                            'status': 'pending',
                            'createdAt': created_at
                        }),
                        'EventBusName': EVENT_BUS_NAME
                    }
                ]
            )
            print(f"Published TaskCreated event for task {task_id}")
        except ClientError as e:
            print(f"Error publishing event: {e}")
            # Continue even if event publication fails

        # Return success response
        return {
            'statusCode': 201,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'message': 'Task created successfully',
                'task': task
            }, default=str)
        }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to create task'})
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
