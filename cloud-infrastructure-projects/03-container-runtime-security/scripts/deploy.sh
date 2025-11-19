#!/bin/bash

################################################################################
# Container Runtime Security Platform - Deployment Script
#
# This script automates the deployment of the complete container runtime
# security platform including Falco, Elasticsearch, Kibana, and monitoring.
#
# Usage: ./scripts/deploy.sh [command]
# Commands:
#   start     - Start all services
#   stop      - Stop all services
#   restart   - Restart all services
#   status    - Show service status
#   logs      - Show service logs
#   clean     - Stop and remove containers
#   reset     - Reset to clean state (removes volumes)
#
################################################################################

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Functions
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker installation
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose installation
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warning "Environment file not found: $ENV_FILE"
        log_info "Creating from .env.example..."

        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            cp "${PROJECT_ROOT}/.env.example" "$ENV_FILE"
            log_success "Created .env file from template"
            log_warning "Please review and update $ENV_FILE with your settings"
        else
            log_error ".env.example not found"
            exit 1
        fi
    fi
}

create_directories() {
    log_info "Creating required directories..."

    mkdir -p "${PROJECT_ROOT}"/{
        prometheus,
        grafana/provisioning/{datasources,dashboards},
        trivy/reports,
        logs
    }

    log_success "Directories created"
}

build_images() {
    log_info "Building custom images..."

    docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache sample-app

    log_success "Images built successfully"
}

start_services() {
    log_info "Starting services..."

    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

    log_success "Services started"

    # Wait for services to be healthy
    wait_for_services
}

stop_services() {
    log_info "Stopping services..."

    docker-compose -f "$DOCKER_COMPOSE_FILE" down

    log_success "Services stopped"
}

restart_services() {
    log_info "Restarting services..."

    stop_services
    sleep 2
    start_services

    log_success "Services restarted"
}

wait_for_services() {
    log_info "Waiting for services to be ready..."

    # Wait for Elasticsearch
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
            log_success "Elasticsearch is ready"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warning "Elasticsearch health check timeout"
    fi

    # Wait for Kibana
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:5601/api/status &> /dev/null; then
            log_success "Kibana is ready"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warning "Kibana health check timeout"
    fi

    # Wait for Prometheus
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:9090/-/healthy &> /dev/null; then
            log_success "Prometheus is ready"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warning "Prometheus health check timeout"
    fi

    # Wait for Grafana
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/api/health &> /dev/null; then
            log_success "Grafana is ready"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warning "Grafana health check timeout"
    fi

    echo ""
}

show_status() {
    log_info "Service Status:"
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps

    echo ""
    log_info "Service Endpoints:"
    echo "  Kibana:       http://localhost:5601"
    echo "  Grafana:      http://localhost:3000 (admin/admin)"
    echo "  Prometheus:   http://localhost:9090"
    echo "  Sample App:   http://localhost:8080"
}

show_logs() {
    local service=$1

    if [ -z "$service" ]; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f
    else
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f "$service"
    fi
}

clean_services() {
    log_info "Cleaning up services..."

    docker-compose -f "$DOCKER_COMPOSE_FILE" down

    log_success "Services cleaned"
}

reset_deployment() {
    log_warning "This will remove all data including Elasticsearch indices and Prometheus metrics"
    read -p "Are you sure? (yes/no): " -r

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Resetting deployment..."

        docker-compose -f "$DOCKER_COMPOSE_FILE" down -v

        log_success "Deployment reset to clean state"
    else
        log_info "Reset cancelled"
    fi
}

setup_kibana_index() {
    log_info "Setting up Kibana index pattern..."

    sleep 5

    # Create index pattern for Falco alerts
    curl -X POST http://localhost:5601/api/saved_objects/index-pattern \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "falco-*",
                "timeFieldName": "timestamp",
                "fields": "[]"
            }
        }' 2>/dev/null || log_warning "Could not create Kibana index pattern (it may already exist)"

    log_success "Kibana index pattern setup complete"
}

verify_deployment() {
    log_info "Verifying deployment..."

    local failed=0

    # Check Elasticsearch
    if ! curl -s http://localhost:9200/_cluster/health | grep -q "\"status\""; then
        log_error "Elasticsearch verification failed"
        failed=1
    else
        log_success "Elasticsearch verified"
    fi

    # Check Kibana
    if ! curl -s http://localhost:5601/api/status | grep -q "\"state\""; then
        log_error "Kibana verification failed"
        failed=1
    else
        log_success "Kibana verified"
    fi

    # Check Prometheus
    if ! curl -s http://localhost:9090/api/v1/query | grep -q "\"status\""; then
        log_error "Prometheus verification failed"
        failed=1
    else
        log_success "Prometheus verified"
    fi

    # Check Grafana
    if ! curl -s http://localhost:3000/api/health | grep -q "\"ok\""; then
        log_error "Grafana verification failed"
        failed=1
    else
        log_success "Grafana verified"
    fi

    # Check Falco
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps falco | grep -q "running"; then
        log_success "Falco verified"
    else
        log_error "Falco verification failed"
        failed=1
    fi

    if [ $failed -eq 0 ]; then
        log_success "All services verified successfully"
        return 0
    else
        log_error "Some services failed verification"
        return 1
    fi
}

show_usage() {
    cat << EOF
Container Runtime Security Platform - Deployment Script

Usage: $0 [command]

Commands:
    start       Start all services (default)
    stop        Stop all services
    restart     Restart all services
    status      Show service status
    logs        Show service logs (follow mode)
    logs [svc]  Show logs for specific service
    clean       Stop and remove containers
    reset       Reset to clean state (removes volumes)
    verify      Verify deployment health
    help        Show this help message

Examples:
    $0 start              # Start all services
    $0 logs falco         # Show Falco logs
    $0 restart            # Restart services
    $0 reset              # Clean reset

EOF
}

# ============================================================
# Main
# ============================================================

main() {
    local command=${1:-start}

    case "$command" in
        start)
            check_prerequisites
            check_env_file
            create_directories
            build_images
            start_services
            setup_kibana_index
            verify_deployment
            show_status
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-}"
            ;;
        clean)
            clean_services
            ;;
        reset)
            reset_deployment
            ;;
        verify)
            verify_deployment
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
