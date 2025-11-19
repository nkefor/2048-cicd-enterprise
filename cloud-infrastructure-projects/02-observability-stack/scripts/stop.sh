#!/bin/bash

################################################################################
# Observability Stack - Shutdown Script
#
# This script stops all observability stack services gracefully
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ============================================================================
# Check Docker
# ============================================================================

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi

# ============================================================================
# Stop Services
# ============================================================================

log_info "=== Stopping Observability Stack ==="

cd "$PROJECT_DIR"

# Get list of running containers
running_containers=$(docker-compose ps -q 2>/dev/null || echo "")

if [ -z "$running_containers" ]; then
    log_warning "No containers are currently running"
    exit 0
fi

# Count running containers
container_count=$(echo "$running_containers" | wc -l)
log_info "Stopping $container_count service(s)..."

# Stop containers with timeout
docker-compose down --timeout=30

if [ $? -eq 0 ]; then
    log_success "All services stopped successfully"
else
    log_error "Failed to stop services gracefully"
    log_info "Attempting force stop..."
    docker-compose down --force-stop
fi

# ============================================================================
# Cleanup Options
# ============================================================================

log_info "=== Cleanup Options ==="

# Ask user if they want to remove volumes
if [ -z "$REMOVE_VOLUMES" ]; then
    read -p "Remove data volumes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing volumes..."
        docker-compose down -v
        log_success "Volumes removed"
    fi
fi

# Ask user if they want to remove images
if [ -z "$REMOVE_IMAGES" ]; then
    read -p "Remove custom images? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing custom images..."
        docker-compose down --rmi custom
        log_success "Custom images removed"
    fi
fi

# ============================================================================
# Summary
# ============================================================================

log_info "=== Summary ==="

# Check remaining containers from this project
remaining=$(docker-compose ps -q 2>/dev/null || echo "")

if [ -z "$remaining" ]; then
    log_success "All containers have been stopped"
else
    log_warning "Some containers are still running"
fi

echo ""
log_info "To start services again, run: ./scripts/start.sh"
echo ""
