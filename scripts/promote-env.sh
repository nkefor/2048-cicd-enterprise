#!/bin/bash

################################################################################
# Environment Promotion Script
# Purpose: Promote infrastructure/code from one environment to another
# Usage: ./promote-env.sh <from> <to>
#   Typical flow: dev → staging → prod
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 <from_env> <to_env>

Promote infrastructure configuration and application from one environment to another.

Arguments:
    from_env    Source environment: dev or staging
    to_env      Target environment: staging or prod

Valid Promotion Paths:
    dev → staging       # Promote from dev to staging
    staging → prod      # Promote from staging to production

Examples:
    $0 dev staging      # Promote dev to staging
    $0 staging prod     # Promote staging to production

Promotion Process:
    1. Validate source environment health
    2. Run smoke tests on source
    3. Compare configurations (drift detection)
    4. Copy approved changes to target
    5. Plan target environment changes
    6. Await approval for production promotions
    7. Apply changes to target environment
    8. Validate target environment health
    9. Run smoke tests on target

EOF
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    print_error "Incorrect number of arguments"
    usage
fi

FROM_ENV=$1
TO_ENV=$2

# Validate promotion path
VALID_PROMOTIONS=("dev:staging" "staging:prod")
PROMOTION_PATH="$FROM_ENV:$TO_ENV"

if [[ ! " ${VALID_PROMOTIONS[@]} " =~ " ${PROMOTION_PATH} " ]]; then
    print_error "Invalid promotion path: $FROM_ENV → $TO_ENV"
    print_info "Valid promotion paths:"
    print_info "  - dev → staging"
    print_info "  - staging → prod"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_info "============================================"
print_info "Environment Promotion Tool"
print_info "============================================"
print_info "Promotion Path: $FROM_ENV → $TO_ENV"
print_info "Project Root:   $PROJECT_ROOT"
print_info "============================================"

# Step 1: Validate source environment
print_info "Step 1/9: Validating source environment ($FROM_ENV)..."
cd "$PROJECT_ROOT/infra"
terraform workspace select "$FROM_ENV" 2>/dev/null || terraform workspace new "$FROM_ENV"
terraform init -reconfigure > /dev/null

# Check if source environment is deployed
if ! terraform show > /dev/null 2>&1; then
    print_error "Source environment ($FROM_ENV) is not deployed"
    print_info "Deploy it first: ./scripts/deploy-env.sh $FROM_ENV apply"
    exit 1
fi
print_success "Source environment validated"

# Step 2: Run smoke tests on source
print_info "Step 2/9: Running smoke tests on $FROM_ENV..."
SOURCE_ALB_URL=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
if [ -n "$SOURCE_ALB_URL" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$SOURCE_ALB_URL" || echo "000")
    if [ "$HTTP_CODE" == "200" ]; then
        print_success "Smoke test passed (HTTP $HTTP_CODE)"
    else
        print_warning "Smoke test warning (HTTP $HTTP_CODE)"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            print_error "Promotion cancelled"
            exit 1
        fi
    fi
else
    print_warning "Could not retrieve ALB URL for smoke test"
fi

# Step 3: Compare configurations
print_info "Step 3/9: Comparing environment configurations..."
FROM_CONFIG="$PROJECT_ROOT/environments/$FROM_ENV/terraform.tfvars"
TO_CONFIG="$PROJECT_ROOT/environments/$TO_ENV/terraform.tfvars"

print_info "Source config: $FROM_CONFIG"
print_info "Target config: $TO_CONFIG"

if command -v diff &> /dev/null; then
    print_info "Configuration differences:"
    diff -u "$FROM_CONFIG" "$TO_CONFIG" || true
fi

# Step 4: Copy approved image tag (for container deployments)
print_info "Step 4/9: Identifying deployment artifacts..."
SOURCE_IMAGE_TAG=$(terraform output -raw ecr_image_tag 2>/dev/null || echo "latest")
print_info "Source image tag: $SOURCE_IMAGE_TAG"

# Step 5: Plan target environment
print_info "Step 5/9: Planning target environment ($TO_ENV)..."
terraform workspace select "$TO_ENV" 2>/dev/null || terraform workspace new "$TO_ENV"
terraform init -reconfigure > /dev/null

terraform plan \
    -var-file="$PROJECT_ROOT/environments/$TO_ENV/terraform.tfvars" \
    -out="$PROJECT_ROOT/environments/$TO_ENV/promotion.tfplan"

print_success "Plan created successfully"
print_info "Plan saved to: $PROJECT_ROOT/environments/$TO_ENV/promotion.tfplan"

# Step 6: Approval for production
if [ "$TO_ENV" == "prod" ]; then
    print_warning "============================================"
    print_warning "⚠️  PRODUCTION PROMOTION WARNING ⚠️"
    print_warning "============================================"
    print_warning "You are about to promote to PRODUCTION"
    print_warning ""
    print_warning "Source:      $FROM_ENV"
    print_warning "Destination: $TO_ENV"
    print_warning "Image Tag:   $SOURCE_IMAGE_TAG"
    print_warning ""
    print_info "Please review the Terraform plan above carefully."
    print_warning "============================================"

    read -p "Type 'promote-to-production' to confirm: " CONFIRM
    if [ "$CONFIRM" != "promote-to-production" ]; then
        print_error "Production promotion cancelled"
        exit 1
    fi

    # Additional approval for production
    print_info "Enter approval ticket number (e.g., JIRA-1234): "
    read -r APPROVAL_TICKET
    print_info "Promotion approved with ticket: $APPROVAL_TICKET"
fi

# Step 7: Apply to target
print_info "Step 7/9: Applying changes to $TO_ENV..."
terraform apply "$PROJECT_ROOT/environments/$TO_ENV/promotion.tfplan"
print_success "✅ Changes applied to $TO_ENV"

# Step 8: Validate target environment
print_info "Step 8/9: Validating target environment ($TO_ENV)..."
sleep 10  # Wait for deployment to stabilize

TARGET_ALB_URL=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
if [ -n "$TARGET_ALB_URL" ]; then
    print_info "Target ALB URL: $TARGET_ALB_URL"
else
    print_warning "Could not retrieve target ALB URL"
fi

# Step 9: Run smoke tests on target
print_info "Step 9/9: Running smoke tests on $TO_ENV..."
if [ -n "$TARGET_ALB_URL" ]; then
    MAX_ATTEMPTS=10
    ATTEMPT=1

    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$TARGET_ALB_URL" || echo "000")
        if [ "$HTTP_CODE" == "200" ]; then
            print_success "✅ Smoke test passed (HTTP $HTTP_CODE)"
            break
        else
            print_warning "Attempt $ATTEMPT/$MAX_ATTEMPTS: HTTP $HTTP_CODE"
            if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
                print_error "Smoke tests failed after $MAX_ATTEMPTS attempts"
                print_warning "Consider rolling back with: terraform apply (previous state)"
                exit 1
            fi
            sleep 5
            ATTEMPT=$((ATTEMPT + 1))
        fi
    done
fi

print_success "============================================"
print_success "✅ PROMOTION COMPLETED SUCCESSFULLY!"
print_success "============================================"
print_success "Promoted: $FROM_ENV → $TO_ENV"
if [ -n "$TARGET_ALB_URL" ]; then
    print_success "URL: http://$TARGET_ALB_URL"
fi
print_success "============================================"

# Display target environment outputs
print_info "Target Environment Outputs:"
terraform output

# Log promotion for audit
PROMOTION_LOG="$PROJECT_ROOT/promotion-history.log"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FROM_ENV → $TO_ENV | Success | Image: $SOURCE_IMAGE_TAG" >> "$PROMOTION_LOG"
print_info "Promotion logged to: $PROMOTION_LOG"
