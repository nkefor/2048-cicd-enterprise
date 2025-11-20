#!/bin/bash
################################################################################
# Enterprise CI/CD Deployment Automation Script
# Purpose: Automate Docker build, ECR push, and ECS Fargate deployment
# Usage: ./scripts/deploy.sh [environment] [options]
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/deployment.log"

# Default values
ENVIRONMENT="${1:-production}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-false}"
DEPLOYMENT_TIMEOUT="${DEPLOYMENT_TIMEOUT:-600}" # 10 minutes

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

################################################################################
# Validation Functions
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    local required_commands=("docker" "aws" "jq" "git")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

validate_environment() {
    log_info "Validating environment variables..."

    local required_vars=("AWS_REGION" "ECR_REPO" "ECS_CLUSTER" "ECS_SERVICE")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set these variables and try again"
        exit 1
    fi

    log_success "Environment variables validated"
}

validate_aws_credentials() {
    log_info "Validating AWS credentials..."

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are invalid or expired"
        log_error "Please configure AWS credentials using 'aws configure' or set AWS environment variables"
        exit 1
    fi

    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_user=$(aws sts get-caller-identity --query Arn --output text)

    log_success "AWS credentials validated"
    log_info "AWS Account: ${aws_account}"
    log_info "AWS Identity: ${aws_user}"
}

################################################################################
# Docker Functions
################################################################################

build_docker_image() {
    log_info "Building Docker image..."

    local git_sha=$(git rev-parse --short HEAD)
    local image_tag="${ECR_REPO}:${git_sha}"
    local latest_tag="${ECR_REPO}:latest"

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would build image with tag ${image_tag}"
        return 0
    fi

    cd "${PROJECT_ROOT}/2048"

    docker build \
        --tag "${image_tag}" \
        --tag "${latest_tag}" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="${git_sha}" \
        . || {
            log_error "Docker build failed"
            exit 1
        }

    log_success "Docker image built successfully: ${image_tag}"

    # Export for use in other functions
    export IMAGE_TAG="${image_tag}"
    export LATEST_TAG="${latest_tag}"
    export GIT_SHA="${git_sha}"
}

push_to_ecr() {
    log_info "Pushing Docker image to ECR..."

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would push image ${IMAGE_TAG} to ECR"
        return 0
    fi

    # Login to ECR
    log_info "Logging in to Amazon ECR..."
    aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login --username AWS --password-stdin "${ECR_REPO%:*}" || {
            log_error "ECR login failed"
            exit 1
        }

    # Push images
    log_info "Pushing ${IMAGE_TAG}..."
    docker push "${IMAGE_TAG}" || {
        log_error "Failed to push image with git SHA tag"
        exit 1
    }

    log_info "Pushing ${LATEST_TAG}..."
    docker push "${LATEST_TAG}" || {
        log_warning "Failed to push latest tag (non-fatal)"
    }

    log_success "Docker images pushed to ECR successfully"
}

################################################################################
# ECS Deployment Functions
################################################################################

get_current_task_definition() {
    log_info "Retrieving current task definition..."

    local task_def=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --query 'services[0].taskDefinition' \
        --output text)

    if [ -z "$task_def" ] || [ "$task_def" = "None" ]; then
        log_error "Failed to retrieve current task definition"
        exit 1
    fi

    log_info "Current task definition: ${task_def}"
    export CURRENT_TASK_DEFINITION="${task_def}"
}

update_ecs_service() {
    log_info "Updating ECS service..."

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would update ECS service ${ECS_SERVICE}"
        return 0
    fi

    # Get current task definition
    get_current_task_definition

    # Update the service with new image
    local update_output=$(aws ecs update-service \
        --cluster "${ECS_CLUSTER}" \
        --service "${ECS_SERVICE}" \
        --force-new-deployment \
        --region "${AWS_REGION}" \
        --output json 2>&1) || {
            log_error "Failed to update ECS service"
            log_error "${update_output}"
            exit 1
        }

    log_success "ECS service update initiated"

    # Extract deployment ID
    local deployment_id=$(echo "${update_output}" | jq -r '.service.deployments[0].id // empty')
    if [ -n "$deployment_id" ]; then
        log_info "Deployment ID: ${deployment_id}"
        export DEPLOYMENT_ID="${deployment_id}"
    fi
}

wait_for_deployment() {
    log_info "Waiting for deployment to stabilize (timeout: ${DEPLOYMENT_TIMEOUT}s)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would wait for deployment to stabilize"
        return 0
    fi

    local start_time=$(date +%s)
    local elapsed=0

    while [ $elapsed -lt $DEPLOYMENT_TIMEOUT ]; do
        local status=$(aws ecs describe-services \
            --cluster "${ECS_CLUSTER}" \
            --services "${ECS_SERVICE}" \
            --region "${AWS_REGION}" \
            --query 'services[0].deployments[?status==`PRIMARY`].rolloutState' \
            --output text)

        if [ "$status" = "COMPLETED" ]; then
            log_success "Deployment completed successfully"
            return 0
        elif [ "$status" = "FAILED" ]; then
            log_error "Deployment failed"
            return 1
        fi

        elapsed=$(( $(date +%s) - start_time ))
        log_info "Deployment in progress... (${elapsed}s / ${DEPLOYMENT_TIMEOUT}s)"
        sleep 10
    done

    log_error "Deployment timeout reached (${DEPLOYMENT_TIMEOUT}s)"
    return 1
}

################################################################################
# Health Check Functions
################################################################################

perform_health_check() {
    if [ "$SKIP_HEALTH_CHECK" = "true" ]; then
        log_warning "Skipping health check (SKIP_HEALTH_CHECK=true)"
        return 0
    fi

    log_info "Performing health check..."

    if [ -z "${ALB_DNS_NAME:-}" ]; then
        log_warning "ALB_DNS_NAME not set, skipping HTTP health check"
        return 0
    fi

    local health_check_url="http://${ALB_DNS_NAME}"
    local max_attempts=10
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))

        log_info "Health check attempt ${attempt}/${max_attempts}..."

        if curl -sf --max-time 10 "${health_check_url}" > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi

        sleep 5
    done

    log_error "Health check failed after ${max_attempts} attempts"
    return 1
}

################################################################################
# Rollback Functions
################################################################################

rollback_deployment() {
    log_error "Initiating rollback to previous task definition..."

    if [ -z "${CURRENT_TASK_DEFINITION:-}" ]; then
        log_error "Cannot rollback: previous task definition unknown"
        return 1
    fi

    log_info "Rolling back to: ${CURRENT_TASK_DEFINITION}"

    aws ecs update-service \
        --cluster "${ECS_CLUSTER}" \
        --service "${ECS_SERVICE}" \
        --task-definition "${CURRENT_TASK_DEFINITION}" \
        --force-new-deployment \
        --region "${AWS_REGION}" > /dev/null || {
            log_error "Rollback failed"
            return 1
        }

    log_success "Rollback initiated successfully"
    log_info "Waiting for rollback to complete..."

    if wait_for_deployment; then
        log_success "Rollback completed successfully"
        return 0
    else
        log_error "Rollback failed to stabilize"
        return 1
    fi
}

################################################################################
# Main Deployment Pipeline
################################################################################

main() {
    log_info "=========================================="
    log_info "Enterprise CI/CD Deployment Starting"
    log_info "=========================================="
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Dry Run: ${DRY_RUN}"
    log_info "Timestamp: $(date)"
    log_info "=========================================="

    # Pre-deployment checks
    check_prerequisites
    validate_environment
    validate_aws_credentials

    # Build and push
    build_docker_image
    push_to_ecr

    # Deploy to ECS
    update_ecs_service

    # Wait for deployment
    if wait_for_deployment; then
        log_success "Deployment stabilized"
    else
        log_error "Deployment failed to stabilize"

        # Attempt automatic rollback
        if rollback_deployment; then
            log_error "Deployment failed, but rollback succeeded"
            exit 1
        else
            log_error "Deployment failed AND rollback failed - manual intervention required"
            exit 2
        fi
    fi

    # Post-deployment health check
    if perform_health_check; then
        log_success "Health check passed"
    else
        log_error "Health check failed"

        # Attempt rollback on health check failure
        if rollback_deployment; then
            log_error "Health check failed, rollback succeeded"
            exit 1
        else
            log_error "Health check failed AND rollback failed - manual intervention required"
            exit 2
        fi
    fi

    log_info "=========================================="
    log_success "Deployment Completed Successfully!"
    log_info "=========================================="
    log_info "Image: ${IMAGE_TAG}"
    log_info "Git SHA: ${GIT_SHA}"
    log_info "Service: ${ECS_SERVICE}"
    log_info "Cluster: ${ECS_CLUSTER}"
    log_info "=========================================="
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"
