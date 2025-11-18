import json
import os
from datetime import datetime
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
    Lambda function to update a task

    Expected path parameter: taskId
    Expected body: fields to update
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

        # Parse request body
        body = json.loads(event.get('body', '{}'))

        if not body:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Request body is required'})
            }

        # First, get the task to get createdAt (needed for update)
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

        existing_task = query_response['Items'][0]
        old_status = existing_task.get('status')

        # Build update expression
        update_expr = "SET updatedAt = :updatedAt"
        expr_attr_values = {
            ':updatedAt': datetime.utcnow().isoformat()
        }
        expr_attr_names = {}

        # Updatable fields
        updatable_fields = ['title', 'description', 'status', 'priority', 'tags']

        for field in updatable_fields:
            if field in body:
                # Use expression attribute names for reserved keywords
                if field == 'status':
                    update_expr += f", #status = :status"
                    expr_attr_names['#status'] = 'status'
                    expr_attr_values[':status'] = body[field]
                else:
                    update_expr += f", {field} = :{field}"
                    expr_attr_values[f':{field}'] = body[field]

        # Update the task
        update_params = {
            'Key': {
                'taskId': task_id,
                'createdAt': existing_task['createdAt']
            },
            'UpdateExpression': update_expr,
            'ExpressionAttributeValues': expr_attr_values,
            'ReturnValues': 'ALL_NEW'
        }

        if expr_attr_names:
            update_params['ExpressionAttributeNames'] = expr_attr_names

        response = table.update_item(**update_params)

        updated_task = response['Attributes']
        new_status = updated_task.get('status')

        # Publish TaskUpdated event
        try:
            event_detail = {
                'taskId': task_id,
                'userId': updated_task.get('userId'),
                'oldStatus': old_status,
                'newStatus': new_status,
                'updatedAt': updated_task['updatedAt']
            }

            eventbridge.put_events(
                Entries=[
                    {
                        'Source': 'task-manager',
                        'DetailType': 'TaskUpdated',
                        'Detail': json.dumps(event_detail),
                        'EventBusName': EVENT_BUS_NAME
                    }
                ]
            )

            # If status changed to completed, publish TaskCompleted event
            if new_status == 'completed' and old_status != 'completed':
                eventbridge.put_events(
                    Entries=[
                        {
                            'Source': 'task-manager',
                            'DetailType': 'TaskCompleted',
                            'Detail': json.dumps(event_detail),
                            'EventBusName': EVENT_BUS_NAME
                        }
                    ]
                )
                print(f"Published TaskCompleted event for task {task_id}")

            print(f"Published TaskUpdated event for task {task_id}")
        except ClientError as e:
            print(f"Error publishing event: {e}")

        # Return success response
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'message': 'Task updated successfully',
                'task': updated_task
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
            'body': json.dumps({'error': 'Failed to update task'})
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
