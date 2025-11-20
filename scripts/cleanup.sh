#!/bin/bash
################################################################################
# Enterprise CI/CD Cleanup Script
# Purpose: Clean up Docker images, ECR repositories, and ECS resources
# Usage: ./scripts/cleanup.sh [options]
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
LOG_FILE="${PROJECT_ROOT}/cleanup.log"

# Default values
DRY_RUN="${DRY_RUN:-true}"  # Default to dry run for safety
KEEP_IMAGES="${KEEP_IMAGES:-5}"  # Keep last N images in ECR
CLEAN_LOCAL="${CLEAN_LOCAL:-true}"
CLEAN_ECR="${CLEAN_ECR:-false}"
CLEAN_ECS="${CLEAN_ECS:-false}"

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

    local required_commands=("docker" "aws" "jq")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

################################################################################
# Docker Cleanup Functions
################################################################################

cleanup_local_docker_images() {
    if [ "$CLEAN_LOCAL" != "true" ]; then
        log_info "Skipping local Docker cleanup (CLEAN_LOCAL=false)"
        return 0
    fi

    log_info "Cleaning up local Docker images..."

    # Remove dangling images
    local dangling=$(docker images -f "dangling=true" -q)
    if [ -n "$dangling" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log_warning "DRY RUN: Would remove $(echo "$dangling" | wc -l) dangling images"
        else
            log_info "Removing dangling images..."
            echo "$dangling" | xargs docker rmi -f || log_warning "Some dangling images could not be removed"
            log_success "Dangling images removed"
        fi
    else
        log_info "No dangling images found"
    fi

    # Remove old 2048 images (keep latest 3)
    local old_images=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "2048" | tail -n +4 | awk '{print $2}')
    if [ -n "$old_images" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log_warning "DRY RUN: Would remove $(echo "$old_images" | wc -l) old 2048 images"
        else
            log_info "Removing old 2048 images..."
            echo "$old_images" | xargs docker rmi -f || log_warning "Some old images could not be removed"
            log_success "Old 2048 images removed"
        fi
    else
        log_info "No old 2048 images to remove"
    fi

    # Clean up build cache
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would prune Docker build cache"
    else
        log_info "Pruning Docker build cache..."
        docker builder prune -f || log_warning "Failed to prune build cache"
        log_success "Docker build cache pruned"
    fi
}

cleanup_docker_system() {
    log_info "Running Docker system cleanup..."

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would run 'docker system prune'"
        docker system df
    else
        log_info "Running 'docker system prune -af --volumes'..."
        docker system prune -af --volumes || log_warning "Docker system prune encountered errors"
        log_success "Docker system cleanup completed"
    fi
}

################################################################################
# ECR Cleanup Functions
################################################################################

cleanup_ecr_images() {
    if [ "$CLEAN_ECR" != "true" ]; then
        log_info "Skipping ECR cleanup (CLEAN_ECR=false)"
        return 0
    fi

    if [ -z "${ECR_REPO:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "ECR_REPO or AWS_REGION not set, skipping ECR cleanup"
        return 0
    fi

    log_info "Cleaning up old ECR images (keeping last ${KEEP_IMAGES} images)..."

    # Extract repository name from ECR_REPO
    local repo_name=$(echo "${ECR_REPO}" | cut -d'/' -f2 | cut -d':' -f1)

    # Get all image digests sorted by push date
    local images=$(aws ecr describe-images \
        --repository-name "${repo_name}" \
        --region "${AWS_REGION}" \
        --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageDigest,imagePushedAt]' \
        --output text 2>/dev/null) || {
            log_warning "Failed to list ECR images (repository may not exist)"
            return 0
        }

    local total_images=$(echo "$images" | wc -l)
    log_info "Found ${total_images} images in ECR"

    if [ "$total_images" -le "$KEEP_IMAGES" ]; then
        log_info "Image count (${total_images}) is within keep limit (${KEEP_IMAGES}), nothing to clean"
        return 0
    fi

    # Calculate how many to delete
    local delete_count=$((total_images - KEEP_IMAGES))
    local images_to_delete=$(echo "$images" | head -n "$delete_count" | awk '{print $1}')

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would delete ${delete_count} old images from ECR"
        log_info "Images to delete:"
        echo "$images_to_delete" | while read -r digest; do
            log_info "  - ${digest}"
        done
    else
        log_info "Deleting ${delete_count} old images from ECR..."

        echo "$images_to_delete" | while read -r digest; do
            aws ecr batch-delete-image \
                --repository-name "${repo_name}" \
                --region "${AWS_REGION}" \
                --image-ids imageDigest="${digest}" > /dev/null || {
                    log_warning "Failed to delete image: ${digest}"
                }
        done

        log_success "ECR cleanup completed"
    fi
}

list_ecr_images() {
    if [ -z "${ECR_REPO:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "ECR_REPO or AWS_REGION not set"
        return 0
    fi

    local repo_name=$(echo "${ECR_REPO}" | cut -d'/' -f2 | cut -d':' -f1)

    log_info "Listing ECR images..."

    aws ecr describe-images \
        --repository-name "${repo_name}" \
        --region "${AWS_REGION}" \
        --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
        --output table || {
            log_warning "Failed to list ECR images"
        }
}

################################################################################
# ECS Cleanup Functions
################################################################################

cleanup_ecs_task_definitions() {
    if [ "$CLEAN_ECS" != "true" ]; then
        log_info "Skipping ECS cleanup (CLEAN_ECS=false)"
        return 0
    fi

    if [ -z "${ECS_TASK_FAMILY:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "ECS_TASK_FAMILY or AWS_REGION not set, skipping ECS cleanup"
        return 0
    fi

    log_info "Cleaning up old ECS task definitions..."

    # List all task definitions for the family
    local task_definitions=$(aws ecs list-task-definitions \
        --family-prefix "${ECS_TASK_FAMILY}" \
        --region "${AWS_REGION}" \
        --query 'taskDefinitionArns' \
        --output text) || {
            log_warning "Failed to list task definitions"
            return 0
        }

    local total_tasks=$(echo "$task_definitions" | wc -w)
    log_info "Found ${total_tasks} task definitions"

    if [ "$total_tasks" -le "$KEEP_IMAGES" ]; then
        log_info "Task definition count is within keep limit, nothing to clean"
        return 0
    fi

    # Keep latest N task definitions, deregister the rest
    local delete_count=$((total_tasks - KEEP_IMAGES))
    local tasks_to_delete=$(echo "$task_definitions" | tr ' ' '\n' | head -n "$delete_count")

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would deregister ${delete_count} old task definitions"
    else
        log_info "Deregistering ${delete_count} old task definitions..."

        echo "$tasks_to_delete" | while read -r task_arn; do
            aws ecs deregister-task-definition \
                --task-definition "${task_arn}" \
                --region "${AWS_REGION}" > /dev/null || {
                    log_warning "Failed to deregister: ${task_arn}"
                }
        done

        log_success "ECS task definitions cleanup completed"
    fi
}

cleanup_stopped_ecs_tasks() {
    if [ "$CLEAN_ECS" != "true" ]; then
        return 0
    fi

    if [ -z "${ECS_CLUSTER:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "ECS_CLUSTER or AWS_REGION not set, skipping stopped tasks cleanup"
        return 0
    fi

    log_info "Listing stopped ECS tasks..."

    local stopped_tasks=$(aws ecs list-tasks \
        --cluster "${ECS_CLUSTER}" \
        --region "${AWS_REGION}" \
        --desired-status STOPPED \
        --query 'taskArns' \
        --output text) || {
            log_warning "Failed to list stopped tasks"
            return 0
        }

    if [ -z "$stopped_tasks" ]; then
        log_info "No stopped tasks found"
        return 0
    fi

    local task_count=$(echo "$stopped_tasks" | wc -w)
    log_info "Found ${task_count} stopped tasks (AWS will auto-clean these after 1 hour)"
}

################################################################################
# Reporting Functions
################################################################################

show_cleanup_summary() {
    log_info "=========================================="
    log_info "Cleanup Summary"
    log_info "=========================================="

    # Docker disk usage
    log_info "Docker disk usage:"
    docker system df

    # ECR image count
    if [ -n "${ECR_REPO:-}" ] && [ -n "${AWS_REGION:-}" ]; then
        local repo_name=$(echo "${ECR_REPO}" | cut -d'/' -f2 | cut -d':' -f1)
        local ecr_count=$(aws ecr describe-images \
            --repository-name "${repo_name}" \
            --region "${AWS_REGION}" \
            --query 'length(imageDetails)' \
            --output text 2>/dev/null || echo "N/A")
        log_info "ECR images remaining: ${ecr_count}"
    fi

    log_info "=========================================="
}

################################################################################
# Main Cleanup Function
################################################################################

main() {
    log_info "=========================================="
    log_info "Enterprise CI/CD Cleanup Starting"
    log_info "=========================================="
    log_info "Dry Run: ${DRY_RUN}"
    log_info "Clean Local: ${CLEAN_LOCAL}"
    log_info "Clean ECR: ${CLEAN_ECR}"
    log_info "Clean ECS: ${CLEAN_ECS}"
    log_info "Keep Images: ${KEEP_IMAGES}"
    log_info "Timestamp: $(date)"
    log_info "=========================================="

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "Running in DRY RUN mode - no resources will be deleted"
        log_warning "Set DRY_RUN=false to perform actual cleanup"
    fi

    check_prerequisites

    # Local Docker cleanup
    cleanup_local_docker_images

    # ECR cleanup
    cleanup_ecr_images

    # ECS cleanup
    cleanup_ecs_task_definitions
    cleanup_stopped_ecs_tasks

    # Show summary
    show_cleanup_summary

    log_info "=========================================="
    log_success "Cleanup Completed!"
    log_info "=========================================="
}

# Show help
show_help() {
    cat << EOF
Enterprise CI/CD Cleanup Script

Usage: ./scripts/cleanup.sh [options]

Options:
    -h, --help          Show this help message
    -d, --dry-run       Run in dry-run mode (default: true)
    -f, --force         Run actual cleanup (set DRY_RUN=false)
    --clean-local       Clean local Docker images (default: true)
    --clean-ecr         Clean ECR images (default: false)
    --clean-ecs         Clean ECS task definitions (default: false)
    --keep N            Keep last N images (default: 5)

Environment Variables:
    DRY_RUN            Set to 'false' to perform actual cleanup
    CLEAN_LOCAL        Clean local Docker resources
    CLEAN_ECR          Clean ECR repository
    CLEAN_ECS          Clean ECS task definitions
    KEEP_IMAGES        Number of images to keep
    ECR_REPO           ECR repository URI
    AWS_REGION         AWS region
    ECS_CLUSTER        ECS cluster name
    ECS_TASK_FAMILY    ECS task definition family

Examples:
    # Dry run (default)
    ./scripts/cleanup.sh

    # Clean local Docker only
    DRY_RUN=false ./scripts/cleanup.sh

    # Clean everything, keep last 10 images
    DRY_RUN=false CLEAN_ECR=true CLEAN_ECS=true KEEP_IMAGES=10 ./scripts/cleanup.sh

    # List ECR images
    ./scripts/cleanup.sh --list-ecr
EOF
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            DRY_RUN=false
            ;;
        --list-ecr)
            list_ecr_images
            exit 0
            ;;
    esac
done

# Handle script interruption
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main
