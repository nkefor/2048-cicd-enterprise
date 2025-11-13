#!/bin/bash

################################################################################
# Environment Comparison & Drift Detection Script
# Purpose: Compare configurations and detect drift across environments
# Usage: ./compare-envs.sh [env1] [env2]
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

usage() {
    cat << EOF
Usage: $0 [env1] [env2]

Compare configurations and detect drift between environments.

Arguments:
    env1    First environment (optional, default: dev)
    env2    Second environment (optional, default: staging)

Examples:
    $0                  # Compare dev vs staging (default)
    $0 dev prod         # Compare dev vs prod
    $0 staging prod     # Compare staging vs prod

Features:
    - Configuration file comparison
    - Resource count comparison
    - Cost estimation comparison
    - Terraform state drift detection
    - Security posture comparison
    - Tag compliance checking

EOF
    exit 1
}

ENV1=${1:-dev}
ENV2=${2:-staging}

# Validate environments
for env in "$ENV1" "$ENV2"; do
    if [[ ! "$env" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $env"
        print_info "Valid environments: dev, staging, prod"
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header "============================================"
print_header "Environment Comparison Tool"
print_header "============================================"
print_info "Comparing: $ENV1 vs $ENV2"
print_info "Project Root: $PROJECT_ROOT"
print_header "============================================"
echo ""

# Function to extract value from tfvars
get_tfvar_value() {
    local file=$1
    local key=$2
    grep "^$key" "$file" | awk '{print $3}' | tr -d '"' || echo "N/A"
}

# 1. Configuration Comparison
print_header "1. Configuration File Comparison"
print_header "============================================"
CONFIG1="$PROJECT_ROOT/environments/$ENV1/terraform.tfvars"
CONFIG2="$PROJECT_ROOT/environments/$ENV2/terraform.tfvars"

if [ -f "$CONFIG1" ] && [ -f "$CONFIG2" ]; then
    # Key configuration items
    printf "%-25s | %-15s | %-15s\n" "Configuration Item" "$ENV1" "$ENV2"
    print_header "------------------------------------------------------------"

    KEYS=("environment" "desired_count" "cpu" "memory" "min_capacity" "max_capacity" "log_retention_days")

    for key in "${KEYS[@]}"; do
        val1=$(get_tfvar_value "$CONFIG1" "$key")
        val2=$(get_tfvar_value "$CONFIG2" "$key")

        if [ "$val1" == "$val2" ]; then
            printf "%-25s | %-15s | %-15s\n" "$key" "$val1" "$val2"
        else
            printf "%-25s | ${YELLOW}%-15s${NC} | ${YELLOW}%-15s${NC} ${YELLOW}⚠${NC}\n" "$key" "$val1" "$val2"
        fi
    done

    echo ""
    print_info "Full configuration diff:"
    diff -y --suppress-common-lines "$CONFIG1" "$CONFIG2" || print_info "No differences found"
else
    print_error "Configuration files not found"
fi

echo ""

# 2. Infrastructure State Comparison
print_header "2. Infrastructure State Analysis"
print_header "============================================"
cd "$PROJECT_ROOT/infra"

for env in "$ENV1" "$ENV2"; do
    print_info "Analyzing $env environment..."

    terraform workspace select "$env" 2>/dev/null || {
        print_warning "$env workspace does not exist"
        continue
    }

    terraform init -reconfigure > /dev/null 2>&1

    # Check for drift
    if terraform plan -detailed-exitcode -var-file="$PROJECT_ROOT/environments/$env/terraform.tfvars" > /dev/null 2>&1; then
        print_success "$env: No drift detected ✓"
    else
        print_warning "$env: Drift detected! Run 'terraform plan' for details"
    fi

    # Count resources
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l || echo "0")
    print_info "$env: $RESOURCE_COUNT resources managed"
done

echo ""

# 3. Cost Estimation Comparison
print_header "3. Cost Estimation Comparison"
print_header "============================================"

estimate_monthly_cost() {
    local env=$1
    local config="$PROJECT_ROOT/environments/$env/terraform.tfvars"

    # Simple cost estimation (rough calculation)
    local desired_count=$(get_tfvar_value "$config" "desired_count")
    local cpu=$(get_tfvar_value "$config" "cpu")
    local memory=$(get_tfvar_value "$config" "memory")

    # Fargate pricing (approximate): $0.04048 per vCPU hour + $0.004445 per GB hour
    # Convert CPU units (256 = 0.25 vCPU)
    local vcpu=$(echo "scale=2; $cpu / 1024" | bc)
    local gb=$(echo "scale=2; $memory / 1024" | bc)

    # Monthly hours: 730
    local cpu_cost=$(echo "scale=2; $vcpu * 0.04048 * 730 * $desired_count" | bc)
    local mem_cost=$(echo "scale=2; $gb * 0.004445 * 730 * $desired_count" | bc)
    local fargate_cost=$(echo "scale=2; $cpu_cost + $mem_cost" | bc)

    # Add ALB cost (~$16/month) and other services
    local alb_cost=16
    local ecr_cost=1
    local cloudwatch_cost=5
    local other_costs=$(echo "$alb_cost + $ecr_cost + $cloudwatch_cost" | bc)

    local total=$(echo "scale=2; $fargate_cost + $other_costs" | bc)

    echo "$total"
}

# Only estimate if bc is available
if command -v bc &> /dev/null; then
    COST1=$(estimate_monthly_cost "$ENV1")
    COST2=$(estimate_monthly_cost "$ENV2")

    printf "%-15s | %-20s\n" "Environment" "Estimated Monthly Cost"
    print_header "------------------------------------"
    printf "%-15s | \$%-19s\n" "$ENV1" "$COST1"
    printf "%-15s | \$%-19s\n" "$ENV2" "$COST2"

    if (( $(echo "$COST1 < $COST2" | bc -l) )); then
        SAVINGS=$(echo "scale=2; $COST2 - $COST1" | bc)
        PERCENT=$(echo "scale=2; ($SAVINGS / $COST2) * 100" | bc)
        print_info "$ENV1 is \$$SAVINGS cheaper per month (${PERCENT}% savings)"
    fi
else
    print_warning "bc not installed - skipping cost estimation"
    print_info "Install bc for cost estimates: apt-get install bc (Ubuntu) or brew install bc (Mac)"
fi

echo ""

# 4. Security Posture Comparison
print_header "4. Security Posture Comparison"
print_header "============================================"

check_security_setting() {
    local config=$1
    local setting=$2
    local value=$(grep "$setting" "$config" | awk '{print $3}' | tr -d '"' || echo "not_set")
    echo "$value"
}

printf "%-30s | %-10s | %-10s\n" "Security Setting" "$ENV1" "$ENV2"
print_header "-------------------------------------------------------"

SECURITY_SETTINGS=("enable_detailed_monitoring" "enable_waf" "enable_encryption_at_rest" "enable_encryption_in_transit")

for setting in "${SECURITY_SETTINGS[@]}"; do
    val1=$(check_security_setting "$CONFIG1" "$setting")
    val2=$(check_security_setting "$CONFIG2" "$setting")

    if [ "$val1" == "true" ] || [ "$val2" == "true" ]; then
        printf "%-30s | %-10s | %-10s\n" "$setting" "$val1" "$val2"
    fi
done

echo ""

# 5. Tag Compliance Check
print_header "5. Tag Compliance Check"
print_header "============================================"

check_required_tags() {
    local config=$1
    local env=$2

    REQUIRED_TAGS=("Environment" "ManagedBy" "Project" "CostCenter")
    local missing_tags=()

    for tag in "${REQUIRED_TAGS[@]}"; do
        if ! grep -q "$tag" "$config"; then
            missing_tags+=("$tag")
        fi
    done

    if [ ${#missing_tags[@]} -eq 0 ]; then
        print_success "$env: All required tags present ✓"
    else
        print_warning "$env: Missing tags: ${missing_tags[*]}"
    fi
}

check_required_tags "$CONFIG1" "$ENV1"
check_required_tags "$CONFIG2" "$ENV2"

echo ""

# 6. Summary
print_header "6. Summary & Recommendations"
print_header "============================================"

# Generate recommendations
if [ "$ENV1" == "dev" ] && [ "$ENV2" == "staging" ]; then
    print_info "Recommendations for Dev → Staging promotion:"
    print_info "  1. Ensure all tests pass in dev environment"
    print_info "  2. Review configuration differences above"
    print_info "  3. Use: ./scripts/promote-env.sh dev staging"
fi

if [ "$ENV1" == "staging" ] && [ "$ENV2" == "prod" ] || [ "$ENV2" == "prod" ]; then
    print_warning "Production deployment recommendations:"
    print_info "  1. Enable WAF for production"
    print_info "  2. Enable detailed monitoring"
    print_info "  3. Ensure backup strategy is configured"
    print_info "  4. Review security posture above"
    print_info "  5. Get approval before promoting to production"
fi

print_success "Comparison complete!"
echo ""
