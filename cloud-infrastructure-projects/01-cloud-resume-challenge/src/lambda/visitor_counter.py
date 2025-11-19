"""
Lambda function for tracking resume website visitor count.
Increments a counter in DynamoDB and returns the current count.
"""

import json
import os
import boto3
from decimal import Decimal
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE', 'cloud-resume-visitor-counter')
table = dynamodb.Table(table_name)

# CORS headers for API Gateway
CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',  # Update with your domain in production
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
}


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal types to JSON-serializable types."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)


def get_current_count():
    """
    Retrieve the current visitor count from DynamoDB.

    Returns:
        int: Current visitor count, or 0 if not found
    """
    try:
        response = table.get_item(Key={'id': 'visitor_count'})
        if 'Item' in response:
            return int(response['Item'].get('count', 0))
        return 0
    except ClientError as e:
        print(f"Error getting current count: {e.response['Error']['Message']}")
        raise


def increment_count():
    """
    Atomically increment the visitor count in DynamoDB.

    Returns:
        int: New visitor count after increment
    """
    try:
        response = table.update_item(
            Key={'id': 'visitor_count'},
            UpdateExpression='ADD #count :increment',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={':increment': 1},
            ReturnValues='UPDATED_NEW'
        )
        return int(response['Attributes']['count'])
    except ClientError as e:
        print(f"Error incrementing count: {e.response['Error']['Message']}")
        raise


def lambda_handler(event, context):
    """
    Main Lambda handler function.

    Handles both GET (retrieve count) and POST (increment count) requests.

    Args:
        event: API Gateway event object
        context: Lambda context object

    Returns:
        dict: API Gateway response with status code, headers, and body
    """
    print(f"Received event: {json.dumps(event)}")

    # Handle preflight OPTIONS request
    http_method = event.get('requestContext', {}).get('http', {}).get('method', 'POST')
    if http_method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': CORS_HEADERS,
            'body': json.dumps({'message': 'OK'})
        }

    try:
        # Handle GET request - return current count
        if http_method == 'GET':
            current_count = get_current_count()

            return {
                'statusCode': 200,
                'headers': {
                    **CORS_HEADERS,
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'count': current_count,
                    'message': 'Current visitor count retrieved successfully'
                }, cls=DecimalEncoder)
            }

        # Handle POST request - increment and return new count
        elif http_method == 'POST':
            new_count = increment_count()

            print(f"Visitor count incremented to: {new_count}")

            return {
                'statusCode': 200,
                'headers': {
                    **CORS_HEADERS,
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'count': new_count,
                    'message': 'Visitor count incremented successfully'
                }, cls=DecimalEncoder)
            }

        # Handle unsupported methods
        else:
            return {
                'statusCode': 405,
                'headers': CORS_HEADERS,
                'body': json.dumps({
                    'error': 'Method not allowed',
                    'message': f'HTTP method {http_method} is not supported'
                })
            }

    except ClientError as e:
        print(f"DynamoDB error: {e.response['Error']['Message']}")
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'Failed to process visitor count'
            })
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'An unexpected error occurred'
            })
        }


# For local testing
if __name__ == '__main__':
    # Test event simulating API Gateway POST request
    test_event = {
        'requestContext': {
            'http': {
                'method': 'POST'
            }
        }
    }

    test_context = {}

    result = lambda_handler(test_event, test_context)
    print(f"\nTest Result:\n{json.dumps(result, indent=2)}")
