"""
Unit tests for visitor_counter Lambda function.
Tests GET, POST, and error scenarios.
"""

import json
import os
import pytest
from decimal import Decimal
from moto import mock_aws
import boto3
from unittest.mock import patch, MagicMock

# Set environment variables before importing the Lambda function
os.environ['DYNAMODB_TABLE'] = 'test-visitor-counter'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

# Import the Lambda function
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from visitor_counter import lambda_handler, get_current_count, increment_count, DecimalEncoder


@pytest.fixture
def dynamodb_table():
    """Create a mock DynamoDB table for testing."""
    with mock_aws():
        # Create DynamoDB client
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

        # Create table
        table = dynamodb.create_table(
            TableName='test-visitor-counter',
            KeySchema=[
                {'AttributeName': 'id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'id', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'
        )

        # Initialize with starting count
        table.put_item(Item={'id': 'visitor_count', 'count': 0})

        yield table


def test_decimal_encoder():
    """Test DecimalEncoder converts Decimal to int."""
    data = {'count': Decimal('42')}
    result = json.dumps(data, cls=DecimalEncoder)
    assert result == '{"count": 42}'


def test_get_current_count_existing(dynamodb_table):
    """Test getting existing visitor count."""
    # Set up test data
    dynamodb_table.put_item(Item={'id': 'visitor_count', 'count': 100})

    # Test
    count = get_current_count()
    assert count == 100


def test_get_current_count_not_found(dynamodb_table):
    """Test getting count when item doesn't exist."""
    # Delete the item
    dynamodb_table.delete_item(Key={'id': 'visitor_count'})

    # Test
    count = get_current_count()
    assert count == 0


def test_increment_count(dynamodb_table):
    """Test incrementing visitor count."""
    # Initialize count
    dynamodb_table.put_item(Item={'id': 'visitor_count', 'count': 50})

    # Increment
    new_count = increment_count()
    assert new_count == 51

    # Verify in table
    response = dynamodb_table.get_item(Key={'id': 'visitor_count'})
    assert int(response['Item']['count']) == 51


def test_increment_count_multiple_times(dynamodb_table):
    """Test multiple increments are atomic."""
    # Initialize count
    dynamodb_table.put_item(Item={'id': 'visitor_count', 'count': 0})

    # Increment multiple times
    for i in range(1, 6):
        count = increment_count()
        assert count == i


def test_lambda_handler_post_request(dynamodb_table):
    """Test Lambda handler with POST request."""
    event = {
        'requestContext': {
            'http': {
                'method': 'POST'
            }
        }
    }

    context = {}

    response = lambda_handler(event, context)

    # Verify response
    assert response['statusCode'] == 200
    assert 'Access-Control-Allow-Origin' in response['headers']

    body = json.loads(response['body'])
    assert 'count' in body
    assert body['count'] == 1
    assert body['message'] == 'Visitor count incremented successfully'


def test_lambda_handler_get_request(dynamodb_table):
    """Test Lambda handler with GET request."""
    # Set up count
    dynamodb_table.put_item(Item={'id': 'visitor_count', 'count': 42})

    event = {
        'requestContext': {
            'http': {
                'method': 'GET'
            }
        }
    }

    context = {}

    response = lambda_handler(event, context)

    # Verify response
    assert response['statusCode'] == 200

    body = json.loads(response['body'])
    assert body['count'] == 42
    assert body['message'] == 'Current visitor count retrieved successfully'


def test_lambda_handler_options_request(dynamodb_table):
    """Test Lambda handler with OPTIONS request (CORS preflight)."""
    event = {
        'requestContext': {
            'http': {
                'method': 'OPTIONS'
            }
        }
    }

    context = {}

    response = lambda_handler(event, context)

    # Verify response
    assert response['statusCode'] == 200
    assert 'Access-Control-Allow-Origin' in response['headers']
    assert 'Access-Control-Allow-Methods' in response['headers']

    body = json.loads(response['body'])
    assert body['message'] == 'OK'


def test_lambda_handler_unsupported_method(dynamodb_table):
    """Test Lambda handler with unsupported HTTP method."""
    event = {
        'requestContext': {
            'http': {
                'method': 'DELETE'
            }
        }
    }

    context = {}

    response = lambda_handler(event, context)

    # Verify response
    assert response['statusCode'] == 405

    body = json.loads(response['body'])
    assert body['error'] == 'Method not allowed'


def test_lambda_handler_dynamodb_error(dynamodb_table):
    """Test Lambda handler when DynamoDB operation fails."""
    event = {
        'requestContext': {
            'http': {
                'method': 'POST'
            }
        }
    }

    context = {}

    # Mock DynamoDB error
    with patch('visitor_counter.increment_count') as mock_increment:
        from botocore.exceptions import ClientError
        mock_increment.side_effect = ClientError(
            {'Error': {'Code': 'InternalServerError', 'Message': 'Test error'}},
            'UpdateItem'
        )

        response = lambda_handler(event, context)

        # Verify error response
        assert response['statusCode'] == 500
        body = json.loads(response['body'])
        assert body['error'] == 'Internal server error'


def test_lambda_handler_unexpected_error(dynamodb_table):
    """Test Lambda handler with unexpected error."""
    event = {
        'requestContext': {
            'http': {
                'method': 'POST'
            }
        }
    }

    context = {}

    # Mock unexpected error
    with patch('visitor_counter.increment_count') as mock_increment:
        mock_increment.side_effect = Exception('Unexpected error')

        response = lambda_handler(event, context)

        # Verify error response
        assert response['statusCode'] == 500
        body = json.loads(response['body'])
        assert body['error'] == 'Internal server error'


def test_cors_headers_present(dynamodb_table):
    """Test that CORS headers are present in all responses."""
    test_methods = ['GET', 'POST', 'OPTIONS']

    for method in test_methods:
        event = {
            'requestContext': {
                'http': {
                    'method': method
                }
            }
        }

        response = lambda_handler(event, {})

        # Verify CORS headers
        assert 'Access-Control-Allow-Origin' in response['headers']
        if method == 'OPTIONS':
            assert 'Access-Control-Allow-Methods' in response['headers']
            assert 'Access-Control-Allow-Headers' in response['headers']


def test_concurrent_increments(dynamodb_table):
    """Test that concurrent increments work correctly (atomic operation)."""
    # Initialize count
    dynamodb_table.put_item(Item={'id': 'visitor_count', 'count': 0})

    # Simulate concurrent requests
    from concurrent.futures import ThreadPoolExecutor

    def make_request():
        event = {
            'requestContext': {
                'http': {
                    'method': 'POST'
                }
            }
        }
        return lambda_handler(event, {})

    # Make 10 concurrent requests
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_request) for _ in range(10)]
        results = [f.result() for f in futures]

    # Verify all requests succeeded
    assert all(r['statusCode'] == 200 for r in results)

    # Verify final count is exactly 10
    response = dynamodb_table.get_item(Key={'id': 'visitor_count'})
    assert int(response['Item']['count']) == 10


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=visitor_counter', '--cov-report=term-missing'])
