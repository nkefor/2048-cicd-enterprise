#!/bin/bash
################################################################################
# Enterprise CI/CD Rollback Script
# Purpose: Rollback ECS service to previous stable version
# Usage: ./scripts/rollback.sh [options]
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
LOG_FILE="${PROJECT_ROOT}/rollback.log"

# Default values
DRY_RUN="${DRY_RUN:-false}"
ROLLBACK_TO="${ROLLBACK_TO:-}"  # Specific task definition to rollback to
ROLLBACK_STEPS="${ROLLBACK_STEPS:-1}"  # Number of versions to rollback
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"
WAIT_FOR_STABLE="${WAIT_FOR_STABLE:-true}"
TIMEOUT="${TIMEOUT:-600}"  # 10 minutes

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

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq not found"
        exit 1
    fi

    log_success "Prerequisites satisfied"
}

validate_environment() {
    log_info "Validating environment..."

    if [ -z "${ECS_CLUSTER:-}" ] || [ -z "${ECS_SERVICE:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_error "Required environment variables not set: ECS_CLUSTER, ECS_SERVICE, AWS_REGION"
        exit 1
    fi

    # Validate AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are invalid or expired"
        exit 1
    fi

    log_success "Environment validated"
}

################################################################################
# Service Information Functions
################################################################################

get_current_task_definition() {
    log_info "Getting current task definition..."

    local current_td=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null) || {
            log_error "Failed to get current task definition"
            exit 1
        }

    if [ -z "$current_td" ] || [ "$current_td" = "None" ]; then
        log_error "No task definition found for service"
        exit 1
    fi

    log_info "Current task definition: ${current_td}"
    echo "$current_td"
}

get_task_definition_family() {
    log_info "Getting task definition family..."

    local current_td=$(get_current_task_definition)
    local family=$(echo "$current_td" | awk -F: '{print $6}' | awk -F/ '{print $2}')

    log_info "Task definition family: ${family}"
    echo "$family"
}

list_task_definitions() {
    local family="$1"
    local max_items="${2:-10}"

    log_info "Listing recent task definitions for family: ${family}"

    aws ecs list-task-definitions \
        --family-prefix "${family}" \
        --sort DESC \
        --max-items "$max_items" \
        --region "${AWS_REGION}" \
        --query 'taskDefinitionArns' \
        --output json 2>/dev/null || {
            log_error "Failed to list task definitions"
            exit 1
        }
}

get_task_definition_details() {
    local task_def_arn="$1"

    aws ecs describe-task-definition \
        --task-definition "${task_def_arn}" \
        --region "${AWS_REGION}" \
        --query 'taskDefinition' \
        --output json 2>/dev/null || {
            log_error "Failed to describe task definition: ${task_def_arn}"
            return 1
        }
}

display_task_definition_info() {
    local task_def_arn="$1"
    local index="$2"

    local task_def=$(get_task_definition_details "$task_def_arn")

    local revision=$(echo "$task_def" | jq -r '.revision')
    local image=$(echo "$task_def" | jq -r '.containerDefinitions[0].image')
    local created_at=$(echo "$task_def" | jq -r '.registeredAt // "N/A"')

    echo "  ${index}. ${task_def_arn}"
    echo "     Revision: ${revision}"
    echo "     Image: ${image}"
    echo "     Created: ${created_at}"
}

################################################################################
# Rollback Selection Functions
################################################################################

select_rollback_target() {
    log_info "=========================================="
    log_info "Selecting Rollback Target"
    log_info "=========================================="

    local current_td=$(get_current_task_definition)
    local family=$(get_task_definition_family)

    log_info "Current task definition: ${current_td}"
    echo ""

    # Get list of task definitions
    local task_defs=$(list_task_definitions "$family" 10)
    local task_def_array=($(echo "$task_defs" | jq -r '.[]'))

    if [ ${#task_def_array[@]} -lt 2 ]; then
        log_error "No previous task definitions found to rollback to"
        exit 1
    fi

    log_info "Available task definitions (newest first):"
    echo ""

    local index=0
    for td in "${task_def_array[@]}"; do
        if [ "$td" = "$current_td" ]; then
            echo -e "${GREEN}→ CURRENT${NC}"
        fi
        display_task_definition_info "$td" "$index"
        echo ""
        index=$((index + 1))
    done

    # Determine rollback target
    if [ -n "$ROLLBACK_TO" ]; then
        log_info "Using specified rollback target: ${ROLLBACK_TO}"
        echo "$ROLLBACK_TO"
    else
        # Find current index
        local current_index=0
        for i in "${!task_def_array[@]}"; do
            if [ "${task_def_array[$i]}" = "$current_td" ]; then
                current_index=$i
                break
            fi
        done

        # Calculate rollback index
        local rollback_index=$((current_index + ROLLBACK_STEPS))

        if [ $rollback_index -ge ${#task_def_array[@]} ]; then
            log_error "Cannot rollback ${ROLLBACK_STEPS} steps (only ${#task_def_array[@]} versions available)"
            exit 1
        fi

        local rollback_target="${task_def_array[$rollback_index]}"
        log_info "Selected rollback target (${ROLLBACK_STEPS} steps back): ${rollback_target}"
        echo "$rollback_target"
    fi
}

confirm_rollback() {
    local from_td="$1"
    local to_td="$2"

    if [ "$AUTO_CONFIRM" = "true" ]; then
        log_warning "Auto-confirm enabled, proceeding with rollback"
        return 0
    fi

    log_warning "=========================================="
    log_warning "ROLLBACK CONFIRMATION"
    log_warning "=========================================="
    log_warning "Cluster: ${ECS_CLUSTER}"
    log_warning "Service: ${ECS_SERVICE}"
    log_warning "FROM: ${from_td}"
    log_warning "TO:   ${to_td}"
    log_warning "=========================================="

    echo -n "Are you sure you want to proceed with rollback? (yes/no): "
    read -r response

    if [ "$response" != "yes" ]; then
        log_info "Rollback cancelled by user"
        exit 0
    fi

    log_info "Rollback confirmed"
}

################################################################################
# Rollback Execution Functions
################################################################################

execute_rollback() {
    local target_td="$1"

    log_info "Executing rollback to: ${target_td}"

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would rollback to ${target_td}"
        return 0
    fi

    # Create backup of current state
    local current_td=$(get_current_task_definition)
    echo "$current_td" > "${PROJECT_ROOT}/.last-task-definition-before-rollback"
    log_info "Backed up current task definition to .last-task-definition-before-rollback"

    # Execute rollback
    local rollback_output=$(aws ecs update-service \
        --cluster "${ECS_CLUSTER}" \
        --service "${ECS_SERVICE}" \
        --task-definition "${target_td}" \
        --force-new-deployment \
        --region "${AWS_REGION}" \
        --output json 2>&1) || {
            log_error "Rollback failed"
            log_error "${rollback_output}"
            exit 1
        }

    log_success "Rollback initiated successfully"

    # Extract deployment ID
    local deployment_id=$(echo "${rollback_output}" | jq -r '.service.deployments[0].id // "N/A"')
    log_info "Deployment ID: ${deployment_id}"
}

wait_for_rollback_completion() {
    if [ "$WAIT_FOR_STABLE" != "true" ]; then
        log_info "Skipping wait for stability (WAIT_FOR_STABLE=false)"
        return 0
    fi

    log_info "Waiting for rollback to stabilize (timeout: ${TIMEOUT}s)..."

    local start_time=$(date +%s)
    local elapsed=0

    while [ $elapsed -lt $TIMEOUT ]; do
        local status=$(aws ecs describe-services \
            --cluster "${ECS_CLUSTER}" \
            --services "${ECS_SERVICE}" \
            --region "${AWS_REGION}" \
            --query 'services[0].deployments[?status==`PRIMARY`].rolloutState' \
            --output text 2>/dev/null || echo "UNKNOWN")

        if [ "$status" = "COMPLETED" ]; then
            log_success "Rollback completed successfully"
            return 0
        elif [ "$status" = "FAILED" ]; then
            log_error "Rollback failed"
            return 1
        fi

        elapsed=$(( $(date +%s) - start_time ))
        log_info "Rollback in progress... (${elapsed}s / ${TIMEOUT}s)"
        sleep 10
    done

    log_error "Rollback timeout reached (${TIMEOUT}s)"
    return 1
}

verify_rollback() {
    log_info "Verifying rollback..."

    local current_td=$(get_current_task_definition)
    local target_td="$1"

    # Extract revision numbers
    local current_revision=$(echo "$current_td" | awk -F: '{print $7}')
    local target_revision=$(echo "$target_td" | awk -F: '{print $7}')

    log_info "Current revision after rollback: ${current_revision}"
    log_info "Expected revision: ${target_revision}"

    # Check running tasks count
    local running_count=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")

    log_info "Running tasks: ${running_count}"

    if [ "$running_count" -gt 0 ]; then
        log_success "Rollback verification passed"
        return 0
    else
        log_error "Rollback verification failed: no running tasks"
        return 1
    fi
}

################################################################################
# Main Rollback Function
################################################################################

main() {
    log_info "=========================================="
    log_info "Enterprise CI/CD Rollback Starting"
    log_info "=========================================="
    log_info "Cluster: ${ECS_CLUSTER}"
    log_info "Service: ${ECS_SERVICE}"
    log_info "Region: ${AWS_REGION}"
    log_info "Dry Run: ${DRY_RUN}"
    log_info "Rollback Steps: ${ROLLBACK_STEPS}"
    log_info "Timestamp: $(date)"
    log_info "=========================================="

    # Validation
    check_prerequisites
    validate_environment

    # Get current state
    local current_td=$(get_current_task_definition)

    # Select rollback target
    local target_td=$(select_rollback_target)

    # Confirm rollback
    confirm_rollback "$current_td" "$target_td"

    # Execute rollback
    execute_rollback "$target_td"

    # Wait for completion
    if wait_for_rollback_completion; then
        log_success "Rollback stabilized"
    else
        log_error "Rollback failed to stabilize"
        exit 1
    fi

    # Verify rollback
    if verify_rollback "$target_td"; then
        log_success "Rollback verification passed"
    else
        log_error "Rollback verification failed"
        exit 1
    fi

    log_info "=========================================="
    log_success "Rollback Completed Successfully!"
    log_info "=========================================="
    log_info "Previous version: ${current_td}"
    log_info "Current version: ${target_td}"
    log_info "To revert this rollback, use:"
    log_info "  ROLLBACK_TO='${current_td}' ./scripts/rollback.sh"
    log_info "=========================================="
}

# Show help
show_help() {
    cat << EOF
Enterprise CI/CD Rollback Script

Usage: ./scripts/rollback.sh [options]

Options:
    -h, --help          Show this help message
    -d, --dry-run       Run in dry-run mode
    -y, --yes           Auto-confirm rollback (skip confirmation)
    -s, --steps N       Number of versions to rollback (default: 1)
    -t, --to ARN        Rollback to specific task definition ARN
    --no-wait           Don't wait for rollback to stabilize

Environment Variables:
    ECS_CLUSTER         ECS cluster name (required)
    ECS_SERVICE         ECS service name (required)
    AWS_REGION          AWS region (required)
    ROLLBACK_TO         Specific task definition ARN to rollback to
    ROLLBACK_STEPS      Number of versions to rollback (default: 1)
    AUTO_CONFIRM        Skip confirmation prompt (default: false)
    WAIT_FOR_STABLE     Wait for deployment to stabilize (default: true)
    TIMEOUT             Rollback timeout in seconds (default: 600)

Examples:
    # Rollback to previous version (with confirmation)
    ./scripts/rollback.sh

    # Rollback 2 versions back
    ./scripts/rollback.sh --steps 2

    # Rollback to specific task definition
    ./scripts/rollback.sh --to arn:aws:ecs:us-east-1:123456789:task-definition/app:42

    # Auto-confirm rollback (for automation)
    AUTO_CONFIRM=true ./scripts/rollback.sh

    # Dry run to see what would be rolled back
    DRY_RUN=true ./scripts/rollback.sh
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -s|--steps)
            ROLLBACK_STEPS="$2"
            shift 2
            ;;
        -t|--to)
            ROLLBACK_TO="$2"
            shift 2
            ;;
        --no-wait)
            WAIT_FOR_STABLE=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Handle script interruption
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main
