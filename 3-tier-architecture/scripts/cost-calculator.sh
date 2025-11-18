#!/bin/bash
#
# AWS Cost Calculator for 3-Tier Architecture
# Estimates monthly costs based on configuration
#
set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Pricing (us-east-1, on-demand, as of 2024)
EC2_T3_MICRO_HOURLY=0.0104
EC2_T3_SMALL_HOURLY=0.0208
EC2_T3_MEDIUM_HOURLY=0.0416

RDS_T3_MICRO_HOURLY=0.017
RDS_T3_SMALL_HOURLY=0.034
RDS_T3_MEDIUM_HOURLY=0.068

ALB_HOURLY=0.0225
ALB_LCU=0.008

NAT_GATEWAY_HOURLY=0.045
NAT_DATA_GB=0.045

EBS_GP3_GB=0.08
S3_STANDARD_GB=0.023

HOURS_PER_MONTH=730

# Get input or use defaults
ENVIRONMENT="${1:-dev}"

print_header "AWS Cost Calculator - 3-Tier Architecture"
echo "Environment: $ENVIRONMENT"
echo "Region: us-east-1"
echo ""

calculate_cost() {
    local description=$1
    local monthly_cost=$2
    local hours=$3
    local count=$4

    if [ -n "$hours" ]; then
        monthly_cost=$(echo "$monthly_cost * $hours" | bc)
    fi

    if [ -n "$count" ]; then
        monthly_cost=$(echo "$monthly_cost * $count" | bc)
    fi

    printf "%-40s \$%8.2f\n" "$description" "$monthly_cost"
    echo "$monthly_cost"
}

# Configuration based on environment
if [ "$ENVIRONMENT" == "prod" ]; then
    # Production configuration
    APP_INSTANCE_TYPE="t3.medium"
    APP_INSTANCE_COUNT=4
    APP_INSTANCE_HOURLY=$EC2_T3_MEDIUM_HOURLY

    BASTION_INSTANCE_TYPE="t3.micro"
    BASTION_INSTANCE_HOURLY=$EC2_T3_MICRO_HOURLY

    DB_INSTANCE_TYPE="db.t3.small"
    DB_INSTANCE_HOURLY=$RDS_T3_SMALL_HOURLY
    DB_MULTI_AZ=true

    NAT_GATEWAY_COUNT=2
    EBS_VOLUME_SIZE=50
    DATA_TRANSFER_GB=200
else
    # Development configuration
    APP_INSTANCE_TYPE="t3.small"
    APP_INSTANCE_COUNT=2
    APP_INSTANCE_HOURLY=$EC2_T3_SMALL_HOURLY

    BASTION_INSTANCE_TYPE="t3.micro"
    BASTION_INSTANCE_HOURLY=$EC2_T3_MICRO_HOURLY

    DB_INSTANCE_TYPE="db.t3.micro"
    DB_INSTANCE_HOURLY=$RDS_T3_MICRO_HOURLY
    DB_MULTI_AZ=false

    NAT_GATEWAY_COUNT=1
    EBS_VOLUME_SIZE=20
    DATA_TRANSFER_GB=50
fi

print_header "Configuration"
echo "Application Tier:"
echo "  Instance Type: $APP_INSTANCE_TYPE"
echo "  Instance Count: $APP_INSTANCE_COUNT"
echo ""
echo "Database Tier:"
echo "  Instance Type: $DB_INSTANCE_TYPE"
echo "  Multi-AZ: $DB_MULTI_AZ"
echo ""
echo "Network:"
echo "  NAT Gateways: $NAT_GATEWAY_COUNT"
echo "  Data Transfer: ${DATA_TRANSFER_GB}GB/month"
echo ""

print_header "Monthly Cost Breakdown"
echo ""

total_cost=0

# EC2 Instances (Application Tier)
app_cost=$(echo "$APP_INSTANCE_HOURLY * $HOURS_PER_MONTH * $APP_INSTANCE_COUNT" | bc)
total_cost=$(echo "$total_cost + $app_cost" | bc)
printf "%-40s \$%8.2f\n" "EC2 ($APP_INSTANCE_TYPE × $APP_INSTANCE_COUNT)" "$app_cost"

# Bastion Host
bastion_cost=$(echo "$BASTION_INSTANCE_HOURLY * $HOURS_PER_MONTH" | bc)
total_cost=$(echo "$total_cost + $bastion_cost" | bc)
printf "%-40s \$%8.2f\n" "Bastion ($BASTION_INSTANCE_TYPE)" "$bastion_cost"

# RDS Database
if [ "$DB_MULTI_AZ" == "true" ]; then
    db_cost=$(echo "$DB_INSTANCE_HOURLY * $HOURS_PER_MONTH * 2" | bc)
    printf "%-40s \$%8.2f\n" "RDS ($DB_INSTANCE_TYPE Multi-AZ)" "$db_cost"
else
    db_cost=$(echo "$DB_INSTANCE_HOURLY * $HOURS_PER_MONTH" | bc)
    printf "%-40s \$%8.2f\n" "RDS ($DB_INSTANCE_TYPE Single-AZ)" "$db_cost"
fi
total_cost=$(echo "$total_cost + $db_cost" | bc)

# Application Load Balancer
alb_base=$(echo "$ALB_HOURLY * $HOURS_PER_MONTH" | bc)
alb_lcu=$(echo "$ALB_LCU * 730" | bc)  # Assume 1 LCU average
alb_cost=$(echo "$alb_base + $alb_lcu" | bc)
total_cost=$(echo "$total_cost + $alb_cost" | bc)
printf "%-40s \$%8.2f\n" "Application Load Balancer" "$alb_cost"

# NAT Gateway
nat_hourly=$(echo "$NAT_GATEWAY_HOURLY * $HOURS_PER_MONTH * $NAT_GATEWAY_COUNT" | bc)
nat_data=$(echo "$DATA_TRANSFER_GB * $NAT_DATA_GB" | bc)
nat_cost=$(echo "$nat_hourly + $nat_data" | bc)
total_cost=$(echo "$total_cost + $nat_cost" | bc)
printf "%-40s \$%8.2f\n" "NAT Gateway (×$NAT_GATEWAY_COUNT + data)" "$nat_cost"

# EBS Volumes
total_ebs=$(echo "$EBS_VOLUME_SIZE * ($APP_INSTANCE_COUNT + 1)" | bc)
ebs_cost=$(echo "$total_ebs * $EBS_GP3_GB" | bc)
total_cost=$(echo "$total_cost + $ebs_cost" | bc)
printf "%-40s \$%8.2f\n" "EBS Storage (${total_ebs}GB gp3)" "$ebs_cost"

# RDS Storage
rds_storage=20
rds_storage_cost=$(echo "$rds_storage * 0.115" | bc)  # GP2 pricing
total_cost=$(echo "$total_cost + $rds_storage_cost" | bc)
printf "%-40s \$%8.2f\n" "RDS Storage (${rds_storage}GB)" "$rds_storage_cost"

# CloudWatch
cloudwatch_cost=5
total_cost=$(echo "$total_cost + $cloudwatch_cost" | bc)
printf "%-40s \$%8.2f\n" "CloudWatch (logs + metrics)" "$cloudwatch_cost"

# Data Transfer Out
data_transfer_cost=$(echo "$DATA_TRANSFER_GB * 0.09" | bc)
total_cost=$(echo "$total_cost + $data_transfer_cost" | bc)
printf "%-40s \$%8.2f\n" "Data Transfer Out (${DATA_TRANSFER_GB}GB)" "$data_transfer_cost"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s \$%8.2f\n" "TOTAL MONTHLY COST (Estimated)" "$total_cost"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Calculate annual cost
annual_cost=$(echo "$total_cost * 12" | bc)
printf "%-40s \$%8.2f\n" "ANNUAL COST (Estimated)" "$annual_cost"
echo ""

print_header "Cost Optimization Opportunities"
echo ""

# Reserved Instances savings
if [ "$ENVIRONMENT" == "prod" ]; then
    ri_savings_percent=40
    ri_savings=$(echo "$app_cost * 0.40" | bc)
    printf "${GREEN}%-50s -\$%8.2f/month${NC}\n" "Reserved Instances (1-year, no upfront)" "$ri_savings"
fi

# Spot Instances savings (for non-prod)
if [ "$ENVIRONMENT" != "prod" ]; then
    spot_savings=$(echo "$app_cost * 0.70" | bc)
    printf "${GREEN}%-50s -\$%8.2f/month${NC}\n" "Spot Instances (70% savings)" "$spot_savings"
fi

# Single NAT for dev
if [ "$ENVIRONMENT" != "prod" ] && [ "$NAT_GATEWAY_COUNT" -gt 1 ]; then
    single_nat_savings=$(echo "$nat_cost / 2" | bc)
    printf "${GREEN}%-50s -\$%8.2f/month${NC}\n" "Use single NAT Gateway (dev only)" "$single_nat_savings"
fi

# Auto-shutdown for dev
if [ "$ENVIRONMENT" != "prod" ]; then
    auto_shutdown_savings=$(echo "($app_cost + $bastion_cost) * 0.50" | bc)
    printf "${GREEN}%-50s -\$%8.2f/month${NC}\n" "Auto-shutdown after hours (12h/day)" "$auto_shutdown_savings"
fi

# Savings Summary
echo ""
print_header "Optimized Monthly Cost Estimate"
echo ""

if [ "$ENVIRONMENT" == "prod" ]; then
    optimized_cost=$(echo "$total_cost - $ri_savings" | bc)
    printf "With Reserved Instances:                  \$%8.2f\n" "$optimized_cost"
    savings_percent=40
else
    optimized_cost=$(echo "$total_cost * 0.50" | bc)  # Various optimizations
    printf "With optimizations (Spot, single NAT):     \$%8.2f\n" "$optimized_cost"
    savings_percent=50
fi

printf "Monthly Savings:                          -\$%8.2f (%d%%)\n" \
    "$(echo "$total_cost - $optimized_cost" | bc)" "$savings_percent"

echo ""
print_header "Usage Notes"
echo ""
echo "• Costs are estimates based on us-east-1 pricing"
echo "• Actual costs may vary based on usage patterns"
echo "• Data transfer costs assume typical web application traffic"
echo "• Does not include optional services (CloudFront, WAF, etc.)"
echo "• For exact costs, check AWS Cost Explorer"
echo ""
echo "To view actual costs:"
echo "  aws ce get-cost-and-usage --time-period Start=\$(date -d '1 month ago' +%Y-%m-01),End=\$(date +%Y-%m-%d) --granularity MONTHLY --metrics UnblendedCost"
echo ""
