#!/bin/bash

################################################################################
# Load Generator Script
#
# This script starts the load generator to create realistic traffic patterns
# for testing the observability stack
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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --duration SECONDS      Load test duration in seconds (default: 3600)"
    echo "  -r, --rps REQUESTS          Requests per second (default: 10)"
    echo "  -e, --error-rate RATE       Error injection rate 0.0-1.0 (default: 0.02)"
    echo "  -l, --latency-rate RATE     Latency injection rate 0.0-1.0 (default: 0.05)"
    echo "  -m, --max-latency SECONDS   Maximum injected latency (default: 3.0)"
    echo "  -b, --burst-prob PROB       Burst probability 0.0-1.0 (default: 0.05)"
    echo "  -f, --follow                Follow logs after starting"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Run for 10 minutes with 20 RPS"
    echo "  $0 -d 600 -r 20"
    echo ""
    echo "  # Run stress test with high error rate"
    echo "  $0 -d 300 -r 100 -e 0.1"
    echo ""
    echo "  # Run with custom latency injection"
    echo "  $0 -d 1800 -r 15 -l 0.2 -m 5.0"
}

# ============================================================================
# Parse Arguments
# ============================================================================

DURATION=3600
RPS=10
ERROR_RATE=0.02
LATENCY_RATE=0.05
MAX_LATENCY=3.0
BURST_PROB=0.05
FOLLOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -r|--rps)
            RPS="$2"
            shift 2
            ;;
        -e|--error-rate)
            ERROR_RATE="$2"
            shift 2
            ;;
        -l|--latency-rate)
            LATENCY_RATE="$2"
            shift 2
            ;;
        -m|--max-latency)
            MAX_LATENCY="$2"
            shift 2
            ;;
        -b|--burst-prob)
            BURST_PROB="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW_LOGS=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Validation
# ============================================================================

cd "$PROJECT_DIR"

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi

# Check if services are running
if ! docker-compose ps sample-api 2>/dev/null | grep -q "Up"; then
    log_error "Sample API is not running"
    log_info "Start services with: ./scripts/start.sh"
    exit 1
fi

# Validate numeric arguments
if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    log_error "Duration must be a number"
    exit 1
fi

if ! [[ "$RPS" =~ ^[0-9]+$ ]]; then
    log_error "RPS must be a number"
    exit 1
fi

# ============================================================================
# Configuration
# ============================================================================

log_info "=== Load Generation Configuration ==="
echo "  Duration:              $DURATION seconds"
echo "  Requests per second:   $RPS"
echo "  Error injection rate:  $ERROR_RATE ($(echo "scale=1; $ERROR_RATE*100" | bc)%)"
echo "  Latency injection:     $LATENCY_RATE ($(echo "scale=1; $LATENCY_RATE*100" | bc)%)"
echo "  Max latency:           ${MAX_LATENCY}s"
echo "  Burst probability:     $BURST_PROB ($(echo "scale=1; $BURST_PROB*100" | bc)%)"
echo ""

# ============================================================================
# Start Load Generator
# ============================================================================

log_info "Starting load generator..."

docker-compose run --rm \
    -e TARGET_URL="http://sample-api:8000" \
    -e REQUESTS_PER_SECOND="$RPS" \
    -e DURATION_SECONDS="$DURATION" \
    -e ERROR_INJECTION_RATE="$ERROR_RATE" \
    -e LATENCY_INJECTION_RATE="$LATENCY_RATE" \
    -e MAX_LATENCY_DELAY="$MAX_LATENCY" \
    -e BURST_PROBABILITY="$BURST_PROB" \
    load-generator python load-gen.py

if [ $? -eq 0 ]; then
    log_success "Load generation completed successfully"
else
    log_error "Load generation failed"
    exit 1
fi

# ============================================================================
# Post-Generation Summary
# ============================================================================

echo ""
log_info "=== Load Generation Summary ==="

# Calculate statistics
expected_requests=$(echo "$RPS * $DURATION" | bc)

echo "Expected total requests: $expected_requests"
echo ""
echo "To view results:"
echo "  Grafana:     http://localhost:3000"
echo "  Prometheus:  http://localhost:9090"
echo "  Jaeger:      http://localhost:16686"
echo "  Loki:        http://localhost:3100"
echo ""

# Optional: show recent logs
if [ "$FOLLOW_LOGS" = true ]; then
    log_info "Following logs (Ctrl+C to stop)..."
    docker-compose logs -f sample-api load-generator
fi
