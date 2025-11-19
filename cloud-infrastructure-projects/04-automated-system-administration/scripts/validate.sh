#!/bin/bash
# Validation Script for Ansible Automation Project
# Purpose: Validate configurations, syntax, and connectivity
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
REPORT_FILE="${LOG_DIR}/validation-report-${TIMESTAMP}.txt"

# Statistics
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Create log directory
mkdir -p "${LOG_DIR}"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} $*"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC} $*"
    ((TESTS_FAILED++))
}

skip() {
    echo -e "${YELLOW}⊘ SKIP${NC} $*"
    ((TESTS_SKIPPED++))
}

# Report to file
report() {
    echo "$@" >> "${REPORT_FILE}"
}

# Header
header() {
    log ""
    log "=== $* ==="
    report ""
    report "=== $* ==="
}

# Check file exists
check_file() {
    local file="$1"
    local desc="$2"

    if [ -f "${PROJECT_DIR}/${file}" ]; then
        pass "${desc} (${file})"
        report "✓ ${desc}"
        return 0
    else
        fail "${desc} (${file})"
        report "✗ ${desc}"
        return 1
    fi
}

# Validate YAML syntax
validate_yaml() {
    local file="$1"
    local desc="$2"

    if ! command -v yamllint &> /dev/null; then
        skip "YAML validation - yamllint not installed"
        report "⊘ YAML validation skipped (yamllint not found)"
        return 0
    fi

    if yamllint -d relaxed "${PROJECT_DIR}/${file}" > /dev/null 2>&1; then
        pass "${desc} (${file})"
        report "✓ ${desc}"
        return 0
    else
        fail "${desc} (${file})"
        yamllint -d relaxed "${PROJECT_DIR}/${file}" | head -5 >> "${REPORT_FILE}"
        report "✗ ${desc}"
        return 1
    fi
}

# Check command exists
check_command() {
    local cmd="$1"
    local desc="$2"

    if command -v "$cmd" &> /dev/null; then
        pass "$desc ($(command -v $cmd))"
        report "✓ $desc"
        return 0
    else
        fail "$desc"
        report "✗ $desc"
        return 1
    fi
}

# Check directory structure
validate_structure() {
    header "Directory Structure"

    local dirs=(
        "playbooks"
        "inventory"
        "group_vars"
        "roles/common"
        "roles/web_server"
        "roles/database"
        "roles/monitoring"
        "scripts"
        "docs"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "${PROJECT_DIR}/${dir}" ]; then
            pass "Directory exists: ${dir}"
            report "✓ Directory exists: ${dir}"
        else
            fail "Directory missing: ${dir}"
            report "✗ Directory missing: ${dir}"
        fi
    done
}

# Check configuration files
validate_config_files() {
    header "Configuration Files"

    check_file "ansible.cfg" "Ansible configuration"
    check_file "requirements.txt" "Python requirements"
    check_file "requirements.yml" "Ansible Galaxy requirements"
    check_file ".env.example" "Environment example"
    check_file ".gitignore" "Git ignore rules"
}

# Check playbooks
validate_playbooks() {
    header "Playbook Files"

    local playbooks=(
        "playbooks/infrastructure-setup.yml"
        "playbooks/application-deployment.yml"
        "playbooks/security-hardening.yml"
        "playbooks/backup-restore.yml"
        "playbooks/monitoring-setup.yml"
    )

    for playbook in "${playbooks[@]}"; do
        if [ -f "${PROJECT_DIR}/${playbook}" ]; then
            pass "Playbook exists: $(basename ${playbook})"
            report "✓ Playbook exists: $(basename ${playbook})"
        else
            fail "Playbook missing: $(basename ${playbook})"
            report "✗ Playbook missing: $(basename ${playbook})"
        fi

        # Validate YAML
        validate_yaml "${playbook}" "YAML syntax: $(basename ${playbook})"
    done
}

# Check roles
validate_roles() {
    header "Ansible Roles"

    local roles=(
        "roles/common"
        "roles/web_server"
        "roles/database"
        "roles/monitoring"
    )

    for role in "${roles[@]}"; do
        local role_name=$(basename "${role}")
        if [ -d "${PROJECT_DIR}/${role}" ]; then
            pass "Role exists: ${role_name}"
            report "✓ Role exists: ${role_name}"

            # Check role structure
            if [ -f "${PROJECT_DIR}/${role}/tasks/main.yml" ]; then
                pass "Role tasks: ${role_name}"
            else
                fail "Role tasks missing: ${role_name}"
            fi

            if [ -f "${PROJECT_DIR}/${role}/defaults/main.yml" ]; then
                pass "Role defaults: ${role_name}"
            else
                fail "Role defaults missing: ${role_name}"
            fi

            if [ -f "${PROJECT_DIR}/${role}/handlers/main.yml" ]; then
                pass "Role handlers: ${role_name}"
            else
                fail "Role handlers missing: ${role_name}"
            fi
        else
            fail "Role missing: ${role_name}"
            report "✗ Role missing: ${role_name}"
        fi
    done
}

# Check scripts
validate_scripts() {
    header "Scripts"

    local scripts=(
        "scripts/bootstrap.sh"
        "scripts/deploy.sh"
        "scripts/validate.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "${PROJECT_DIR}/${script}" ]; then
            pass "Script exists: $(basename ${script})"
            report "✓ Script exists: $(basename ${script})"

            # Check if executable
            if [ -x "${PROJECT_DIR}/${script}" ]; then
                pass "Script is executable: $(basename ${script})"
            else
                fail "Script is not executable: $(basename ${script})"
            fi

            # Check shebang
            if grep -q "^#!/bin/bash" "${PROJECT_DIR}/${script}"; then
                pass "Valid shebang: $(basename ${script})"
            else
                fail "Invalid shebang: $(basename ${script})"
            fi
        else
            fail "Script missing: $(basename ${script})"
            report "✗ Script missing: $(basename ${script})"
        fi
    done
}

# Check documentation
validate_documentation() {
    header "Documentation"

    check_file "README.md" "Main README"
    check_file "docs/architecture.md" "Architecture documentation"
    check_file "docs/runbooks.md" "Operational runbooks"
    check_file "docs/troubleshooting.md" "Troubleshooting guide"
}

# Check system tools
validate_system_tools() {
    header "System Tools"

    local commands=(
        "ansible:Ansible"
        "ansible-playbook:Ansible Playbook"
        "ansible-inventory:Ansible Inventory"
        "python3:Python 3"
        "pip3:pip3"
        "git:Git"
        "ssh:SSH"
    )

    for cmd_pair in "${commands[@]}"; do
        IFS=':' read -r cmd desc <<< "$cmd_pair"
        check_command "$cmd" "$desc"
    done
}

# Validate inventory
validate_inventory() {
    header "Inventory"

    if [ -f "${PROJECT_DIR}/inventory/hosts.yml" ]; then
        pass "Inventory file exists"
        report "✓ Inventory file exists"

        if command -v ansible-inventory &> /dev/null; then
            if cd "${PROJECT_DIR}" && ansible-inventory -i inventory/hosts.yml --list > /dev/null 2>&1; then
                pass "Inventory is valid YAML"
                report "✓ Inventory is valid YAML"
            else
                fail "Inventory syntax error"
                report "✗ Inventory syntax error"
            fi
        fi
    else
        fail "Inventory file not found"
        report "✗ Inventory file not found"
    fi
}

# Check file permissions
validate_permissions() {
    header "File Permissions"

    # Check if scripts are executable
    for script in scripts/*.sh; do
        if [ -f "${script}" ]; then
            if [ -x "${script}" ]; then
                pass "Script is executable: $(basename ${script})"
            else
                fail "Script not executable: $(basename ${script})"
                report "✗ Script not executable: $(basename ${script})"
            fi
        fi
    done
}

# Generate summary report
generate_summary() {
    header "Validation Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=$((TESTS_PASSED * 100 / total))

    log ""
    log "Total Tests: ${total}"
    log "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    log "Failed: ${RED}${TESTS_FAILED}${NC}"
    log "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    log "Pass Rate: ${pass_rate}%"

    report ""
    report "=== Validation Summary ==="
    report "Total Tests: ${total}"
    report "Passed: ${TESTS_PASSED}"
    report "Failed: ${TESTS_FAILED}"
    report "Skipped: ${TESTS_SKIPPED}"
    report "Pass Rate: ${pass_rate}%"
    report "Timestamp: $(date)"

    if [ ${TESTS_FAILED} -eq 0 ]; then
        success "All validation checks passed!"
        report "Status: ALL CHECKS PASSED"
        return 0
    else
        fail "${TESTS_FAILED} validation checks failed"
        report "Status: SOME CHECKS FAILED"
        return 1
    fi
}

# Main execution
main() {
    # Initialize report
    > "${REPORT_FILE}"  # Clear file

    log "Ansible Automation Project Validation"
    log "Project Directory: ${PROJECT_DIR}"
    report "Ansible Automation Project Validation"
    report "Project Directory: ${PROJECT_DIR}"
    report "Validation Date: $(date)"

    # Run validations
    validate_structure
    validate_config_files
    validate_playbooks
    validate_roles
    validate_scripts
    validate_documentation
    validate_system_tools
    validate_inventory
    validate_permissions

    # Generate summary
    if generate_summary; then
        log ""
        log "Full report saved to: ${REPORT_FILE}"
        exit 0
    else
        log ""
        error "Validation completed with errors"
        log "Full report saved to: ${REPORT_FILE}"
        exit 1
    fi
}

# Run main
main "$@"
