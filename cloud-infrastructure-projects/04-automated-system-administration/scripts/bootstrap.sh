#!/bin/bash
# Bootstrap Script for Ansible Automation
# Purpose: Initialize the Ansible control environment
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
LOG_FILE="${LOG_DIR}/bootstrap-${TIMESTAMP}.log"

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

# Check requirements
check_requirements() {
    log "Checking system requirements..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed"
        exit 1
    fi
    log "Python 3: $(python3 --version)"

    # Check pip
    if ! command -v pip3 &> /dev/null; then
        error "pip3 is not installed"
        exit 1
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
        exit 1
    fi
    log "Git: $(git --version)"

    success "All system requirements met"
}

# Create Python virtual environment
setup_virtualenv() {
    log "Setting up Python virtual environment..."

    if [ -d "${PROJECT_DIR}/venv" ]; then
        warning "Virtual environment already exists, skipping creation"
    else
        python3 -m venv "${PROJECT_DIR}/venv"
        success "Virtual environment created"
    fi

    # Activate virtual environment
    source "${PROJECT_DIR}/venv/bin/activate"
    log "Virtual environment activated"

    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    success "pip upgraded"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."

    source "${PROJECT_DIR}/venv/bin/activate"

    if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
        pip install -r "${PROJECT_DIR}/requirements.txt"
        success "Python dependencies installed"
    else
        error "requirements.txt not found"
        exit 1
    fi
}

# Setup SSH keys
setup_ssh() {
    log "Setting up SSH configuration..."

    SSH_DIR="${HOME}/.ssh"
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"

    if [ ! -f "${SSH_DIR}/id_rsa" ]; then
        warning "SSH key not found at ${SSH_DIR}/id_rsa"
        log "Generating new SSH key..."
        ssh-keygen -t rsa -b 4096 -f "${SSH_DIR}/id_rsa" -N "" -C "ansible@localhost"
        success "SSH key generated"
    else
        log "SSH key already exists"
    fi

    # Update SSH config
    if [ ! -f "${SSH_DIR}/config" ]; then
        cat > "${SSH_DIR}/config" << 'EOF'
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 600
EOF
        chmod 600 "${SSH_DIR}/config"
        success "SSH config created"
    fi
}

# Configure Ansible
setup_ansible() {
    log "Configuring Ansible..."

    source "${PROJECT_DIR}/venv/bin/activate"

    # Verify Ansible installation
    if ! command -v ansible &> /dev/null; then
        error "Ansible not found in virtual environment"
        exit 1
    fi

    log "Ansible: $(ansible --version | head -1)"

    # Create inventory backup
    if [ -f "${PROJECT_DIR}/inventory/hosts.yml" ]; then
        cp "${PROJECT_DIR}/inventory/hosts.yml" "${PROJECT_DIR}/inventory/hosts.yml.bak"
        log "Inventory backup created"
    fi

    # Test Ansible configuration
    cd "${PROJECT_DIR}"
    ansible --version > /dev/null
    success "Ansible configured successfully"
}

# Install Ansible Galaxy dependencies
install_galaxy_roles() {
    log "Installing Ansible Galaxy roles and collections..."

    source "${PROJECT_DIR}/venv/bin/activate"
    cd "${PROJECT_DIR}"

    if [ -f "${PROJECT_DIR}/requirements.yml" ]; then
        ansible-galaxy collection install -r requirements.yml --upgrade
        success "Galaxy dependencies installed"
    else
        warning "requirements.yml not found, skipping Galaxy installation"
    fi
}

# Validate inventory
validate_inventory() {
    log "Validating Ansible inventory..."

    source "${PROJECT_DIR}/venv/bin/activate"
    cd "${PROJECT_DIR}"

    if ansible-inventory -i inventory/hosts.yml --list > /dev/null 2>&1; then
        success "Inventory validation passed"
    else
        error "Inventory validation failed"
        exit 1
    fi
}

# Setup environment file
setup_environment() {
    log "Setting up environment configuration..."

    if [ ! -f "${PROJECT_DIR}/.env" ]; then
        if [ -f "${PROJECT_DIR}/.env.example" ]; then
            cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
            warning "Created .env from .env.example"
            log "Please review and update .env with your configuration"
        fi
    else
        log "Environment file already exists"
    fi
}

# Create log directories
setup_logging() {
    log "Setting up logging..."

    mkdir -p /var/log/ansible
    mkdir -p "${PROJECT_DIR}/logs"
    success "Logging directories created"
}

# Run Ansible lint
run_lint() {
    log "Running Ansible lint..."

    source "${PROJECT_DIR}/venv/bin/activate"
    cd "${PROJECT_DIR}"

    if command -v ansible-lint &> /dev/null; then
        ansible-lint playbooks/ --quiet 2>/dev/null || warning "Some lint issues found (non-critical)"
        success "Lint check completed"
    else
        warning "ansible-lint not found, skipping"
    fi
}

# Summary report
print_summary() {
    cat << EOF

${GREEN}=== Bootstrap Summary ===${NC}
${GREEN}✓${NC} System requirements verified
${GREEN}✓${NC} Python virtual environment setup
${GREEN}✓${NC} Dependencies installed
${GREEN}✓${NC} SSH configuration
${GREEN}✓${NC} Ansible configured
${GREEN}✓${NC} Inventory validated
${GREEN}✓${NC} Environment configured

${BLUE}Next Steps:${NC}
1. Review and customize .env file
2. Update inventory/hosts.yml with your infrastructure
3. Review group_vars/all.yml and customize as needed
4. Test connectivity: ansible all -i inventory/hosts.yml -m ping
5. Run playbooks:
   - ansible-playbook playbooks/infrastructure-setup.yml
   - ansible-playbook playbooks/application-deployment.yml
   - ansible-playbook playbooks/security-hardening.yml

${BLUE}Documentation:${NC}
- Main README: ${PROJECT_DIR}/README.md
- Architecture: ${PROJECT_DIR}/docs/architecture.md
- Runbooks: ${PROJECT_DIR}/docs/runbooks.md

${BLUE}Bootstrap Log:${NC} ${LOG_FILE}

EOF
}

# Main execution
main() {
    log "Starting Ansible automation bootstrap..."
    log "Project directory: ${PROJECT_DIR}"

    check_requirements
    setup_virtualenv
    install_dependencies
    setup_ssh
    setup_ansible
    install_galaxy_roles
    validate_inventory
    setup_environment
    setup_logging
    run_lint

    success "Bootstrap completed successfully!"
    print_summary
}

# Run main
main "$@"
