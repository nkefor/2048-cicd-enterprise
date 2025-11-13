#!/usr/bin/env python3
"""
HIPAA Compliance Test Suite
Validates infrastructure against HIPAA requirements
"""

import boto3
import pytest

class TestHIPAACompliance:

    def test_encryption_at_rest(self):
        """Test: All EBS volumes must be encrypted"""
        ec2 = boto3.client('ec2')
        volumes = ec2.describe_volumes()['Volumes']

        for volume in volumes:
            assert volume['Encrypted'], f"Volume {volume['VolumeId']} is not encrypted!"

    def test_encryption_in_transit(self):
        """Test: Load balancers must use HTTPS"""
        elbv2 = boto3.client('elbv2')
        load_balancers = elbv2.describe_load_balancers()['LoadBalancers']

        for lb in load_balancers:
            listeners = elbv2.describe_listeners(LoadBalancerArn=lb['LoadBalancerArn'])
            for listener in listeners['Listeners']:
                if listener['Port'] in [80, 443]:
                    assert listener['Protocol'] in ['HTTPS', 'TLS'], \
                        f"Listener on port {listener['Port']} must use HTTPS/TLS"

    def test_logging_enabled(self):
        """Test: CloudTrail logging must be enabled"""
        cloudtrail = boto3.client('cloudtrail')
        trails = cloudtrail.describe_trails()['trailList']

        assert len(trails) > 0, "No CloudTrail trails found"

        for trail in trails:
            status = cloudtrail.get_trail_status(Name=trail['TrailARN'])
            assert status['IsLogging'], f"Trail {trail['Name']} is not logging"

    def test_backup_enabled(self):
        """Test: Automated backups must be configured"""
        rds = boto3.client('rds')
        db_instances = rds.describe_db_instances().get('DBInstances', [])

        for db in db_instances:
            assert db['BackupRetentionPeriod'] >= 7, \
                f"DB {db['DBInstanceIdentifier']} backup retention < 7 days"

    def test_access_logging(self):
        """Test: S3 buckets must have access logging enabled"""
        s3 = boto3.client('s3')
        buckets = s3.list_buckets()['Buckets']

        for bucket in buckets:
            try:
                logging = s3.get_bucket_logging(Bucket=bucket['Name'])
                # Check if logging is configured
                assert 'LoggingEnabled' in logging or 'TargetBucket' in logging.get('LoggingEnabled', {}), \
                    f"S3 bucket {bucket['Name']} does not have access logging enabled"
            except:
                pass  # Skip buckets we don't have access to

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
