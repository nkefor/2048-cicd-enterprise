"""
AWS Security Audit - Auto-Remediation Lambda Function
Automatically fixes common security findings from Security Hub
"""

import json
import os
import boto3
import logging
from datetime import datetime
from typing import Dict, List, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
s3 = boto3.client('s3')
ec2 = boto3.client('ec2')
iam = boto3.client('iam')
securityhub = boto3.client('securityhub')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

# Environment variables
FINDINGS_TABLE = os.environ['FINDINGS_TABLE']
REMEDIATION_TABLE = os.environ['REMEDIATION_TABLE']
EVIDENCE_BUCKET = os.environ['EVIDENCE_BUCKET']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
AUTO_REMEDIATE_CRITICAL = os.environ.get('AUTO_REMEDIATE_CRITICAL', 'true').lower() == 'true'
AUTO_REMEDIATE_HIGH = os.environ.get('AUTO_REMEDIATE_HIGH', 'true').lower() == 'true'
AUTO_REMEDIATE_MEDIUM = os.environ.get('AUTO_REMEDIATE_MEDIUM', 'false').lower() == 'true'

# DynamoDB tables
findings_table = dynamodb.Table(FINDINGS_TABLE)
remediation_table = dynamodb.Table(REMEDIATION_TABLE)


def lambda_handler(event, context):
    """
    Main Lambda handler for auto-remediation
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Extract findings from Security Hub event
        findings = extract_findings(event)

        results = {
            'total_findings': len(findings),
            'remediated': 0,
            'skipped': 0,
            'failed': 0,
            'details': []
        }

        for finding in findings:
            result = process_finding(finding)
            results['details'].append(result)

            if result['status'] == 'REMEDIATED':
                results['remediated'] += 1
            elif result['status'] == 'SKIPPED':
                results['skipped'] += 1
            else:
                results['failed'] += 1

        # Send summary notification
        send_summary_notification(results)

        logger.info(f"Remediation complete: {json.dumps(results)}")
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }

    except Exception as e:
        logger.error(f"Error in auto-remediation: {str(e)}", exc_info=True)
        send_error_notification(str(e))
        raise


def extract_findings(event: Dict) -> List[Dict]:
    """Extract findings from EventBridge event"""
    findings = []

    if 'detail' in event and 'findings' in event['detail']:
        findings = event['detail']['findings']
    elif isinstance(event, list):
        findings = event

    return findings


def process_finding(finding: Dict) -> Dict:
    """Process a single security finding"""
    finding_id = finding.get('Id', 'Unknown')
    finding_type = finding.get('Types', ['Unknown'])[0]
    severity = finding.get('Severity', {}).get('Label', 'MEDIUM')
    title = finding.get('Title', 'Unknown')

    logger.info(f"Processing finding: {finding_id} - {title} ({severity})")

    # Check if auto-remediation is enabled for this severity
    if not should_auto_remediate(severity):
        logger.info(f"Auto-remediation disabled for {severity} severity")
        return {
            'finding_id': finding_id,
            'status': 'SKIPPED',
            'reason': f'Auto-remediation disabled for {severity} severity'
        }

    # Store finding in DynamoDB
    store_finding(finding)

    # Determine remediation action based on finding type
    remediation_result = None

    try:
        # S3 Security Findings
        if 'S3.1' in finding_type or 'S3.8' in finding_type:
            remediation_result = remediate_s3_public_bucket(finding)
        elif 'S3.4' in finding_type:
            remediation_result = remediate_s3_encryption(finding)

        # EC2 Security Group Findings
        elif 'EC2.19' in finding_type or 'EC2.21' in finding_type:
            remediation_result = remediate_security_group_ssh_rdp(finding)

        # IAM Security Findings
        elif 'IAM.3' in finding_type:
            remediation_result = remediate_iam_access_keys(finding)
        elif 'IAM.6' in finding_type:
            remediation_result = remediate_iam_password_policy(finding)

        # CloudTrail Findings
        elif '2.1' in finding_type or 'CloudTrail.1' in finding_type:
            remediation_result = remediate_cloudtrail_disabled(finding)

        # Default: Manual remediation required
        else:
            remediation_result = {
                'finding_id': finding_id,
                'status': 'MANUAL_REQUIRED',
                'reason': f'No auto-remediation available for {finding_type}'
            }

        # Log remediation action
        if remediation_result:
            log_remediation_action(finding, remediation_result)

            # Update Security Hub finding status
            if remediation_result['status'] == 'REMEDIATED':
                update_securityhub_finding(finding_id, 'RESOLVED')

        return remediation_result or {
            'finding_id': finding_id,
            'status': 'FAILED',
            'reason': 'Unknown error'
        }

    except Exception as e:
        logger.error(f"Remediation failed for {finding_id}: {str(e)}")
        return {
            'finding_id': finding_id,
            'status': 'FAILED',
            'reason': str(e)
        }


def should_auto_remediate(severity: str) -> bool:
    """Determine if finding should be auto-remediated based on severity"""
    if severity == 'CRITICAL':
        return AUTO_REMEDIATE_CRITICAL
    elif severity == 'HIGH':
        return AUTO_REMEDIATE_HIGH
    elif severity == 'MEDIUM':
        return AUTO_REMEDIATE_MEDIUM
    else:
        return False


def remediate_s3_public_bucket(finding: Dict) -> Dict:
    """
    Remediate S3 bucket with public access
    CIS Control: 2.3
    """
    try:
        bucket_name = extract_resource_id(finding, 's3')

        logger.info(f"Remediating public S3 bucket: {bucket_name}")

        # 1. Block public access
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )

        # 2. Enable default encryption (if not already enabled)
        try:
            s3.put_bucket_encryption(
                Bucket=bucket_name,
                ServerSideEncryptionConfiguration={
                    'Rules': [{
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'AES256'
                        },
                        'BucketKeyEnabled': True
                    }]
                }
            )
        except Exception as e:
            logger.warning(f"Encryption already enabled or error: {str(e)}")

        # 3. Enable versioning
        s3.put_bucket_versioning(
            Bucket=bucket_name,
            VersioningConfiguration={'Status': 'Enabled'}
        )

        return {
            'finding_id': finding['Id'],
            'status': 'REMEDIATED',
            'actions': [
                'Blocked public access',
                'Enabled encryption',
                'Enabled versioning'
            ],
            'resource': bucket_name
        }

    except Exception as e:
        logger.error(f"Failed to remediate S3 bucket: {str(e)}")
        return {
            'finding_id': finding['Id'],
            'status': 'FAILED',
            'reason': str(e)
        }


def remediate_security_group_ssh_rdp(finding: Dict) -> Dict:
    """
    Remediate security group with open SSH/RDP
    CIS Control: 4.1, 4.2
    """
    try:
        sg_id = extract_resource_id(finding, 'security-group')

        logger.info(f"Remediating open SSH/RDP in security group: {sg_id}")

        actions = []

        # Remove unrestricted SSH (port 22)
        try:
            ec2.revoke_security_group_ingress(
                GroupId=sg_id,
                IpPermissions=[{
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                }]
            )
            actions.append('Removed open SSH (0.0.0.0/0:22)')
        except Exception as e:
            if 'InvalidPermission.NotFound' not in str(e):
                logger.warning(f"SSH rule not found or error: {str(e)}")

        # Remove unrestricted RDP (port 3389)
        try:
            ec2.revoke_security_group_ingress(
                GroupId=sg_id,
                IpPermissions=[{
                    'IpProtocol': 'tcp',
                    'FromPort': 3389,
                    'ToPort': 3389,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                }]
            )
            actions.append('Removed open RDP (0.0.0.0/0:3389)')
        except Exception as e:
            if 'InvalidPermission.NotFound' not in str(e):
                logger.warning(f"RDP rule not found or error: {str(e)}")

        return {
            'finding_id': finding['Id'],
            'status': 'REMEDIATED',
            'actions': actions,
            'resource': sg_id
        }

    except Exception as e:
        logger.error(f"Failed to remediate security group: {str(e)}")
        return {
            'finding_id': finding['Id'],
            'status': 'FAILED',
            'reason': str(e)
        }


def remediate_iam_access_keys(finding: Dict) -> Dict:
    """
    Remediate IAM access keys older than 90 days
    CIS Control: 1.4
    """
    try:
        user_name = extract_resource_id(finding, 'iam-user')

        logger.info(f"Remediating old access keys for IAM user: {user_name}")

        # Get access keys for user
        response = iam.list_access_keys(UserName=user_name)

        actions = []
        for key in response['AccessKeyMetadata']:
            key_id = key['AccessKeyId']
            created_date = key['CreateDate'].replace(tzinfo=None)
            age_days = (datetime.now() - created_date).days

            if age_days > 90:
                # Deactivate old access key
                iam.update_access_key(
                    UserName=user_name,
                    AccessKeyId=key_id,
                    Status='Inactive'
                )
                actions.append(f'Deactivated access key {key_id} (age: {age_days} days)')

                # Notify user to rotate key
                send_key_rotation_notification(user_name, key_id)

        return {
            'finding_id': finding['Id'],
            'status': 'REMEDIATED',
            'actions': actions,
            'resource': user_name
        }

    except Exception as e:
        logger.error(f"Failed to remediate IAM access keys: {str(e)}")
        return {
            'finding_id': finding['Id'],
            'status': 'FAILED',
            'reason': str(e)
        }


def remediate_iam_password_policy(finding: Dict) -> Dict:
    """
    Enforce strong IAM password policy
    CIS Control: 1.5-1.11
    """
    try:
        logger.info("Enforcing IAM password policy")

        iam.update_account_password_policy(
            MinimumPasswordLength=14,
            RequireSymbols=True,
            RequireNumbers=True,
            RequireUppercaseCharacters=True,
            RequireLowercaseCharacters=True,
            AllowUsersToChangePassword=True,
            MaxPasswordAge=90,
            PasswordReusePrevention=12,
            HardExpiry=False
        )

        return {
            'finding_id': finding['Id'],
            'status': 'REMEDIATED',
            'actions': ['Enforced strong password policy'],
            'resource': 'AWS Account'
        }

    except Exception as e:
        logger.error(f"Failed to update password policy: {str(e)}")
        return {
            'finding_id': finding['Id'],
            'status': 'FAILED',
            'reason': str(e)
        }


def remediate_s3_encryption(finding: Dict) -> Dict:
    """Enable S3 bucket encryption"""
    try:
        bucket_name = extract_resource_id(finding, 's3')

        logger.info(f"Enabling encryption for S3 bucket: {bucket_name}")

        s3.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
                'Rules': [{
                    'ApplyServerSideEncryptionByDefault': {
                        'SSEAlgorithm': 'AES256'
                    },
                    'BucketKeyEnabled': True
                }]
            }
        )

        return {
            'finding_id': finding['Id'],
            'status': 'REMEDIATED',
            'actions': ['Enabled default encryption (AES256)'],
            'resource': bucket_name
        }

    except Exception as e:
        logger.error(f"Failed to enable S3 encryption: {str(e)}")
        return {
            'finding_id': finding['Id'],
            'status': 'FAILED',
            'reason': str(e)
        }


def remediate_cloudtrail_disabled(finding: Dict) -> Dict:
    """Enable CloudTrail in all regions"""
    # This is a complex remediation that requires CloudTrail setup
    # For now, we'll mark as manual required
    return {
        'finding_id': finding['Id'],
        'status': 'MANUAL_REQUIRED',
        'reason': 'CloudTrail setup requires manual configuration'
    }


def extract_resource_id(finding: Dict, resource_type: str) -> str:
    """Extract resource ID from finding"""
    resources = finding.get('Resources', [])

    for resource in resources:
        resource_id = resource.get('Id', '')

        if resource_type == 's3':
            # ARN format: arn:aws:s3:::bucket-name
            if 's3:::' in resource_id:
                return resource_id.split(':::')[-1]

        elif resource_type == 'security-group':
            # ARN format: .../security-group/sg-xxxxx
            if 'security-group/' in resource_id:
                return resource_id.split('/')[-1]

        elif resource_type == 'iam-user':
            # ARN format: arn:aws:iam::account:user/username
            if ':user/' in resource_id:
                return resource_id.split('/')[-1]

    raise ValueError(f"Could not extract {resource_type} ID from finding")


def store_finding(finding: Dict):
    """Store finding in DynamoDB"""
    try:
        findings_table.put_item(
            Item={
                'finding_id': finding['Id'],
                'timestamp': int(datetime.now().timestamp()),
                'severity': finding.get('Severity', {}).get('Label', 'MEDIUM'),
                'account_id': finding.get('AwsAccountId', 'Unknown'),
                'title': finding.get('Title', 'Unknown'),
                'finding_type': finding.get('Types', ['Unknown'])[0],
                'compliance_status': finding.get('Compliance', {}).get('Status', 'UNKNOWN'),
                'full_finding': json.dumps(finding)
            }
        )
    except Exception as e:
        logger.error(f"Failed to store finding: {str(e)}")


def log_remediation_action(finding: Dict, result: Dict):
    """Log remediation action to DynamoDB"""
    try:
        remediation_table.put_item(
            Item={
                'remediation_id': f"{finding['Id']}-{int(datetime.now().timestamp())}",
                'finding_id': finding['Id'],
                'timestamp': int(datetime.now().timestamp()),
                'status': result['status'],
                'actions': result.get('actions', []),
                'resource': result.get('resource', 'Unknown'),
                'reason': result.get('reason', '')
            }
        )
    except Exception as e:
        logger.error(f"Failed to log remediation: {str(e)}")


def update_securityhub_finding(finding_id: str, status: str):
    """Update Security Hub finding status"""
    try:
        securityhub.batch_update_findings(
            FindingIdentifiers=[{
                'Id': finding_id,
                'ProductArn': finding_id.split('/')[0]
            }],
            Workflow={'Status': status}
        )
    except Exception as e:
        logger.error(f"Failed to update Security Hub finding: {str(e)}")


def send_summary_notification(results: Dict):
    """Send remediation summary via SNS"""
    try:
        message = f"""
AWS Security Audit - Auto-Remediation Summary

Total Findings: {results['total_findings']}
Remediated: {results['remediated']}
Skipped: {results['skipped']}
Failed: {results['failed']}

Timestamp: {datetime.now().isoformat()}
"""

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='AWS Security Auto-Remediation Summary',
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")


def send_error_notification(error: str):
    """Send error notification"""
    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='AWS Security Auto-Remediation ERROR',
            Message=f"Auto-remediation error: {error}\n\nTimestamp: {datetime.now().isoformat()}"
        )
    except Exception as e:
        logger.error(f"Failed to send error notification: {str(e)}")


def send_key_rotation_notification(user_name: str, key_id: str):
    """Send notification to rotate access key"""
    try:
        message = f"""
IAM Access Key Rotation Required

User: {user_name}
Access Key: {key_id}

Your access key has been deactivated due to age (>90 days).
Please rotate your access key and update applications.

1. Create new access key in IAM console
2. Update applications with new key
3. Delete old access key

Contact security team if you need assistance.
"""

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'IAM Access Key Rotation Required: {user_name}',
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send key rotation notification: {str(e)}")
