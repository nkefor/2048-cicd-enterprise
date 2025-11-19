#!/bin/bash
# Deployment Script for Ansible Automation
# Purpose: Execute deployment playbooks with safety checks
# Updated: 2025-11-19

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deploy-${TIMESTAMP}.log"

# Default values
PLAYBOOK=""
INVENTORY="inventory/hosts.yml"
LIMIT=""
CHECK_MODE=false
VERBOSE=""
TAGS=""
SKIP_TAGS=""
EXTRA_VARS=""
ASK_BECOME_PASS=false

# Create log directory
mkdir -p "${LOG_DIR}"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 -p PLAYBOOK [OPTIONS]

Required:
  -p, --playbook PLAYBOOK    Playbook to run (infrastructure-setup,
                              application-deployment, security-hardening,
                              backup-restore, monitoring-setup)

Options:
  -i, --inventory FILE       Inventory file (default: inventory/hosts.yml)
  -l, --limit PATTERN        Limit playbook to hosts/groups
  -c, --check                Run in check mode (dry-run)
  -v, --verbose              Increase verbosity
  -t, --tags TAGS            Only run tasks with specific tags
  -s, --skip-tags TAGS       Skip tasks with specific tags
  -e, --extra-vars VARS      Extra variables (JSON format)
  -b, --ask-become-pass      Ask for become password
  -h, --help                 Show this help message

Examples:
  $0 -p infrastructure-setup
  $0 -p application-deployment -l webservers --check
  $0 -p security-hardening --tags ssh -l production
  $0 -p backup-restore --tags backup --ask-become-pass

EOF
    exit 0
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--playbook)
                PLAYBOOK="$2"
                shift 2
                ;;
            -i|--inventory)
                INVENTORY="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -c|--check)
                CHECK_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE="-vv"
                shift
                ;;
            -t|--tags)
                TAGS="$2"
                shift 2
                ;;
            -s|--skip-tags)
                SKIP_TAGS="$2"
                shift 2
                ;;
            -e|--extra-vars)
                EXTRA_VARS="$2"
                shift 2
                ;;
            -b|--ask-become-pass)
                ASK_BECOME_PASS=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate playbook
    if [ -z "${PLAYBOOK}" ]; then
        error "Playbook is required"
        usage
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."

    # Check Ansible installation
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible not found"
        exit 1
    fi

    # Check inventory
    if [ ! -f "${PROJECT_DIR}/${INVENTORY}" ]; then
        error "Inventory file not found: ${INVENTORY}"
        exit 1
    fi

    # Check playbook
    if [ ! -f "${PROJECT_DIR}/playbooks/${PLAYBOOK}.yml" ]; then
        error "Playbook not found: playbooks/${PLAYBOOK}.yml"
        exit 1
    fi

    # Validate inventory syntax
    cd "${PROJECT_DIR}"
    if ! ansible-inventory -i "${INVENTORY}" --list > /dev/null 2>&1; then
        error "Inventory validation failed"
        exit 1
    fi

    # Test connectivity
    log "Testing connectivity to managed hosts..."
    if ! ansible all -i "${INVENTORY}" -m ping ${LIMIT:+-l $LIMIT} --quiet 2>/dev/null; then
        warning "Some hosts may not be reachable"
    fi

    success "Pre-deployment checks completed"
}

# Build ansible-playbook command
build_command() {
    local cmd="ansible-playbook"

    # Playbook path
    cmd+=" playbooks/${PLAYBOOK}.yml"

    # Inventory
    cmd+=" -i ${INVENTORY}"

    # Limit
    if [ -n "${LIMIT}" ]; then
        cmd+=" -l ${LIMIT}"
    fi

    # Check mode
    if [ "${CHECK_MODE}" = true ]; then
        cmd+=" --check"
    fi

    # Verbosity
    if [ -n "${VERBOSE}" ]; then
        cmd+=" ${VERBOSE}"
    fi

    # Tags
    if [ -n "${TAGS}" ]; then
        cmd+=" -t ${TAGS}"
    fi

    # Skip tags
    if [ -n "${SKIP_TAGS}" ]; then
        cmd+=" --skip-tags=${SKIP_TAGS}"
    fi

    # Extra variables
    if [ -n "${EXTRA_VARS}" ]; then
        cmd+=" -e '${EXTRA_VARS}'"
    fi

    # Ask for become password
    if [ "${ASK_BECOME_PASS}" = true ]; then
        cmd+=" --ask-become-pass"
    fi

    echo "${cmd}"
}

# Display deployment info
display_deployment_info() {
    cat << EOF

${BLUE}=== Deployment Configuration ===${NC}
Playbook: ${PLAYBOOK}
Inventory: ${INVENTORY}
Limit: ${LIMIT:-all}
Check Mode: ${CHECK_MODE}
Tags: ${TAGS:-all}
Skip Tags: ${SKIP_TAGS:-none}
Extra Variables: ${EXTRA_VARS:-none}

${BLUE}Deployment Log: ${LOG_FILE}${NC}

EOF

    if [ "${CHECK_MODE}" = true ]; then
        warning "Running in CHECK MODE (dry-run) - no changes will be made"
        echo ""
    fi
}

# Execute deployment
execute_deployment() {
    log "Starting deployment..."

    cd "${PROJECT_DIR}"

    # Build command
    local cmd=$(build_command)

    # Log command
    log "Executing: ${cmd}"

    # Execute
    if eval "${cmd}" 2>&1 | tee -a "${LOG_FILE}"; then
        success "Deployment completed successfully"
        return 0
    else
        error "Deployment failed"
        return 1
    fi
}

# Post-deployment actions
post_deployment() {
    log "Running post-deployment actions..."

    if [ "${CHECK_MODE}" != true ]; then
        # Log summary
        cat >> "${LOG_FILE}" << EOF

Deployment Summary:
- Timestamp: ${TIMESTAMP}
- Playbook: ${PLAYBOOK}
- Inventory: ${INVENTORY}
- Status: COMPLETED

EOF

        success "Deployment log saved to: ${LOG_FILE}"
    else
        log "Check mode completed - no changes made"
    fi
}

# Main execution
main() {
    log "Ansible Deployment Script"
    log "Started at: $(date)"

    # Parse arguments
    parse_arguments "$@"

    # Display deployment info
    display_deployment_info

    # Pre-deployment checks
    pre_deployment_checks

    # Ask for confirmation
    if [ "${CHECK_MODE}" != true ]; then
        echo -e "${YELLOW}This will execute the ${PLAYBOOK} playbook.${NC}"
        read -p "Continue? (yes/no) " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi

    # Execute deployment
    if execute_deployment; then
        post_deployment
        success "Deployment finished successfully!"
        exit 0
    else
        error "Deployment failed"
        exit 1
    fi
}

# Run main
main "$@"
