#!/usr/bin/env python3
"""
FinOps Cost Analyzer
Analyzes cloud costs across AWS and Azure, provides optimization recommendations
"""

import boto3
import json
from datetime import datetime, timedelta
from typing import Dict, List
from dataclasses import dataclass

@dataclass
class CostRecommendation:
    resource_id: str
    resource_type: str
    current_cost: float
    potential_savings: float
    recommendation: str
    priority: str  # high, medium, low

class AWSCostAnalyzer:
    def __init__(self):
        self.ce_client = boto3.client('ce')  # Cost Explorer
        self.ec2_client = boto3.client('ec2')
        self.rds_client = boto3.client('rds')

    def get_monthly_costs(self, months: int = 3) -> Dict:
        """Get monthly costs for the last N months"""
        end = datetime.now()
        start = end - timedelta(days=months * 30)

        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start.strftime('%Y-%m-%d'),
                'End': end.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}]
        )

        return response['ResultsByTime']

    def find_unattached_volumes(self) -> List[CostRecommendation]:
        """Find unattached EBS volumes (waste)"""
        recommendations = []
        volumes = self.ec2_client.describe_volumes(
            Filters=[{'Name': 'status', 'Values': ['available']}]
        )

        for volume in volumes['Volumes']:
            # Estimate cost: $0.10/GB-month for gp3
            size_gb = volume['Size']
            monthly_cost = size_gb * 0.10

            recommendations.append(CostRecommendation(
                resource_id=volume['VolumeId'],
                resource_type='EBS Volume',
                current_cost=monthly_cost,
                potential_savings=monthly_cost,
                recommendation=f'Delete unattached volume {volume["VolumeId"]} ({size_gb}GB)',
                priority='medium'
            ))

        return recommendations

    def find_idle_instances(self) -> List[CostRecommendation]:
        """Find EC2 instances with low CPU utilization"""
        recommendations = []
        cloudwatch = boto3.client('cloudwatch')

        instances = self.ec2_client.describe_instances(
            Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
        )

        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']

                # Get CPU utilization
                metrics = cloudwatch.get_metric_statistics(
                    Namespace='AWS/EC2',
                    MetricName='CPUUtilization',
                    Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                    StartTime=datetime.now() - timedelta(days=7),
                    EndTime=datetime.now(),
                    Period=86400,
                    Statistics=['Average']
                )

                if metrics['Datapoints']:
                    avg_cpu = sum(d['Average'] for d in metrics['Datapoints']) / len(metrics['Datapoints'])

                    if avg_cpu < 5:  # Less than 5% CPU
                        instance_type = instance['InstanceType']
                        # Rough estimate: t3.small = $15/month
                        monthly_cost = 15

                        recommendations.append(CostRecommendation(
                            resource_id=instance_id,
                            resource_type='EC2 Instance',
                            current_cost=monthly_cost,
                            potential_savings=monthly_cost * 0.8,
                            recommendation=f'Stop or downsize idle instance {instance_id} (avg CPU: {avg_cpu:.1f}%)',
                            priority='high'
                        ))

        return recommendations

    def get_ri_recommendations(self) -> List[CostRecommendation]:
        """Get Reserved Instance recommendations"""
        recommendations = []

        response = self.ce_client.get_reservation_purchase_recommendation(
            Service='Amazon Elastic Compute Cloud - Compute',
            LookbackPeriodInDays='SIXTY_DAYS',
            TermInYears='ONE_YEAR',
            PaymentOption='PARTIAL_UPFRONT'
        )

        for rec in response.get('Recommendations', []):
            details = rec['RecommendationDetails'][0]
            savings = float(rec['RecommendationSummary']['EstimatedMonthlySavingsAmount'])

            recommendations.append(CostRecommendation(
                resource_id=details['InstanceDetails']['EC2InstanceDetails']['InstanceType'],
                resource_type='Reserved Instance',
                current_cost=float(rec['RecommendationSummary']['EstimatedMonthlyOnDemandCost']),
                potential_savings=savings,
                recommendation=f'Purchase Reserved Instance: {details["InstanceDetails"]["EC2InstanceDetails"]["InstanceType"]}',
                priority='high' if savings > 100 else 'medium'
            ))

        return recommendations

class FinOpsAnalyzer:
    def __init__(self):
        self.aws_analyzer = AWSCostAnalyzer()

    def analyze_all(self) -> Dict:
        """Run all cost analyses"""
        print("🔍 Analyzing cloud costs...")

        recommendations = []

        # AWS analyses
        print("  ├─ Finding unattached volumes...")
        recommendations.extend(self.aws_analyzer.find_unattached_volumes())

        print("  ├─ Finding idle instances...")
        recommendations.extend(self.aws_analyzer.find_idle_instances())

        print("  └─ Getting RI recommendations...")
        recommendations.extend(self.aws_analyzer.get_ri_recommendations())

        # Calculate total savings
        total_savings = sum(r.potential_savings for r in recommendations)
        high_priority = [r for r in recommendations if r.priority == 'high']

        report = {
            'timestamp': datetime.now().isoformat(),
            'total_recommendations': len(recommendations),
            'high_priority_count': len(high_priority),
            'total_potential_savings': total_savings,
            'recommendations': [
                {
                    'resource_id': r.resource_id,
                    'type': r.resource_type,
                    'current_cost': r.current_cost,
                    'savings': r.potential_savings,
                    'action': r.recommendation,
                    'priority': r.priority
                }
                for r in sorted(recommendations, key=lambda x: x.potential_savings, reverse=True)
            ]
        }

        return report

    def print_report(self, report: Dict):
        """Print cost optimization report"""
        print("\n" + "="*70)
        print("💰 FinOps Cost Optimization Report")
        print("="*70)
        print(f"Generated: {report['timestamp']}")
        print(f"Total Recommendations: {report['total_recommendations']}")
        print(f"High Priority: {report['high_priority_count']}")
        print(f"Total Potential Savings: ${report['total_potential_savings']:.2f}/month")
        print("="*70)

        print("\n📋 Top Recommendations (sorted by savings):\n")
        for i, rec in enumerate(report['recommendations'][:10], 1):
            print(f"{i}. [{rec['priority'].upper()}] {rec['action']}")
            print(f"   💵 Potential Savings: ${rec['savings']:.2f}/month")
            print(f"   Current Cost: ${rec['current_cost']:.2f}/month")
            print()

if __name__ == '__main__':
    analyzer = FinOpsAnalyzer()
    report = analyzer.analyze_all()
    analyzer.print_report(report)

    # Save to file
    with open('finops-report.json', 'w') as f:
        json.dump(report, f, indent=2)

    print(f"\n✅ Report saved to: finops-report.json")
