#!/bin/bash
################################################################################
# Enterprise CI/CD Health Check Script
# Purpose: Monitor application health, ECS service status, and infrastructure
# Usage: ./scripts/health-check.sh [options]
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
LOG_FILE="${PROJECT_ROOT}/health-check.log"

# Default values
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"  # Check every 60 seconds
MAX_RETRIES="${MAX_RETRIES:-3}"
TIMEOUT="${TIMEOUT:-10}"
CONTINUOUS="${CONTINUOUS:-false}"
ALERT_ON_FAILURE="${ALERT_ON_FAILURE:-false}"

# Health status
HEALTH_STATUS="UNKNOWN"
FAILED_CHECKS=0

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
# HTTP Health Check Functions
################################################################################

check_http_endpoint() {
    local endpoint="${1:-}"
    local expected_status="${2:-200}"

    if [ -z "$endpoint" ]; then
        log_warning "No HTTP endpoint specified, skipping HTTP check"
        return 2  # Skip
    fi

    log_info "Checking HTTP endpoint: ${endpoint}"

    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        attempt=$((attempt + 1))

        # Make HTTP request
        local response_code=$(curl -sf -o /dev/null -w "%{http_code}" \
            --max-time "$TIMEOUT" \
            --connect-timeout 5 \
            "${endpoint}" 2>/dev/null || echo "000")

        if [ "$response_code" -eq "$expected_status" ]; then
            log_success "HTTP check passed (Status: ${response_code})"
            return 0
        else
            log_warning "HTTP check failed (Status: ${response_code}, Expected: ${expected_status}) - Attempt ${attempt}/${MAX_RETRIES}"

            if [ $attempt -lt $MAX_RETRIES ]; then
                sleep 2
            fi
        fi
    done

    log_error "HTTP check failed after ${MAX_RETRIES} attempts"
    return 1
}

check_http_response_time() {
    local endpoint="${1:-}"

    if [ -z "$endpoint" ]; then
        return 2  # Skip
    fi

    log_info "Measuring HTTP response time..."

    local response_time=$(curl -sf -o /dev/null -w "%{time_total}" \
        --max-time "$TIMEOUT" \
        "${endpoint}" 2>/dev/null || echo "999")

    local response_ms=$(echo "$response_time * 1000" | bc -l | cut -d'.' -f1)

    if [ "$response_ms" -lt 1000 ]; then
        log_success "Response time: ${response_ms}ms (Good)"
        return 0
    elif [ "$response_ms" -lt 3000 ]; then
        log_warning "Response time: ${response_ms}ms (Acceptable)"
        return 0
    else
        log_error "Response time: ${response_ms}ms (Slow)"
        return 1
    fi
}

################################################################################
# ECS Health Check Functions
################################################################################

check_ecs_service_health() {
    if [ -z "${ECS_CLUSTER:-}" ] || [ -z "${ECS_SERVICE:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "ECS variables not set, skipping ECS health check"
        return 2  # Skip
    fi

    log_info "Checking ECS service health..."

    # Get service details
    local service_info=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --query 'services[0]' \
        --output json 2>/dev/null) || {
            log_error "Failed to describe ECS service"
            return 1
        }

    # Extract key metrics
    local running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
    local desired_count=$(echo "$service_info" | jq -r '.desiredCount // 0')
    local pending_count=$(echo "$service_info" | jq -r '.pendingCount // 0')
    local deployment_count=$(echo "$service_info" | jq -r '.deployments | length')

    log_info "ECS Service Status:"
    log_info "  - Running tasks: ${running_count}"
    log_info "  - Desired tasks: ${desired_count}"
    log_info "  - Pending tasks: ${pending_count}"
    log_info "  - Active deployments: ${deployment_count}"

    # Check if service is healthy
    if [ "$running_count" -eq "$desired_count" ] && [ "$running_count" -gt 0 ]; then
        log_success "ECS service is healthy"
        return 0
    elif [ "$running_count" -lt "$desired_count" ]; then
        log_warning "ECS service is scaling (Running: ${running_count}, Desired: ${desired_count})"
        return 1
    elif [ "$running_count" -eq 0 ]; then
        log_error "ECS service has no running tasks!"
        return 1
    else
        log_warning "ECS service in unknown state"
        return 1
    fi
}

check_ecs_task_health() {
    if [ -z "${ECS_CLUSTER:-}" ] || [ -z "${ECS_SERVICE:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        return 2  # Skip
    fi

    log_info "Checking ECS task health..."

    # Get task ARNs
    local task_arns=$(aws ecs list-tasks \
        --cluster "${ECS_CLUSTER}" \
        --service-name "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output text 2>/dev/null) || {
            log_error "Failed to list ECS tasks"
            return 1
        }

    if [ -z "$task_arns" ]; then
        log_error "No running tasks found"
        return 1
    fi

    # Describe tasks
    local task_info=$(aws ecs describe-tasks \
        --cluster "${ECS_CLUSTER}" \
        --tasks $task_arns \
        --region "${AWS_REGION}" \
        --output json 2>/dev/null) || {
            log_error "Failed to describe ECS tasks"
            return 1
        }

    # Check task health
    local unhealthy_tasks=$(echo "$task_info" | jq -r '[.tasks[] | select(.healthStatus == "UNHEALTHY")] | length')
    local healthy_tasks=$(echo "$task_info" | jq -r '[.tasks[] | select(.healthStatus == "HEALTHY")] | length')
    local total_tasks=$(echo "$task_info" | jq -r '.tasks | length')

    log_info "Task Health Status:"
    log_info "  - Healthy: ${healthy_tasks}"
    log_info "  - Unhealthy: ${unhealthy_tasks}"
    log_info "  - Total: ${total_tasks}"

    if [ "$unhealthy_tasks" -gt 0 ]; then
        log_error "Found ${unhealthy_tasks} unhealthy tasks"
        return 1
    else
        log_success "All tasks are healthy"
        return 0
    fi
}

check_ecs_deployment_status() {
    if [ -z "${ECS_CLUSTER:-}" ] || [ -z "${ECS_SERVICE:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        return 2  # Skip
    fi

    log_info "Checking ECS deployment status..."

    local deployments=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${AWS_REGION}" \
        --query 'services[0].deployments' \
        --output json 2>/dev/null) || {
            log_error "Failed to get deployment status"
            return 1
        }

    local deployment_count=$(echo "$deployments" | jq 'length')
    local primary_status=$(echo "$deployments" | jq -r '.[] | select(.status == "PRIMARY") | .rolloutState // "UNKNOWN"')

    log_info "Deployment Status: ${primary_status}"

    if [ "$primary_status" = "COMPLETED" ]; then
        log_success "Deployment is stable"
        return 0
    elif [ "$primary_status" = "IN_PROGRESS" ]; then
        log_warning "Deployment in progress"
        return 1
    elif [ "$primary_status" = "FAILED" ]; then
        log_error "Deployment has failed"
        return 1
    else
        log_warning "Deployment status unknown"
        return 1
    fi
}

################################################################################
# ALB Health Check Functions
################################################################################

check_alb_target_health() {
    if [ -z "${TARGET_GROUP_ARN:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_warning "TARGET_GROUP_ARN not set, skipping ALB health check"
        return 2  # Skip
    fi

    log_info "Checking ALB target health..."

    local targets=$(aws elbv2 describe-target-health \
        --target-group-arn "${TARGET_GROUP_ARN}" \
        --region "${AWS_REGION}" \
        --output json 2>/dev/null) || {
            log_error "Failed to describe target health"
            return 1
        }

    local healthy=$(echo "$targets" | jq -r '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    local unhealthy=$(echo "$targets" | jq -r '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "unhealthy")] | length')
    local total=$(echo "$targets" | jq -r '.TargetHealthDescriptions | length')

    log_info "ALB Target Health:"
    log_info "  - Healthy: ${healthy}"
    log_info "  - Unhealthy: ${unhealthy}"
    log_info "  - Total: ${total}"

    if [ "$healthy" -gt 0 ] && [ "$unhealthy" -eq 0 ]; then
        log_success "All ALB targets are healthy"
        return 0
    elif [ "$healthy" -gt 0 ]; then
        log_warning "Some ALB targets are unhealthy (${unhealthy}/${total})"
        return 1
    else
        log_error "No healthy ALB targets!"
        return 1
    fi
}

################################################################################
# CloudWatch Metrics Check
################################################################################

check_cloudwatch_metrics() {
    if [ -z "${AWS_REGION:-}" ]; then
        return 2  # Skip
    fi

    log_info "Checking CloudWatch metrics..."

    # Get CPU utilization (last 5 minutes)
    local cpu_util=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name CPUUtilization \
        --dimensions Name=ServiceName,Value="${ECS_SERVICE}" Name=ClusterName,Value="${ECS_CLUSTER}" \
        --start-time "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 300 \
        --statistics Average \
        --region "${AWS_REGION}" \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")

    # Get memory utilization
    local mem_util=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name MemoryUtilization \
        --dimensions Name=ServiceName,Value="${ECS_SERVICE}" Name=ClusterName,Value="${ECS_CLUSTER}" \
        --start-time "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 300 \
        --statistics Average \
        --region "${AWS_REGION}" \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")

    log_info "Resource Utilization:"
    log_info "  - CPU: ${cpu_util}%"
    log_info "  - Memory: ${mem_util}%"

    # Basic threshold checks
    if [ "$cpu_util" != "N/A" ] && [ "$cpu_util" != "None" ]; then
        local cpu_int=$(echo "$cpu_util" | cut -d'.' -f1)
        if [ "$cpu_int" -gt 80 ]; then
            log_warning "High CPU utilization: ${cpu_util}%"
        fi
    fi

    return 0
}

################################################################################
# Comprehensive Health Check
################################################################################

run_all_health_checks() {
    log_info "=========================================="
    log_info "Running Comprehensive Health Checks"
    log_info "=========================================="
    log_info "Timestamp: $(date)"
    log_info "=========================================="

    local checks_passed=0
    local checks_failed=0
    local checks_skipped=0

    # HTTP endpoint check
    if check_http_endpoint "${ALB_DNS_NAME:-http://localhost}"; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # HTTP response time check
    if check_http_response_time "${ALB_DNS_NAME:-}"; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # ECS service health
    if check_ecs_service_health; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # ECS task health
    if check_ecs_task_health; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # ECS deployment status
    if check_ecs_deployment_status; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # ALB target health
    if check_alb_target_health; then
        checks_passed=$((checks_passed + 1))
    elif [ $? -eq 2 ]; then
        checks_skipped=$((checks_skipped + 1))
    else
        checks_failed=$((checks_failed + 1))
    fi

    # CloudWatch metrics
    check_cloudwatch_metrics

    # Summary
    log_info "=========================================="
    log_info "Health Check Summary"
    log_info "=========================================="
    log_info "Passed: ${checks_passed}"
    log_info "Failed: ${checks_failed}"
    log_info "Skipped: ${checks_skipped}"
    log_info "=========================================="

    if [ $checks_failed -gt 0 ]; then
        HEALTH_STATUS="UNHEALTHY"
        log_error "Overall Status: UNHEALTHY"
        return 1
    elif [ $checks_passed -gt 0 ]; then
        HEALTH_STATUS="HEALTHY"
        log_success "Overall Status: HEALTHY"
        return 0
    else
        HEALTH_STATUS="UNKNOWN"
        log_warning "Overall Status: UNKNOWN"
        return 2
    fi
}

################################################################################
# Main Function
################################################################################

main() {
    if [ "$CONTINUOUS" = "true" ]; then
        log_info "Starting continuous health monitoring (interval: ${CHECK_INTERVAL}s)"
        log_info "Press Ctrl+C to stop"

        while true; do
            run_all_health_checks || true
            sleep "$CHECK_INTERVAL"
        done
    else
        run_all_health_checks
        exit $?
    fi
}

# Show help
show_help() {
    cat << EOF
Enterprise CI/CD Health Check Script

Usage: ./scripts/health-check.sh [options]

Options:
    -h, --help          Show this help message
    -c, --continuous    Run continuous health monitoring
    -i, --interval N    Check interval in seconds (default: 60)
    -r, --retries N     Max retries for HTTP checks (default: 3)
    -t, --timeout N     Request timeout in seconds (default: 10)

Environment Variables:
    ALB_DNS_NAME        Load balancer DNS name or endpoint URL
    ECS_CLUSTER         ECS cluster name
    ECS_SERVICE         ECS service name
    TARGET_GROUP_ARN    ALB target group ARN
    AWS_REGION          AWS region

Examples:
    # Single health check
    ./scripts/health-check.sh

    # Continuous monitoring every 30 seconds
    CONTINUOUS=true CHECK_INTERVAL=30 ./scripts/health-check.sh

    # Check specific endpoint
    ALB_DNS_NAME=http://my-alb-123456.us-east-1.elb.amazonaws.com ./scripts/health-check.sh
EOF
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--continuous)
            CONTINUOUS=true
            ;;
    esac
done

# Handle script interruption
trap 'log_info "Health monitoring stopped"; exit 0' INT TERM

# Run main function
main
