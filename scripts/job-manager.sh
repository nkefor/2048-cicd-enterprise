#!/bin/bash
################################################################################
# Enterprise CI/CD Job Manager
# Purpose: Orchestrate and manage all CI/CD automation jobs
# Usage: ./scripts/job-manager.sh [command] [options]
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
JOB_LOG_FILE="${LOG_DIR}/job-manager.log"

# Job tracking
JOBS_RUNNING=()
JOBS_COMPLETED=()
JOBS_FAILED=()

# Default configuration
PARALLEL="${PARALLEL:-false}"
VERBOSE="${VERBOSE:-false}"
ENVIRONMENT="${ENVIRONMENT:-production}"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${JOB_LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${JOB_LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${JOB_LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${JOB_LOG_FILE}"
}

log_job() {
    echo -e "${CYAN}[JOB]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${JOB_LOG_FILE}"
}

################################################################################
# Initialization Functions
################################################################################

initialize() {
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"

    log_info "=========================================="
    log_info "Enterprise CI/CD Job Manager"
    log_info "=========================================="
    log_info "Version: 1.0.0"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Timestamp: $(date)"
    log_info "=========================================="
}

check_script_exists() {
    local script="$1"
    local script_path="${SCRIPT_DIR}/${script}"

    if [ ! -f "$script_path" ]; then
        log_error "Script not found: ${script}"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        log_warning "Script not executable, making executable: ${script}"
        chmod +x "$script_path"
    fi

    return 0
}

################################################################################
# Job Execution Functions
################################################################################

run_job() {
    local job_name="$1"
    local script_name="$2"
    shift 2
    local args="$@"

    log_job "Starting job: ${job_name}"

    if ! check_script_exists "$script_name"; then
        log_error "Job failed: ${job_name} (script not found)"
        JOBS_FAILED+=("$job_name")
        return 1
    fi

    local script_path="${SCRIPT_DIR}/${script_name}"
    local job_log="${LOG_DIR}/${job_name}-$(date +%Y%m%d-%H%M%S).log"

    log_info "Executing: ${script_path} ${args}"
    log_info "Log file: ${job_log}"

    # Execute the job
    if bash "$script_path" $args > "$job_log" 2>&1; then
        log_success "Job completed: ${job_name}"
        JOBS_COMPLETED+=("$job_name")
        return 0
    else
        log_error "Job failed: ${job_name}"
        log_error "Check log file: ${job_log}"
        JOBS_FAILED+=("$job_name")
        return 1
    fi
}

run_job_async() {
    local job_name="$1"
    shift

    log_job "Starting async job: ${job_name}"
    JOBS_RUNNING+=("$job_name")

    run_job "$@" &
    local pid=$!

    log_info "Job ${job_name} running in background (PID: ${pid})"
    echo "$pid"
}

wait_for_jobs() {
    log_info "Waiting for all jobs to complete..."

    wait

    log_info "All jobs finished"
}

################################################################################
# Pipeline Functions
################################################################################

pipeline_full_deploy() {
    log_info "=========================================="
    log_info "Running Full Deployment Pipeline"
    log_info "=========================================="

    local start_time=$(date +%s)

    # Step 1: Deploy
    if run_job "deploy" "deploy.sh" "$ENVIRONMENT"; then
        log_success "Deployment successful"
    else
        log_error "Deployment failed, aborting pipeline"
        return 1
    fi

    # Step 2: Health Check
    if run_job "health-check" "health-check.sh"; then
        log_success "Health check passed"
    else
        log_error "Health check failed, initiating rollback"

        # Automatic rollback on health check failure
        if run_job "rollback" "rollback.sh" "-y"; then
            log_warning "Rollback successful after health check failure"
        else
            log_error "Rollback failed - manual intervention required"
        fi
        return 1
    fi

    # Step 3: Optional cleanup
    if [ "${AUTO_CLEANUP:-false}" = "true" ]; then
        run_job "cleanup" "cleanup.sh" || log_warning "Cleanup encountered errors (non-fatal)"
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "=========================================="
    log_success "Full Deployment Pipeline Completed"
    log_success "Duration: ${duration}s"
    log_success "=========================================="
}

pipeline_deploy_and_monitor() {
    log_info "=========================================="
    log_info "Running Deploy & Monitor Pipeline"
    log_info "=========================================="

    # Deploy in background
    local deploy_pid=$(run_job_async "deploy" "deploy" "deploy.sh" "$ENVIRONMENT")

    # Wait for deploy to complete
    wait "$deploy_pid" || {
        log_error "Deployment failed"
        return 1
    }

    # Start continuous health monitoring
    log_info "Starting continuous health monitoring..."
    CONTINUOUS=true CHECK_INTERVAL=30 bash "${SCRIPT_DIR}/health-check.sh" &
    local monitor_pid=$!

    log_info "Health monitoring running (PID: ${monitor_pid})"
    log_info "To stop monitoring: kill ${monitor_pid}"
}

pipeline_blue_green() {
    log_info "=========================================="
    log_info "Running Blue-Green Deployment Pipeline"
    log_info "=========================================="

    log_warning "Blue-green deployment is a placeholder for future implementation"
    log_info "This would involve:"
    log_info "  1. Deploy to 'green' environment"
    log_info "  2. Run smoke tests on green"
    log_info "  3. Switch traffic from blue to green"
    log_info "  4. Monitor green environment"
    log_info "  5. Decommission blue on success, rollback on failure"
}

################################################################################
# Job Management Commands
################################################################################

cmd_deploy() {
    log_info "Deploying application..."
    run_job "deploy" "deploy.sh" "$@"
}

cmd_rollback() {
    log_info "Rolling back deployment..."
    run_job "rollback" "rollback.sh" "$@"
}

cmd_health_check() {
    log_info "Running health check..."
    run_job "health-check" "health-check.sh" "$@"
}

cmd_cleanup() {
    log_info "Running cleanup..."
    run_job "cleanup" "cleanup.sh" "$@"
}

cmd_status() {
    log_info "=========================================="
    log_info "Job Status Report"
    log_info "=========================================="

    # ECS service status
    if [ -n "${ECS_CLUSTER:-}" ] && [ -n "${ECS_SERVICE:-}" ] && [ -n "${AWS_REGION:-}" ]; then
        log_info "Checking ECS service status..."

        local service_info=$(aws ecs describe-services \
            --cluster "${ECS_CLUSTER}" \
            --services "${ECS_SERVICE}" \
            --region "${AWS_REGION}" \
            --output json 2>/dev/null) || {
                log_warning "Failed to get ECS service status"
                return 1
            }

        local running=$(echo "$service_info" | jq -r '.services[0].runningCount // 0')
        local desired=$(echo "$service_info" | jq -r '.services[0].desiredCount // 0')
        local deployment_count=$(echo "$service_info" | jq -r '.services[0].deployments | length')

        log_info "ECS Service: ${ECS_SERVICE}"
        log_info "  Cluster: ${ECS_CLUSTER}"
        log_info "  Running Tasks: ${running}/${desired}"
        log_info "  Active Deployments: ${deployment_count}"
    else
        log_warning "ECS environment variables not set"
    fi

    # Recent jobs
    log_info ""
    log_info "Recent Job Logs:"
    if [ -d "$LOG_DIR" ]; then
        ls -lht "${LOG_DIR}" | head -10
    else
        log_info "No job logs found"
    fi

    log_info "=========================================="
}

cmd_logs() {
    local job_name="${1:-}"

    log_info "=========================================="
    log_info "Job Logs"
    log_info "=========================================="

    if [ -z "$job_name" ]; then
        log_info "Available log files:"
        if [ -d "$LOG_DIR" ]; then
            ls -lht "${LOG_DIR}"
        else
            log_info "No logs found"
        fi
    else
        log_info "Showing logs for: ${job_name}"
        local latest_log=$(ls -t "${LOG_DIR}/${job_name}"*.log 2>/dev/null | head -1)

        if [ -n "$latest_log" ]; then
            tail -n 50 "$latest_log"
        else
            log_error "No logs found for job: ${job_name}"
        fi
    fi
}

cmd_list() {
    log_info "=========================================="
    log_info "Available Jobs"
    log_info "=========================================="

    echo ""
    echo -e "${GREEN}Deployment Jobs:${NC}"
    echo "  deploy          - Deploy application to ECS"
    echo "  rollback        - Rollback to previous version"
    echo ""
    echo -e "${GREEN}Monitoring Jobs:${NC}"
    echo "  health-check    - Check application health"
    echo "  status          - Show current status"
    echo ""
    echo -e "${GREEN}Maintenance Jobs:${NC}"
    echo "  cleanup         - Clean up old images and resources"
    echo ""
    echo -e "${GREEN}Pipeline Jobs:${NC}"
    echo "  full-deploy     - Full deployment pipeline (deploy + health check)"
    echo "  deploy-monitor  - Deploy and start continuous monitoring"
    echo "  blue-green      - Blue-green deployment (future)"
    echo ""
    echo -e "${GREEN}Management Commands:${NC}"
    echo "  status          - Show current system status"
    echo "  logs [job]      - View job logs"
    echo "  list            - List all available jobs"
    echo "  help            - Show help message"
    echo ""
}

################################################################################
# Help and Usage
################################################################################

show_help() {
    cat << EOF
Enterprise CI/CD Job Manager

Usage: ./scripts/job-manager.sh [command] [options]

Commands:
    deploy              Deploy application
    rollback            Rollback deployment
    health-check        Run health checks
    cleanup             Clean up resources
    status              Show system status
    logs [job]          View job logs
    list                List all available jobs

Pipeline Commands:
    full-deploy         Run full deployment pipeline
    deploy-monitor      Deploy and start monitoring
    blue-green          Blue-green deployment (future)

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -e, --env ENV       Set environment (default: production)
    --parallel          Run jobs in parallel where possible

Environment Variables:
    ENVIRONMENT         Deployment environment (default: production)
    ECS_CLUSTER         ECS cluster name
    ECS_SERVICE         ECS service name
    AWS_REGION          AWS region
    ECR_REPO            ECR repository URI
    ALB_DNS_NAME        Load balancer DNS name
    TARGET_GROUP_ARN    ALB target group ARN
    PARALLEL            Enable parallel execution
    AUTO_CLEANUP        Auto cleanup after deployment

Examples:
    # Deploy to production
    ./scripts/job-manager.sh deploy

    # Run full deployment pipeline
    ./scripts/job-manager.sh full-deploy

    # Check system status
    ./scripts/job-manager.sh status

    # View deploy job logs
    ./scripts/job-manager.sh logs deploy

    # Rollback with confirmation
    ./scripts/job-manager.sh rollback

    # Deploy with auto cleanup
    AUTO_CLEANUP=true ./scripts/job-manager.sh full-deploy

    # Deploy and monitor continuously
    ./scripts/job-manager.sh deploy-monitor

For more information on specific jobs, run:
    ./scripts/[job-name].sh --help
EOF
}

################################################################################
# Main Function
################################################################################

main() {
    initialize

    local command="${1:-help}"
    shift || true

    case "$command" in
        deploy)
            cmd_deploy "$@"
            ;;
        rollback)
            cmd_rollback "$@"
            ;;
        health-check|health)
            cmd_health_check "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs "$@"
            ;;
        list)
            cmd_list
            ;;
        full-deploy|pipeline)
            pipeline_full_deploy
            ;;
        deploy-monitor)
            pipeline_deploy_and_monitor
            ;;
        blue-green)
            pipeline_blue_green
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Parse global options
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Handle script interruption
trap 'log_warning "Job manager interrupted"; exit 130' INT TERM

# Run main function
main "$@"
