#!/usr/bin/env python3
"""
Automated Rightsizing Script
Automatically resize resources based on utilization metrics
"""

import boto3
from datetime import datetime, timedelta

class AutoRightSizer:
    def __init__(self, dry_run=True):
        self.ec2 = boto3.client('ec2')
        self.cloudwatch = boto3.client('cloudwatch')
        self.dry_run = dry_run

    def get_instance_metrics(self, instance_id: str, days: int = 7) -> dict:
        """Get CPU and memory metrics for an instance"""
        end_time = datetime.now()
        start_time = end_time - timedelta(days=days)

        cpu_metrics = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )

        cpu_avg = sum(d['Average'] for d in cpu_metrics['Datapoints']) / len(cpu_metrics['Datapoints']) if cpu_metrics['Datapoints'] else 0
        cpu_max = max((d['Maximum'] for d in cpu_metrics['Datapoints']), default=0)

        return {'cpu_avg': cpu_avg, 'cpu_max': cpu_max}

    def recommend_instance_type(self, current_type: str, cpu_avg: float) -> str:
        """Recommend instance type based on usage"""
        # Simple downsize recommendations
        if cpu_avg < 10:
            return 't3.micro'
        elif cpu_avg < 30:
            return 't3.small'
        elif cpu_avg < 50:
            return 't3.medium'
        else:
            return current_type

    def rightsize_instance(self, instance_id: str):
        """Rightsize a single instance"""
        instance = self.ec2.describe_instances(InstanceIds=[instance_id])['Reservations'][0]['Instances'][0]
        current_type = instance['InstanceType']

        metrics = self.get_instance_metrics(instance_id)
        recommended_type = self.recommend_instance_type(current_type, metrics['cpu_avg'])

        if recommended_type != current_type:
            print(f"Instance {instance_id}: {current_type} → {recommended_type} (CPU avg: {metrics['cpu_avg']:.1f}%)")

            if not self.dry_run:
                # Stop instance, modify type, start instance
                self.ec2.stop_instances(InstanceIds=[instance_id])
                self.ec2.get_waiter('instance_stopped').wait(InstanceIds=[instance_id])
                self.ec2.modify_instance_attribute(InstanceId=instance_id, InstanceType={'Value': recommended_type})
                self.ec2.start_instances(InstanceIds=[instance_id])
                print(f"✅ Resized {instance_id}")
            else:
                print(f"[DRY RUN] Would resize {instance_id}")

if __name__ == '__main__':
    # Run in dry-run mode by default
    rightsizer = AutoRightSizer(dry_run=True)
    print("Running auto-rightsizing analysis (dry-run mode)...")
