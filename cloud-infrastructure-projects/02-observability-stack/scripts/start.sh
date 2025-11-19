#!/bin/bash

################################################################################
# Observability Stack - Startup Script
#
# This script starts all observability stack services and performs health checks
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
# Configuration
# ============================================================================

# Check if .env file exists, if not copy from .env.example
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${YELLOW}[INFO]${NC} .env file not found, copying from .env.example"
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        echo -e "${YELLOW}[WARN]${NC} .env created from template. Please review and configure sensitive values."
    else
        echo -e "${RED}[ERROR]${NC} .env.example not found"
        exit 1
    fi
fi

# Load environment variables
export $(cat "$PROJECT_DIR/.env" | grep -v '^#' | xargs)

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

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_success "Docker is installed"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    log_success "Docker Compose is installed"
}

check_docker_daemon() {
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    log_success "Docker daemon is running"
}

wait_for_service() {
    local service=$1
    local url=$2
    local max_attempts=$3
    local attempt=1

    log_info "Waiting for $service to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" &> /dev/null; then
            log_success "$service is ready"
            return 0
        fi

        echo -ne "${YELLOW}[WAIT]${NC} Attempt $attempt/$max_attempts - waiting for $service...\r"
        sleep 2
        attempt=$((attempt + 1))
    done

    log_warning "$service did not respond in time (may still be initializing)"
    return 1
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

log_info "=== Running pre-flight checks ==="
check_docker
check_docker_compose
check_docker_daemon

# Check disk space
available_space=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
if [ "$available_space" -lt 5242880 ]; then  # Less than 5GB
    log_warning "Low disk space available: $(numfmt --to=iec-i --suffix=B $available_space 2>/dev/null || echo '$available_space KB')"
fi

# Check if ports are available
required_ports=(3000 3100 5432 6379 8080 9090 9093 9100 9121 9187 14268 16686)
for port in "${required_ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port $port is already in use"
    fi
done

# ============================================================================
# Start Services
# ============================================================================

log_info "=== Starting Observability Stack ==="

cd "$PROJECT_DIR"

# Build images if needed
log_info "Building custom images..."
docker-compose build --quiet

# Start services
log_info "Starting services..."
docker-compose up -d

# ============================================================================
# Health Checks
# ============================================================================

log_info "=== Performing health checks ==="

sleep 5  # Give services time to start

# List of services and their health check URLs
declare -A services=(
    ["Prometheus"]="http://localhost:9090/-/healthy"
    ["Grafana"]="http://localhost:3000/api/health"
    ["AlertManager"]="http://localhost:9093/-/healthy"
    ["Loki"]="http://localhost:3100/ready"
    ["Jaeger UI"]="http://localhost:16686"
    ["Sample API"]="http://localhost:8000/health"
)

all_healthy=true

for service in "${!services[@]}"; do
    url="${services[$service]}"
    if wait_for_service "$service" "$url" 30; then
        log_success "$service is healthy"
    else
        log_warning "$service health check failed or timed out"
        all_healthy=false
    fi
done

# ============================================================================
# Display Service Information
# ============================================================================

log_info "=== Observability Stack Summary ==="

echo ""
echo -e "${BLUE}Dashboard Access:${NC}"
echo "  Grafana:         http://localhost:3000"
echo "    Username:      admin"
echo "    Password:      $(grep GF_SECURITY_ADMIN_PASSWORD $PROJECT_DIR/.env | cut -d= -f2)"
echo "  Prometheus:      http://localhost:9090"
echo "  Jaeger:          http://localhost:16686"
echo "  AlertManager:    http://localhost:9093"
echo "  Loki:            http://localhost:3100"
echo ""

echo -e "${BLUE}Sample Application:${NC}"
echo "  API:             http://localhost:8000"
echo "  API Docs:        http://localhost:8000/docs"
echo "  Health Check:    http://localhost:8000/health"
echo "  Metrics:         http://localhost:8000/metrics"
echo ""

echo -e "${BLUE}Infrastructure:${NC}"
echo "  PostgreSQL:      localhost:5432"
echo "  Redis:           localhost:6379"
echo ""

# ============================================================================
# Display Logs
# ============================================================================

log_info "=== Checking logs for errors ==="

# Check for startup errors in the last 30 seconds
errors=$(docker-compose logs --tail=100 2>/dev/null | grep -i "error" | head -5)
if [ ! -z "$errors" ]; then
    log_warning "Some startup errors detected:"
    echo "$errors"
fi

# ============================================================================
# Next Steps
# ============================================================================

log_info "=== Next Steps ==="

echo ""
echo "1. Access Grafana at http://localhost:3000"
echo "2. Review pre-configured dashboards"
echo "3. Generate sample traffic:"
echo "   docker-compose exec load-generator python load-gen.py"
echo "4. View logs:"
echo "   docker-compose logs -f sample-api"
echo "5. To stop all services:"
echo "   ./scripts/stop.sh"
echo ""

if [ "$all_healthy" = true ]; then
    log_success "All services are up and healthy!"
    echo ""
    log_info "Your observability stack is ready to use!"
else
    log_warning "Some services may still be initializing. Check logs with:"
    echo "  docker-compose logs -f"
fi

echo ""
