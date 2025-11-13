#!/bin/bash

################################################################################
# Multi-Environment Deployment Script
# Purpose: Deploy infrastructure to specific environment (dev/staging/prod)
# Usage: ./deploy-env.sh <environment> [action]
#   environment: dev, staging, or prod
#   action: plan, apply, destroy (default: plan)
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <environment> [action]

Arguments:
    environment     Target environment: dev, staging, or prod
    action          Terraform action: plan, apply, destroy (default: plan)

Examples:
    $0 dev plan           # Plan changes for dev environment
    $0 staging apply      # Apply changes to staging
    $0 prod destroy       # Destroy prod infrastructure (requires confirmation)

Environment Configurations:
    dev      - Development (1 instance, 0.25 vCPU, auto-shutdown enabled)
    staging  - Staging (2 instances, 0.5 vCPU, weekend auto-shutdown)
    prod     - Production (3 instances, 0.5 vCPU, always on, HA)

EOF
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Missing required argument: environment"
    usage
fi

ENVIRONMENT=$1
ACTION=${2:-plan}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_info "Valid environments: dev, staging, prod"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    print_error "Invalid action: $ACTION"
    print_info "Valid actions: plan, apply, destroy"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"
INFRA_DIR="$PROJECT_ROOT/infra"

# Validate directories
if [ ! -d "$ENV_DIR" ]; then
    print_error "Environment directory not found: $ENV_DIR"
    exit 1
fi

if [ ! -d "$INFRA_DIR" ]; then
    print_error "Infrastructure directory not found: $INFRA_DIR"
    exit 1
fi

print_info "============================================"
print_info "Multi-Environment Deployment Tool"
print_info "============================================"
print_info "Environment:     $ENVIRONMENT"
print_info "Action:          $ACTION"
print_info "Environment Dir: $ENV_DIR"
print_info "Infrastructure:  $INFRA_DIR"
print_info "============================================"

# Production safety check
if [ "$ENVIRONMENT" == "prod" ] && [ "$ACTION" == "destroy" ]; then
    print_warning "⚠️  PRODUCTION DESTRUCTION WARNING ⚠️"
    print_warning "You are about to DESTROY the production environment!"
    read -p "Type 'destroy-production' to confirm: " CONFIRM
    if [ "$CONFIRM" != "destroy-production" ]; then
        print_error "Destruction cancelled"
        exit 1
    fi
fi

# Change to infrastructure directory
cd "$INFRA_DIR"

# Initialize Terraform with environment-specific backend
print_info "Initializing Terraform with $ENVIRONMENT backend..."
if [ -f "$ENV_DIR/backend.tf" ]; then
    cp "$ENV_DIR/backend.tf" ./backend-override.tf
    terraform init -reconfigure
else
    terraform init
fi

# Execute Terraform action
print_info "Executing: terraform $ACTION for $ENVIRONMENT..."

case "$ACTION" in
    plan)
        terraform plan \
            -var-file="$ENV_DIR/terraform.tfvars" \
            -out="$ENV_DIR/$ENVIRONMENT.tfplan"
        print_success "Plan saved to: $ENV_DIR/$ENVIRONMENT.tfplan"
        print_info "To apply this plan, run: $0 $ENVIRONMENT apply"
        ;;

    apply)
        if [ -f "$ENV_DIR/$ENVIRONMENT.tfplan" ]; then
            print_info "Applying saved plan from: $ENV_DIR/$ENVIRONMENT.tfplan"
            terraform apply "$ENV_DIR/$ENVIRONMENT.tfplan"
        else
            print_warning "No saved plan found, running apply with var file"
            terraform apply \
                -var-file="$ENV_DIR/terraform.tfvars" \
                -auto-approve
        fi
        print_success "✅ $ENVIRONMENT environment deployed successfully!"

        # Display outputs
        print_info "Environment Outputs:"
        terraform output
        ;;

    destroy)
        terraform destroy \
            -var-file="$ENV_DIR/terraform.tfvars" \
            -auto-approve
        print_success "✅ $ENVIRONMENT environment destroyed"
        ;;
esac

# Cleanup temporary backend file
if [ -f "./backend-override.tf" ]; then
    rm ./backend-override.tf
fi

print_success "Deployment script completed successfully!"
