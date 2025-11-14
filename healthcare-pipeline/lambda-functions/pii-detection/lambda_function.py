"""
PII/PHI Detection Lambda Function
Uses Amazon Comprehend Medical to detect and classify sensitive healthcare information
"""

import json
import boto3
import os
import logging
from datetime import datetime
from typing import Dict, List, Any
import uuid

# Initialize AWS clients
comprehend_medical = boto3.client('comprehendmedical')
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
QUARANTINE_BUCKET = os.environ.get('QUARANTINE_BUCKET')
AUDIT_TABLE = os.environ.get('AUDIT_TABLE')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
PII_THRESHOLD = float(os.environ.get('PII_THRESHOLD', '0.8'))

# Entity types that are considered PHI/PII
PHI_ENTITY_TYPES = [
    'NAME',
    'AGE',
    'ID',
    'EMAIL',
    'URL',
    'ADDRESS',
    'PROFESSION',
    'PHONE_OR_FAX',
    'DATE'
]


def lambda_handler(event, context):
    """
    Main Lambda handler for PII/PHI detection

    Args:
        event: Lambda event containing S3 object information
        context: Lambda context

    Returns:
        dict: Processing result
    """
    try:
        logger.info(f"Processing event: {json.dumps(event)}")

        # Extract S3 object information
        record = event['Records'][0] if 'Records' in event else event
        bucket = record['s3']['bucket']['name'] if 's3' in record else event.get('bucket')
        key = record['s3']['object']['key'] if 's3' in record else event.get('key')

        if not bucket or not key:
            raise ValueError("Missing bucket or key in event")

        # Generate processing ID
        processing_id = str(uuid.uuid4())
        start_time = datetime.utcnow()

        logger.info(f"Processing file: s3://{bucket}/{key} with ID: {processing_id}")

        # Read file content from S3
        file_content = read_s3_file(bucket, key)

        # Detect PHI/PII entities
        entities = detect_phi_entities(file_content)

        # Classify and assess risk
        risk_assessment = assess_risk(entities)

        # Process based on risk level
        result = process_based_on_risk(
            bucket, key, file_content, entities,
            risk_assessment, processing_id
        )

        # Log audit trail
        log_audit_trail(
            processing_id, bucket, key, entities,
            risk_assessment, result['action'], start_time
        )

        # Send CloudWatch metrics
        send_metrics(entities, risk_assessment)

        # Send alert if high risk
        if risk_assessment['risk_level'] == 'HIGH':
            send_alert(processing_id, bucket, key, risk_assessment)

        logger.info(f"Processing completed: {result}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'processing_id': processing_id,
                'action': result['action'],
                'risk_level': risk_assessment['risk_level'],
                'entities_detected': len(entities),
                'output_location': result.get('output_location')
            })
        }

    except Exception as e:
        logger.error(f"Error processing file: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def read_s3_file(bucket: str, key: str) -> str:
    """Read file content from S3"""
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        return content
    except Exception as e:
        logger.error(f"Error reading S3 file: {str(e)}")
        raise


def detect_phi_entities(text: str) -> List[Dict[str, Any]]:
    """
    Detect PHI/PII entities using Amazon Comprehend Medical

    Args:
        text: Text content to analyze

    Returns:
        List of detected entities
    """
    entities = []

    try:
        # Detect entities (medical and PHI)
        response = comprehend_medical.detect_entities_v2(Text=text)

        for entity in response['Entities']:
            entities.append({
                'text': entity['Text'],
                'category': entity['Category'],
                'type': entity['Type'],
                'score': entity['Score'],
                'begin_offset': entity['BeginOffset'],
                'end_offset': entity['EndOffset'],
                'traits': entity.get('Traits', []),
                'attributes': entity.get('Attributes', [])
            })

        # Detect PHI (Protected Health Information)
        phi_response = comprehend_medical.detect_phi(Text=text)

        for entity in phi_response['Entities']:
            if entity['Type'] in PHI_ENTITY_TYPES:
                entities.append({
                    'text': entity['Text'],
                    'category': 'PHI',
                    'type': entity['Type'],
                    'score': entity['Score'],
                    'begin_offset': entity['BeginOffset'],
                    'end_offset': entity['EndOffset'],
                    'is_phi': True
                })

        logger.info(f"Detected {len(entities)} entities")
        return entities

    except Exception as e:
        logger.error(f"Error detecting entities: {str(e)}")
        raise


def assess_risk(entities: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Assess risk level based on detected entities

    Args:
        entities: List of detected entities

    Returns:
        Risk assessment dictionary
    """
    phi_count = sum(1 for e in entities if e.get('is_phi', False))
    high_confidence_phi = sum(
        1 for e in entities
        if e.get('is_phi', False) and e['score'] >= PII_THRESHOLD
    )

    # Determine risk level
    if high_confidence_phi > 5:
        risk_level = 'HIGH'
    elif high_confidence_phi > 0 or phi_count > 10:
        risk_level = 'MEDIUM'
    elif phi_count > 0:
        risk_level = 'LOW'
    else:
        risk_level = 'MINIMAL'

    return {
        'risk_level': risk_level,
        'total_entities': len(entities),
        'phi_count': phi_count,
        'high_confidence_phi': high_confidence_phi,
        'phi_types': list(set(e['type'] for e in entities if e.get('is_phi', False)))
    }


def process_based_on_risk(
    bucket: str, key: str, content: str,
    entities: List[Dict[str, Any]],
    risk_assessment: Dict[str, Any],
    processing_id: str
) -> Dict[str, Any]:
    """
    Process file based on risk assessment

    Args:
        bucket: Source S3 bucket
        key: Source S3 key
        content: File content
        entities: Detected entities
        risk_assessment: Risk assessment result
        processing_id: Unique processing ID

    Returns:
        Processing result
    """
    risk_level = risk_assessment['risk_level']

    if risk_level in ['HIGH', 'MEDIUM']:
        # Quarantine high/medium risk files
        return quarantine_file(bucket, key, content, processing_id, risk_assessment)
    else:
        # Process and de-identify low risk files
        masked_content = mask_phi_entities(content, entities)
        return save_processed_file(key, masked_content, processing_id, entities)


def mask_phi_entities(content: str, entities: List[Dict[str, Any]]) -> str:
    """
    Mask PHI entities in content

    Args:
        content: Original content
        entities: Detected entities to mask

    Returns:
        Masked content
    """
    # Sort entities by offset in reverse order to maintain positions
    sorted_entities = sorted(
        [e for e in entities if e.get('is_phi', False)],
        key=lambda x: x['begin_offset'],
        reverse=True
    )

    masked_content = content

    for entity in sorted_entities:
        start = entity['begin_offset']
        end = entity['end_offset']
        entity_type = entity['type']

        # Create mask based on entity type
        mask = f"[{entity_type}_REDACTED]"

        masked_content = masked_content[:start] + mask + masked_content[end:]

    return masked_content


def save_processed_file(
    original_key: str,
    content: str,
    processing_id: str,
    entities: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """Save processed file to S3"""
    try:
        # Generate output key
        output_key = f"processed/{datetime.utcnow().strftime('%Y/%m/%d')}/{processing_id}/{original_key.split('/')[-1]}"

        # Save masked content
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=output_key,
            Body=content.encode('utf-8'),
            ServerSideEncryption='aws:kms',
            Metadata={
                'processing-id': processing_id,
                'original-key': original_key,
                'entities-detected': str(len(entities)),
                'processed-date': datetime.utcnow().isoformat()
            }
        )

        # Save entity metadata
        metadata_key = f"{output_key}.metadata.json"
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=metadata_key,
            Body=json.dumps(entities, indent=2).encode('utf-8'),
            ServerSideEncryption='aws:kms'
        )

        logger.info(f"Saved processed file to: s3://{PROCESSED_BUCKET}/{output_key}")

        return {
            'action': 'PROCESSED',
            'output_location': f"s3://{PROCESSED_BUCKET}/{output_key}"
        }

    except Exception as e:
        logger.error(f"Error saving processed file: {str(e)}")
        raise


def quarantine_file(
    bucket: str, key: str, content: str,
    processing_id: str, risk_assessment: Dict[str, Any]
) -> Dict[str, Any]:
    """Quarantine high-risk file"""
    try:
        # Generate quarantine key
        quarantine_key = f"quarantine/{datetime.utcnow().strftime('%Y/%m/%d')}/{processing_id}/{key.split('/')[-1]}"

        # Save to quarantine bucket
        s3.put_object(
            Bucket=QUARANTINE_BUCKET,
            Key=quarantine_key,
            Body=content.encode('utf-8'),
            ServerSideEncryption='aws:kms',
            Metadata={
                'processing-id': processing_id,
                'original-bucket': bucket,
                'original-key': key,
                'risk-level': risk_assessment['risk_level'],
                'quarantine-date': datetime.utcnow().isoformat()
            },
            Tagging=f"RiskLevel={risk_assessment['risk_level']}&Status=Quarantined"
        )

        logger.info(f"Quarantined file to: s3://{QUARANTINE_BUCKET}/{quarantine_key}")

        return {
            'action': 'QUARANTINED',
            'output_location': f"s3://{QUARANTINE_BUCKET}/{quarantine_key}",
            'reason': f"High PHI risk: {risk_assessment['high_confidence_phi']} entities detected"
        }

    except Exception as e:
        logger.error(f"Error quarantining file: {str(e)}")
        raise


def log_audit_trail(
    processing_id: str, bucket: str, key: str,
    entities: List[Dict[str, Any]], risk_assessment: Dict[str, Any],
    action: str, start_time: datetime
) -> None:
    """Log audit trail to DynamoDB"""
    try:
        table = dynamodb.Table(AUDIT_TABLE)

        table.put_item(
            Item={
                'processing_id': processing_id,
                'timestamp': datetime.utcnow().isoformat(),
                'source_bucket': bucket,
                'source_key': key,
                'action': action,
                'risk_level': risk_assessment['risk_level'],
                'entities_detected': len(entities),
                'phi_count': risk_assessment['phi_count'],
                'processing_duration_ms': int((datetime.utcnow() - start_time).total_seconds() * 1000),
                'phi_types': risk_assessment['phi_types']
            }
        )

        logger.info(f"Logged audit trail for processing ID: {processing_id}")

    except Exception as e:
        logger.error(f"Error logging audit trail: {str(e)}")
        # Don't raise - audit logging failure shouldn't stop processing


def send_metrics(entities: List[Dict[str, Any]], risk_assessment: Dict[str, Any]) -> None:
    """Send custom metrics to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='HealthcarePipeline/PHI',
            MetricData=[
                {
                    'MetricName': 'EntitiesDetected',
                    'Value': len(entities),
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'PHICount',
                    'Value': risk_assessment['phi_count'],
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'RiskLevel',
                    'Value': {'HIGH': 3, 'MEDIUM': 2, 'LOW': 1, 'MINIMAL': 0}[risk_assessment['risk_level']],
                    'Unit': 'None',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        logger.error(f"Error sending metrics: {str(e)}")


def send_alert(
    processing_id: str, bucket: str, key: str,
    risk_assessment: Dict[str, Any]
) -> None:
    """Send SNS alert for high-risk files"""
    try:
        message = {
            'alert_type': 'HIGH_PHI_RISK',
            'processing_id': processing_id,
            'source': f"s3://{bucket}/{key}",
            'risk_level': risk_assessment['risk_level'],
            'phi_count': risk_assessment['phi_count'],
            'high_confidence_phi': risk_assessment['high_confidence_phi'],
            'phi_types': risk_assessment['phi_types'],
            'timestamp': datetime.utcnow().isoformat(),
            'action_required': 'File has been quarantined and requires manual review'
        }

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"HIGH RISK PHI DETECTED - Processing ID: {processing_id}",
            Message=json.dumps(message, indent=2)
        )

        logger.info(f"Sent alert for processing ID: {processing_id}")

    except Exception as e:
        logger.error(f"Error sending alert: {str(e)}")
