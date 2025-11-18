#!/bin/bash
#
# Automated Deployment Script for 3-Tier Architecture
# This script handles the complete deployment process from start to finish
#
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACTION="${1:-plan}"

# Functions
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_tools=()

    # Check for required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v ansible >/dev/null 2>&1 || missing_tools+=("ansible")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install missing tools:"
        echo "  - terraform: https://www.terraform.io/downloads"
        echo "  - aws-cli: https://aws.amazon.com/cli/"
        echo "  - ansible: https://docs.ansible.com/ansible/latest/installation_guide/"
        echo "  - jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi

    print_success "All required tools are installed"

    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi

    print_success "AWS credentials configured"

    # Display AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    print_info "AWS Account: $ACCOUNT_ID"
    print_info "AWS User: $USER_ARN"
}

check_required_vars() {
    print_header "Checking Required Variables"

    local missing_vars=()

    if [ -z "$TERRAFORM_STATE_BUCKET" ]; then
        missing_vars+=("TERRAFORM_STATE_BUCKET")
    fi

    if [ -z "$DB_PASSWORD" ]; then
        missing_vars+=("DB_PASSWORD")
    fi

    if [ -z "$SSH_KEY_NAME" ]; then
        missing_vars+=("SSH_KEY_NAME")
    fi

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        echo ""
        echo "Please set the following environment variables:"
        echo "  export TERRAFORM_STATE_BUCKET=your-state-bucket"
        echo "  export DB_PASSWORD='YourSecurePassword123!'"
        echo "  export SSH_KEY_NAME=your-ssh-key"
        exit 1
    fi

    print_success "All required variables are set"
}

validate_terraform() {
    print_header "Validating Terraform Configuration"

    cd "$TERRAFORM_DIR"

    # Format check
    print_info "Running terraform fmt..."
    if terraform fmt -check -recursive; then
        print_success "Terraform formatting is correct"
    else
        print_warning "Terraform formatting issues found. Auto-fixing..."
        terraform fmt -recursive
    fi

    # Validate
    print_info "Running terraform validate..."
    terraform init -backend=false >/dev/null 2>&1
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        exit 1
    fi
}

init_terraform() {
    print_header "Initializing Terraform"

    cd "$TERRAFORM_DIR"

    print_info "Initializing Terraform backend..."
    terraform init \
        -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
        -backend-config="key=3-tier-architecture/${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=$AWS_REGION" \
        -backend-config="encrypt=true" \
        -reconfigure

    print_success "Terraform initialized successfully"
}

plan_terraform() {
    print_header "Planning Terraform Deployment"

    cd "$TERRAFORM_DIR"

    print_info "Generating execution plan..."
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="environment=$ENVIRONMENT" \
        -var="db_password=$DB_PASSWORD" \
        -var="key_name=$SSH_KEY_NAME" \
        -out=tfplan

    print_success "Terraform plan generated: tfplan"

    # Ask for confirmation
    echo ""
    read -p "Do you want to review the plan? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform show tfplan | less
    fi
}

apply_terraform() {
    print_header "Applying Terraform Configuration"

    cd "$TERRAFORM_DIR"

    if [ ! -f "tfplan" ]; then
        print_error "No terraform plan found. Run with 'plan' first."
        exit 1
    fi

    # Confirmation
    echo ""
    print_warning "This will deploy/modify infrastructure in AWS"
    print_info "Environment: $ENVIRONMENT"
    print_info "Region: $AWS_REGION"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no) " -r
    echo ""
    if [[ ! $REPLY == "yes" ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi

    print_info "Applying Terraform configuration..."
    if terraform apply tfplan; then
        print_success "Infrastructure deployed successfully"
    else
        print_error "Terraform apply failed"
        exit 1
    fi

    # Save outputs
    print_info "Saving outputs..."
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"

    # Display important outputs
    echo ""
    print_header "Deployment Outputs"
    echo ""
    print_info "ALB DNS: $(terraform output -raw alb_dns_name)"
    print_info "Bastion IP: $(terraform output -raw bastion_public_ip)"
    print_info "Application URL: $(terraform output -raw application_url)"
    echo ""
}

configure_ansible() {
    print_header "Configuring Infrastructure with Ansible"

    cd "$ANSIBLE_DIR"

    # Wait for instances to be ready
    print_info "Waiting for EC2 instances to be ready..."
    sleep 30

    # Refresh dynamic inventory
    print_info "Refreshing dynamic inventory..."
    ansible-inventory -i inventory/aws_ec2.yml --list > /dev/null 2>&1 || true

    # Display inventory
    print_info "Discovered hosts:"
    ansible-inventory -i inventory/aws_ec2.yml --graph

    # Run Ansible playbook
    echo ""
    read -p "Do you want to configure servers with Ansible? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Running Ansible playbook..."
        ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
        print_success "Ansible configuration completed"
    else
        print_warning "Skipping Ansible configuration"
    fi
}

run_health_checks() {
    print_header "Running Health Checks"

    cd "$TERRAFORM_DIR"

    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")

    if [ -z "$ALB_DNS" ]; then
        print_warning "ALB DNS not found, skipping health checks"
        return
    fi

    print_info "Checking ALB health..."
    print_info "URL: http://$ALB_DNS"

    # Wait for ALB to be ready
    print_info "Waiting for ALB to become available..."
    for i in {1..12}; do
        if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS" | grep -q "200"; then
            print_success "ALB is healthy and responding"
            return
        fi
        echo -n "."
        sleep 10
    done

    print_warning "ALB health check timed out (this is normal if instances are still launching)"
}

destroy_infrastructure() {
    print_header "Destroying Infrastructure"

    cd "$TERRAFORM_DIR"

    # Strong confirmation for destroy
    echo ""
    print_error "⚠️  WARNING: This will DESTROY all infrastructure in environment: $ENVIRONMENT"
    print_error "This action cannot be undone!"
    echo ""
    read -p "Type 'destroy-$ENVIRONMENT' to confirm: " -r
    echo ""

    if [[ ! $REPLY == "destroy-$ENVIRONMENT" ]]; then
        print_info "Destruction cancelled"
        exit 0
    fi

    print_info "Destroying infrastructure..."
    terraform destroy \
        -var="aws_region=$AWS_REGION" \
        -var="environment=$ENVIRONMENT" \
        -var="db_password=$DB_PASSWORD" \
        -var="key_name=$SSH_KEY_NAME" \
        -auto-approve

    print_success "Infrastructure destroyed"
}

show_outputs() {
    print_header "Infrastructure Outputs"

    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfstate" ]; then
        print_error "No terraform state found"
        exit 1
    fi

    echo ""
    terraform output
    echo ""
}

display_usage() {
    cat << EOF
Usage: $0 [ACTION]

Actions:
    check       - Check prerequisites and validate configuration
    plan        - Generate Terraform execution plan (default)
    apply       - Apply Terraform configuration and deploy
    configure   - Run Ansible configuration only
    deploy      - Full deployment (plan + apply + configure)
    outputs     - Show Terraform outputs
    destroy     - Destroy all infrastructure
    help        - Display this help message

Environment Variables:
    TERRAFORM_STATE_BUCKET  - S3 bucket for Terraform state (required)
    DB_PASSWORD             - RDS database password (required)
    SSH_KEY_NAME            - SSH key pair name (required)
    ENVIRONMENT             - Environment name (default: dev)
    AWS_REGION              - AWS region (default: us-east-1)

Examples:
    # Check prerequisites
    $0 check

    # Plan deployment
    export TERRAFORM_STATE_BUCKET=my-state-bucket
    export DB_PASSWORD='SecurePass123!'
    export SSH_KEY_NAME=my-key
    $0 plan

    # Deploy infrastructure
    $0 apply

    # Full deployment including Ansible
    $0 deploy

    # Destroy infrastructure
    $0 destroy

EOF
}

# Main execution
main() {
    case "$ACTION" in
        check)
            check_prerequisites
            check_required_vars
            validate_terraform
            print_success "All checks passed!"
            ;;
        plan)
            check_prerequisites
            check_required_vars
            validate_terraform
            init_terraform
            plan_terraform
            ;;
        apply)
            check_prerequisites
            check_required_vars
            init_terraform
            apply_terraform
            run_health_checks
            ;;
        configure)
            configure_ansible
            ;;
        deploy)
            check_prerequisites
            check_required_vars
            validate_terraform
            init_terraform
            plan_terraform
            apply_terraform
            configure_ansible
            run_health_checks
            print_header "Deployment Complete!"
            print_success "Infrastructure deployed and configured"
            ;;
        outputs)
            show_outputs
            ;;
        destroy)
            check_prerequisites
            destroy_infrastructure
            ;;
        help|--help|-h)
            display_usage
            ;;
        *)
            print_error "Unknown action: $ACTION"
            echo ""
            display_usage
            exit 1
            ;;
    esac
}

# Run main
main
