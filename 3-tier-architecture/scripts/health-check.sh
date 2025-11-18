#!/bin/bash
#
# Health Check Script - Validates entire infrastructure
#
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"

print_status() {
    local status=$1
    local message=$2
    if [ "$status" == "ok" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" == "warning" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get Terraform outputs
cd "$TERRAFORM_DIR"
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: No Terraform state found${NC}"
    exit 1
fi

ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
DB_ENDPOINT=$(terraform output -raw db_endpoint 2>/dev/null || echo "")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")

print_header "Infrastructure Health Check"
echo "Timestamp: $(date)"
echo ""

# 1. VPC Health
print_header "1. VPC & Networking"
if [ -n "$VPC_ID" ]; then
    VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].State' --output text 2>/dev/null || echo "unknown")
    if [ "$VPC_STATE" == "available" ]; then
        print_status "ok" "VPC is available ($VPC_ID)"
    else
        print_status "error" "VPC state: $VPC_STATE"
    fi

    # Check NAT Gateways
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'length(NatGateways)' --output text 2>/dev/null || echo "0")
    if [ "$NAT_COUNT" -gt 0 ]; then
        print_status "ok" "NAT Gateways: $NAT_COUNT available"
    else
        print_status "warning" "No NAT Gateways found"
    fi
else
    print_status "error" "VPC ID not found"
fi

# 2. Load Balancer Health
print_header "2. Application Load Balancer"
if [ -n "$ALB_DNS" ]; then
    print_status "ok" "ALB DNS: $ALB_DNS"

    # Check ALB response
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS" || echo "000")
    if [ "$HTTP_CODE" == "200" ]; then
        print_status "ok" "ALB responding (HTTP $HTTP_CODE)"
    else
        print_status "warning" "ALB response code: $HTTP_CODE"
    fi

    # Check response time
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "http://$ALB_DNS" || echo "0")
    RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
    if (( $(echo "$RESPONSE_TIME < 2" | bc -l) )); then
        print_status "ok" "Response time: ${RESPONSE_MS}ms"
    else
        print_status "warning" "Response time: ${RESPONSE_MS}ms (slow)"
    fi

    # Check target health
    ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || echo "")
    if [ -n "$ALB_ARN" ]; then
        TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
        if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
            HEALTHY_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text 2>/dev/null || echo "0")
            TOTAL_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'length(TargetHealthDescriptions)' --output text 2>/dev/null || echo "0")

            if [ "$HEALTHY_TARGETS" -gt 0 ]; then
                print_status "ok" "Healthy targets: $HEALTHY_TARGETS/$TOTAL_TARGETS"
            else
                print_status "error" "No healthy targets ($TOTAL_TARGETS registered)"
            fi
        fi
    fi
else
    print_status "error" "ALB DNS not found"
fi

# 3. Auto Scaling Group
print_header "3. Auto Scaling Group"
if [ -n "$ASG_NAME" ]; then
    ASG_INFO=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" 2>/dev/null || echo "")

    if [ -n "$ASG_INFO" ]; then
        DESIRED=$(echo "$ASG_INFO" | jq -r '.AutoScalingGroups[0].DesiredCapacity')
        MIN=$(echo "$ASG_INFO" | jq -r '.AutoScalingGroups[0].MinSize')
        MAX=$(echo "$ASG_INFO" | jq -r '.AutoScalingGroups[0].MaxSize')
        INSTANCES=$(echo "$ASG_INFO" | jq -r '.AutoScalingGroups[0].Instances | length')
        HEALTHY=$(echo "$ASG_INFO" | jq -r '[.AutoScalingGroups[0].Instances[] | select(.HealthStatus=="Healthy")] | length')

        print_status "ok" "Capacity: Min=$MIN, Desired=$DESIRED, Max=$MAX"
        if [ "$HEALTHY" == "$DESIRED" ]; then
            print_status "ok" "Healthy instances: $HEALTHY/$INSTANCES"
        else
            print_status "warning" "Healthy instances: $HEALTHY/$INSTANCES (desired: $DESIRED)"
        fi

        # Check instance distribution across AZs
        AZS=$(echo "$ASG_INFO" | jq -r '[.AutoScalingGroups[0].Instances[].AvailabilityZone] | unique | length')
        if [ "$AZS" -ge 2 ]; then
            print_status "ok" "Multi-AZ deployment: $AZS zones"
        else
            print_status "warning" "Single AZ deployment"
        fi
    fi
else
    print_status "error" "ASG name not found"
fi

# 4. Database Health
print_header "4. RDS Database"
if [ -n "$DB_ENDPOINT" ]; then
    DB_ID=$(echo "$DB_ENDPOINT" | cut -d'.' -f1)
    DB_INFO=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" 2>/dev/null || echo "")

    if [ -n "$DB_INFO" ]; then
        DB_STATUS=$(echo "$DB_INFO" | jq -r '.DBInstances[0].DBInstanceStatus')
        if [ "$DB_STATUS" == "available" ]; then
            print_status "ok" "Database status: $DB_STATUS"
        else
            print_status "warning" "Database status: $DB_STATUS"
        fi

        MULTI_AZ=$(echo "$DB_INFO" | jq -r '.DBInstances[0].MultiAZ')
        if [ "$MULTI_AZ" == "true" ]; then
            print_status "ok" "Multi-AZ: enabled"
        else
            print_status "warning" "Multi-AZ: disabled"
        fi

        BACKUP_RETENTION=$(echo "$DB_INFO" | jq -r '.DBInstances[0].BackupRetentionPeriod')
        if [ "$BACKUP_RETENTION" -ge 7 ]; then
            print_status "ok" "Backup retention: $BACKUP_RETENTION days"
        else
            print_status "warning" "Backup retention: $BACKUP_RETENTION days (< 7)"
        fi

        ENCRYPTED=$(echo "$DB_INFO" | jq -r '.DBInstances[0].StorageEncrypted')
        if [ "$ENCRYPTED" == "true" ]; then
            print_status "ok" "Encryption: enabled"
        else
            print_status "error" "Encryption: disabled"
        fi
    fi
else
    print_status "error" "Database endpoint not found"
fi

# 5. Bastion Host
print_header "5. Bastion Host"
if [ -n "$BASTION_IP" ]; then
    print_status "ok" "Bastion IP: $BASTION_IP"

    # Try to ping bastion
    if ping -c 1 -W 2 "$BASTION_IP" >/dev/null 2>&1; then
        print_status "ok" "Bastion is reachable"
    else
        print_status "warning" "Bastion ping failed (ICMP may be blocked)"
    fi
else
    print_status "error" "Bastion IP not found"
fi

# 6. CloudWatch Alarms
print_header "6. CloudWatch Alarms"
ALARM_COUNT=$(aws cloudwatch describe-alarms --query 'length(MetricAlarms)' --output text 2>/dev/null || echo "0")
print_status "ok" "Total alarms: $ALARM_COUNT"

if [ "$ALARM_COUNT" -gt 0 ]; then
    ALARM_STATE=$(aws cloudwatch describe-alarms --state-value ALARM --query 'length(MetricAlarms)' --output text 2>/dev/null || echo "0")
    if [ "$ALARM_STATE" -eq 0 ]; then
        print_status "ok" "Alarms in ALARM state: 0"
    else
        print_status "warning" "Alarms in ALARM state: $ALARM_STATE"

        # List alarms in ALARM state
        aws cloudwatch describe-alarms --state-value ALARM --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null | tr '\t' '\n' | while read alarm; do
            echo "  - $alarm"
        done
    fi
fi

# 7. Security Groups
print_header "7. Security Groups"
if [ -n "$VPC_ID" ]; then
    SG_COUNT=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "0")
    print_status "ok" "Security groups: $SG_COUNT"

    # Check for overly permissive rules
    OPEN_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].GroupId' --output text 2>/dev/null | wc -w)
    if [ "$OPEN_SG" -gt 1 ]; then
        print_status "warning" "$OPEN_SG security groups allow 0.0.0.0/0"
    else
        print_status "ok" "No overly permissive security groups (only ALB)"
    fi
fi

# 8. Cost Estimate
print_header "8. Current Month Cost Estimate"
START_DATE=$(date -u -d "$(date +%Y-%m-01)" +%Y-%m-%d)
END_DATE=$(date -u +%Y-%m-%d)

COST=$(aws ce get-cost-and-usage \
    --time-period Start="$START_DATE",End="$END_DATE" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --filter file:/dev/stdin 2>/dev/null <<EOF | jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount' || echo "0"
{
  "Tags": {
    "Key": "Project",
    "Values": ["3-Tier-Architecture"]
  }
}
EOF
)

COST_FORMATTED=$(printf "%.2f" "$COST")
print_status "ok" "Current month cost: \$$COST_FORMATTED USD"

# Summary
print_header "Health Check Summary"
echo ""
echo "Overall Status: Infrastructure is operational"
echo ""
echo "Quick Access:"
echo "  Application: http://$ALB_DNS"
echo "  Bastion SSH: ssh -i ~/.ssh/your-key.pem ec2-user@$BASTION_IP"
echo ""
echo "Next Steps:"
echo "  - Monitor CloudWatch dashboards"
echo "  - Review any warnings above"
echo "  - Run './scripts/deploy.sh outputs' for full details"
echo ""
