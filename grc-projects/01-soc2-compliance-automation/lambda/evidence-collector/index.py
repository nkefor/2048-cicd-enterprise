"""
SOC 2 Compliance Evidence Collector
Automated evidence collection for SOC 2 compliance monitoring
"""
import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any

# AWS Clients
iam = boto3.client('iam')
cloudtrail = boto3.client('cloudtrail')
config = boto3.client('config')
ec2 = boto3.client('ec2')
s3_client = boto3.client('s3')
rds = boto3.client('rds')
kms = boto3.client('kms')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
EVIDENCE_BUCKET = os.environ['EVIDENCE_BUCKET']
EVIDENCE_TABLE = os.environ['EVIDENCE_TABLE']
CONTROL_STATUS_TABLE = os.environ['CONTROL_STATUS_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

# DynamoDB tables
evidence_table = dynamodb.Table(EVIDENCE_TABLE)
control_table = dynamodb.Table(CONTROL_STATUS_TABLE)


def handler(event, context):
    """Main Lambda handler for evidence collection"""
    print(f"Starting evidence collection: {json.dumps(event)}")

    scan_type = event.get('scan_type', 'incremental')
    timestamp = int(datetime.utcnow().timestamp())

    evidence_collected = []
    failed_controls = []

    try:
        # SOC 2 Security Controls (CC6.1 - CC7.5)
        evidence_collected.extend(collect_iam_evidence(timestamp))
        evidence_collected.extend(collect_cloudtrail_evidence(timestamp))
        evidence_collected.extend(collect_encryption_evidence(timestamp))
        evidence_collected.extend(collect_network_security_evidence(timestamp))
        evidence_collected.extend(collect_backup_evidence(timestamp))

        # Store evidence in DynamoDB and S3
        store_evidence(evidence_collected, timestamp)

        # Calculate compliance score
        compliance_score = calculate_compliance_score(evidence_collected)

        # Publish metrics
        publish_metrics(compliance_score, evidence_collected)

        # Send alerts if needed
        if compliance_score < int(os.environ.get('COMPLIANCE_THRESHOLD', 85)):
            send_alert(compliance_score, failed_controls)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Evidence collection completed',
                'evidence_count': len(evidence_collected),
                'compliance_score': compliance_score,
                'timestamp': timestamp
            })
        }

    except Exception as e:
        print(f"Error collecting evidence: {str(e)}")
        raise


def collect_iam_evidence(timestamp: int) -> List[Dict]:
    """Collect IAM-related evidence (CC6.1, CC6.2)"""
    evidence = []

    try:
        # Check password policy
        password_policy = iam.get_account_password_policy()
        evidence.append({
            'control_id': 'CC6.1',
            'control_name': 'Password Policy Enforcement',
            'trust_principle': 'security',
            'evidence_type': 'password_policy',
            'timestamp': timestamp,
            'data': password_policy['PasswordPolicy'],
            'compliance_status': 'COMPLIANT' if validate_password_policy(password_policy) else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)  # 1 year TTL
        })

        # Check MFA for root account
        summary = iam.get_account_summary()
        root_mfa_enabled = summary['SummaryMap'].get('AccountMFAEnabled', 0) == 1
        evidence.append({
            'control_id': 'CC6.1',
            'control_name': 'Root Account MFA',
            'trust_principle': 'security',
            'evidence_type': 'mfa_status',
            'timestamp': timestamp,
            'data': {'root_mfa_enabled': root_mfa_enabled},
            'compliance_status': 'COMPLIANT' if root_mfa_enabled else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check for users with console access but no MFA
        users = iam.list_users()['Users']
        users_without_mfa = []
        for user in users:
            try:
                login_profile = iam.get_login_profile(UserName=user['UserName'])
                mfa_devices = iam.list_mfa_devices(UserName=user['UserName'])
                if len(mfa_devices['MFADevices']) == 0:
                    users_without_mfa.append(user['UserName'])
            except iam.exceptions.NoSuchEntityException:
                continue

        evidence.append({
            'control_id': 'CC6.1',
            'control_name': 'User MFA Enforcement',
            'trust_principle': 'security',
            'evidence_type': 'user_mfa',
            'timestamp': timestamp,
            'data': {
                'total_users': len(users),
                'users_without_mfa': users_without_mfa,
                'count': len(users_without_mfa)
            },
            'compliance_status': 'COMPLIANT' if len(users_without_mfa) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check for access keys older than 90 days
        old_access_keys = []
        for user in users:
            access_keys = iam.list_access_keys(UserName=user['UserName'])
            for key in access_keys['AccessKeyMetadata']:
                age_days = (datetime.now(key['CreateDate'].tzinfo) - key['CreateDate']).days
                if age_days > 90:
                    old_access_keys.append({
                        'user': user['UserName'],
                        'key_id': key['AccessKeyId'],
                        'age_days': age_days
                    })

        evidence.append({
            'control_id': 'CC6.2',
            'control_name': 'Access Key Rotation',
            'trust_principle': 'security',
            'evidence_type': 'access_key_rotation',
            'timestamp': timestamp,
            'data': {
                'old_keys': old_access_keys,
                'count': len(old_access_keys)
            },
            'compliance_status': 'COMPLIANT' if len(old_access_keys) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

    except Exception as e:
        print(f"Error collecting IAM evidence: {str(e)}")

    return evidence


def collect_cloudtrail_evidence(timestamp: int) -> List[Dict]:
    """Collect CloudTrail logging evidence (CC7.2)"""
    evidence = []

    try:
        trails = cloudtrail.describe_trails()['trailList']

        for trail in trails:
            trail_status = cloudtrail.get_trail_status(Name=trail['TrailARN'])

            # Check if trail is logging
            is_logging = trail_status['IsLogging']

            # Check if multi-region
            is_multi_region = trail.get('IsMultiRegionTrail', False)

            # Check log file validation
            log_file_validation = trail.get('LogFileValidationEnabled', False)

            evidence.append({
                'control_id': 'CC7.2',
                'control_name': 'Audit Logging',
                'trust_principle': 'security',
                'evidence_type': 'cloudtrail',
                'timestamp': timestamp,
                'data': {
                    'trail_name': trail['Name'],
                    'is_logging': is_logging,
                    'is_multi_region': is_multi_region,
                    'log_file_validation': log_file_validation,
                    's3_bucket': trail.get('S3BucketName', 'N/A')
                },
                'compliance_status': 'COMPLIANT' if (is_logging and is_multi_region and log_file_validation) else 'NON_COMPLIANT',
                'ttl': timestamp + (365 * 24 * 60 * 60)
            })

        if len(trails) == 0:
            evidence.append({
                'control_id': 'CC7.2',
                'control_name': 'Audit Logging',
                'trust_principle': 'security',
                'evidence_type': 'cloudtrail',
                'timestamp': timestamp,
                'data': {'error': 'No CloudTrail trails found'},
                'compliance_status': 'NON_COMPLIANT',
                'ttl': timestamp + (365 * 24 * 60 * 60)
            })

    except Exception as e:
        print(f"Error collecting CloudTrail evidence: {str(e)}")

    return evidence


def collect_encryption_evidence(timestamp: int) -> List[Dict]:
    """Collect encryption evidence (CC6.7)"""
    evidence = []

    try:
        # Check EBS encryption
        volumes = ec2.describe_volumes()['Volumes']
        unencrypted_volumes = [v['VolumeId'] for v in volumes if not v.get('Encrypted', False)]

        evidence.append({
            'control_id': 'CC6.7',
            'control_name': 'Data Encryption at Rest - EBS',
            'trust_principle': 'confidentiality',
            'evidence_type': 'ebs_encryption',
            'timestamp': timestamp,
            'data': {
                'total_volumes': len(volumes),
                'encrypted_volumes': len(volumes) - len(unencrypted_volumes),
                'unencrypted_volumes': unencrypted_volumes
            },
            'compliance_status': 'COMPLIANT' if len(unencrypted_volumes) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check S3 bucket encryption
        buckets = s3_client.list_buckets()['Buckets']
        unencrypted_buckets = []
        for bucket in buckets:
            try:
                s3_client.get_bucket_encryption(Bucket=bucket['Name'])
            except s3_client.exceptions.ServerSideEncryptionConfigurationNotFoundError:
                unencrypted_buckets.append(bucket['Name'])

        evidence.append({
            'control_id': 'CC6.7',
            'control_name': 'Data Encryption at Rest - S3',
            'trust_principle': 'confidentiality',
            'evidence_type': 's3_encryption',
            'timestamp': timestamp,
            'data': {
                'total_buckets': len(buckets),
                'encrypted_buckets': len(buckets) - len(unencrypted_buckets),
                'unencrypted_buckets': unencrypted_buckets
            },
            'compliance_status': 'COMPLIANT' if len(unencrypted_buckets) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check RDS encryption
        db_instances = rds.describe_db_instances()['DBInstances']
        unencrypted_dbs = [db['DBInstanceIdentifier'] for db in db_instances if not db.get('StorageEncrypted', False)]

        evidence.append({
            'control_id': 'CC6.7',
            'control_name': 'Data Encryption at Rest - RDS',
            'trust_principle': 'confidentiality',
            'evidence_type': 'rds_encryption',
            'timestamp': timestamp,
            'data': {
                'total_instances': len(db_instances),
                'encrypted_instances': len(db_instances) - len(unencrypted_dbs),
                'unencrypted_instances': unencrypted_dbs
            },
            'compliance_status': 'COMPLIANT' if len(unencrypted_dbs) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check KMS key rotation
        keys = kms.list_keys()['Keys']
        keys_without_rotation = []
        for key in keys:
            try:
                rotation_status = kms.get_key_rotation_status(KeyId=key['KeyId'])
                if not rotation_status.get('KeyRotationEnabled', False):
                    keys_without_rotation.append(key['KeyId'])
            except Exception:
                continue

        evidence.append({
            'control_id': 'CC6.7',
            'control_name': 'KMS Key Rotation',
            'trust_principle': 'confidentiality',
            'evidence_type': 'kms_rotation',
            'timestamp': timestamp,
            'data': {
                'total_keys': len(keys),
                'keys_with_rotation': len(keys) - len(keys_without_rotation),
                'keys_without_rotation': keys_without_rotation
            },
            'compliance_status': 'COMPLIANT' if len(keys_without_rotation) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

    except Exception as e:
        print(f"Error collecting encryption evidence: {str(e)}")

    return evidence


def collect_network_security_evidence(timestamp: int) -> List[Dict]:
    """Collect network security evidence (CC6.6)"""
    evidence = []

    try:
        # Check for security groups with 0.0.0.0/0 access
        security_groups = ec2.describe_security_groups()['SecurityGroups']
        overly_permissive_sgs = []

        for sg in security_groups:
            for permission in sg.get('IpPermissions', []):
                for ip_range in permission.get('IpRanges', []):
                    if ip_range.get('CidrIp') == '0.0.0.0/0':
                        overly_permissive_sgs.append({
                            'sg_id': sg['GroupId'],
                            'sg_name': sg['GroupName'],
                            'port': permission.get('FromPort', 'all'),
                            'protocol': permission.get('IpProtocol', 'all')
                        })

        evidence.append({
            'control_id': 'CC6.6',
            'control_name': 'Network Security - Open Security Groups',
            'trust_principle': 'security',
            'evidence_type': 'security_groups',
            'timestamp': timestamp,
            'data': {
                'total_security_groups': len(security_groups),
                'overly_permissive': overly_permissive_sgs,
                'count': len(overly_permissive_sgs)
            },
            'compliance_status': 'COMPLIANT' if len(overly_permissive_sgs) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

        # Check VPC Flow Logs
        vpcs = ec2.describe_vpcs()['Vpcs']
        flow_logs = ec2.describe_flow_logs()['FlowLogs']
        flow_log_vpc_ids = {fl['ResourceId'] for fl in flow_logs}
        vpcs_without_flow_logs = [vpc['VpcId'] for vpc in vpcs if vpc['VpcId'] not in flow_log_vpc_ids]

        evidence.append({
            'control_id': 'CC6.6',
            'control_name': 'Network Security - VPC Flow Logs',
            'trust_principle': 'security',
            'evidence_type': 'vpc_flow_logs',
            'timestamp': timestamp,
            'data': {
                'total_vpcs': len(vpcs),
                'vpcs_with_flow_logs': len(vpcs) - len(vpcs_without_flow_logs),
                'vpcs_without_flow_logs': vpcs_without_flow_logs
            },
            'compliance_status': 'COMPLIANT' if len(vpcs_without_flow_logs) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

    except Exception as e:
        print(f"Error collecting network security evidence: {str(e)}")

    return evidence


def collect_backup_evidence(timestamp: int) -> List[Dict]:
    """Collect backup and disaster recovery evidence (A1.2)"""
    evidence = []

    try:
        # Check RDS automated backups
        db_instances = rds.describe_db_instances()['DBInstances']
        dbs_without_backups = []

        for db in db_instances:
            if db.get('BackupRetentionPeriod', 0) == 0:
                dbs_without_backups.append(db['DBInstanceIdentifier'])

        evidence.append({
            'control_id': 'A1.2',
            'control_name': 'Availability - Database Backups',
            'trust_principle': 'availability',
            'evidence_type': 'rds_backups',
            'timestamp': timestamp,
            'data': {
                'total_instances': len(db_instances),
                'instances_with_backups': len(db_instances) - len(dbs_without_backups),
                'instances_without_backups': dbs_without_backups
            },
            'compliance_status': 'COMPLIANT' if len(dbs_without_backups) == 0 else 'NON_COMPLIANT',
            'ttl': timestamp + (365 * 24 * 60 * 60)
        })

    except Exception as e:
        print(f"Error collecting backup evidence: {str(e)}")

    return evidence


def validate_password_policy(policy_response: Dict) -> bool:
    """Validate password policy meets SOC 2 requirements"""
    policy = policy_response.get('PasswordPolicy', {})

    return (
        policy.get('MinimumPasswordLength', 0) >= 14 and
        policy.get('RequireUppercaseCharacters', False) and
        policy.get('RequireLowercaseCharacters', False) and
        policy.get('RequireNumbers', False) and
        policy.get('RequireSymbols', False) and
        policy.get('MaxPasswordAge', 999) <= 90 and
        policy.get('PasswordReusePrevention', 0) >= 12
    )


def store_evidence(evidence_list: List[Dict], timestamp: int):
    """Store evidence in DynamoDB and S3"""
    # Batch write to DynamoDB
    with evidence_table.batch_writer() as batch:
        for evidence in evidence_list:
            batch.put_item(Item=evidence)

    # Store aggregated evidence in S3
    s3_key = f"evidence/{datetime.utcfromtimestamp(timestamp).strftime('%Y/%m/%d')}/{timestamp}.json"
    s3_client.put_object(
        Bucket=EVIDENCE_BUCKET,
        Key=s3_key,
        Body=json.dumps(evidence_list, default=str),
        ServerSideEncryption='aws:kms'
    )

    print(f"Stored {len(evidence_list)} evidence items in DynamoDB and S3")


def calculate_compliance_score(evidence_list: List[Dict]) -> float:
    """Calculate overall compliance score"""
    if not evidence_list:
        return 0.0

    compliant_count = sum(1 for e in evidence_list if e['compliance_status'] == 'COMPLIANT')
    total_count = len(evidence_list)

    score = (compliant_count / total_count) * 100
    return round(score, 2)


def publish_metrics(compliance_score: float, evidence_list: List[Dict]):
    """Publish compliance metrics to CloudWatch"""
    cloudwatch.put_metric_data(
        Namespace='SOC2/Compliance',
        MetricData=[
            {
                'MetricName': 'ComplianceScore',
                'Value': compliance_score,
                'Unit': 'Percent'
            },
            {
                'MetricName': 'EvidenceCollected',
                'Value': len(evidence_list),
                'Unit': 'Count'
            },
            {
                'MetricName': 'CompliantControls',
                'Value': sum(1 for e in evidence_list if e['compliance_status'] == 'COMPLIANT'),
                'Unit': 'Count'
            },
            {
                'MetricName': 'NonCompliantControls',
                'Value': sum(1 for e in evidence_list if e['compliance_status'] == 'NON_COMPLIANT'),
                'Unit': 'Count'
            }
        ]
    )


def send_alert(compliance_score: float, failed_controls: List[str]):
    """Send SNS alert for low compliance score"""
    message = f"""
    SOC 2 Compliance Alert

    Compliance Score: {compliance_score}%
    Status: BELOW THRESHOLD

    Failed Controls: {len(failed_controls)}

    Action Required: Review compliance dashboard and remediate findings.
    """

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject='SOC 2 Compliance Alert - Low Score',
        Message=message
    )
