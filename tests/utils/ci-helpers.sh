#!/bin/bash

##############################################################################
# CI/CD Test Helper Utilities
#
# Common functions for CI/CD test scripts
##############################################################################

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

##############################################################################
# Logging Functions
##############################################################################

log_info() {
  echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_debug() {
  if [ "${DEBUG:-false}" = "true" ]; then
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
  fi
}

##############################################################################
# Docker Helper Functions
##############################################################################

# Build Docker image with retry
docker_build_with_retry() {
  local dockerfile_path="$1"
  local image_name="$2"
  local max_retries="${3:-3}"
  local retry_count=0

  while [ $retry_count -lt $max_retries ]; do
    log_info "Building Docker image (attempt $((retry_count + 1))/$max_retries)..."

    if docker build -t "$image_name" "$dockerfile_path"; then
      log_info "Docker build successful"
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [ $retry_count -lt $max_retries ]; then
      log_warn "Build failed, retrying in 5 seconds..."
      sleep 5
    fi
  done

  log_error "Docker build failed after $max_retries attempts"
  return 1
}

# Wait for container to be healthy
wait_for_container_health() {
  local container_name="$1"
  local max_wait="${2:-60}"
  local waited=0

  log_info "Waiting for container '$container_name' to be healthy..."

  while [ $waited -lt $max_wait ]; do
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

    case $health_status in
      "healthy")
        log_info "Container is healthy"
        return 0
        ;;
      "unhealthy")
        log_error "Container is unhealthy"
        docker logs "$container_name" --tail 50
        return 1
        ;;
      "none")
        # No health check defined, check if running
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
          log_info "Container is running (no health check defined)"
          return 0
        fi
        ;;
    esac

    sleep 2
    waited=$((waited + 2))
  done

  log_error "Container health check timeout after ${max_wait}s"
  docker logs "$container_name" --tail 50
  return 1
}

# Get container logs
get_container_logs() {
  local container_name="$1"
  local lines="${2:-100}"

  log_info "Container logs (last $lines lines):"
  docker logs "$container_name" --tail "$lines" 2>&1 | sed 's/^/  /'
}

##############################################################################
# HTTP/API Helper Functions
##############################################################################

# Wait for URL to be reachable
wait_for_url() {
  local url="$1"
  local max_wait="${2:-60}"
  local waited=0

  log_info "Waiting for URL to be reachable: $url"

  while [ $waited -lt $max_wait ]; do
    if curl -sf "$url" > /dev/null 2>&1; then
      log_info "URL is reachable"
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  log_error "URL not reachable after ${max_wait}s: $url"
  return 1
}

# Check HTTP status code
check_http_status() {
  local url="$1"
  local expected_status="${2:-200}"

  local actual_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")

  if [ "$actual_status" = "$expected_status" ]; then
    log_info "HTTP status check passed: $actual_status"
    return 0
  else
    log_error "HTTP status check failed: expected $expected_status, got $actual_status"
    return 1
  fi
}

# Check response contains text
check_response_contains() {
  local url="$1"
  local expected_text="$2"

  local response=$(curl -s "$url")

  if echo "$response" | grep -q "$expected_text"; then
    log_info "Response contains expected text: '$expected_text'"
    return 0
  else
    log_error "Response does not contain expected text: '$expected_text'"
    log_debug "Response: $response"
    return 1
  fi
}

##############################################################################
# Test Result Functions
##############################################################################

# Initialize test results
init_test_results() {
  export TEST_TOTAL=0
  export TEST_PASSED=0
  export TEST_FAILED=0
  export TEST_SKIPPED=0
  export FAILED_TESTS=()
}

# Record test result
record_test_result() {
  local test_name="$1"
  local result="$2" # pass, fail, skip

  TEST_TOTAL=$((TEST_TOTAL + 1))

  case $result in
    pass)
      TEST_PASSED=$((TEST_PASSED + 1))
      log_info "✅ $test_name: PASSED"
      ;;
    fail)
      TEST_FAILED=$((TEST_FAILED + 1))
      FAILED_TESTS+=("$test_name")
      log_error "❌ $test_name: FAILED"
      ;;
    skip)
      TEST_SKIPPED=$((TEST_SKIPPED + 1))
      log_warn "⏭️  $test_name: SKIPPED"
      ;;
  esac
}

# Print test summary
print_test_summary() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║                  Test Summary                          ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
  echo "Total:   $TEST_TOTAL"
  echo "Passed:  $TEST_PASSED ✅"
  echo "Failed:  $TEST_FAILED ❌"
  echo "Skipped: $TEST_SKIPPED ⏭️"
  echo ""

  if [ $TEST_FAILED -gt 0 ]; then
    echo "Failed Tests:"
    for test in "${FAILED_TESTS[@]}"; do
      echo "  ❌ $test"
    done
    echo ""
    return 1
  else
    echo "✅ ALL TESTS PASSED"
    return 0
  fi
}

##############################################################################
# Environment Functions
##############################################################################

# Check required environment variables
check_required_env() {
  local vars=("$@")
  local missing=()

  for var in "${vars[@]}"; do
    if [ -z "${!var:-}" ]; then
      missing+=("$var")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_error "Missing required environment variables:"
    for var in "${missing[@]}"; do
      echo "  - $var"
    done
    return 1
  fi

  return 0
}

# Load environment file
load_env_file() {
  local env_file="$1"

  if [ -f "$env_file" ]; then
    log_info "Loading environment from: $env_file"
    set -a
    source "$env_file"
    set +a
  else
    log_warn "Environment file not found: $env_file"
  fi
}

##############################################################################
# Cleanup Functions
##############################################################################

# Register cleanup function
register_cleanup() {
  local cleanup_fn="$1"

  if [ -z "${CLEANUP_FUNCTIONS:-}" ]; then
    export CLEANUP_FUNCTIONS=()
  fi

  CLEANUP_FUNCTIONS+=("$cleanup_fn")

  # Register trap on first call
  if [ ${#CLEANUP_FUNCTIONS[@]} -eq 1 ]; then
    trap run_cleanup EXIT
  fi
}

# Run all cleanup functions
run_cleanup() {
  log_info "Running cleanup functions..."

  for fn in "${CLEANUP_FUNCTIONS[@]}"; do
    log_debug "Running cleanup: $fn"
    $fn || true
  done
}

##############################################################################
# Utility Functions
##############################################################################

# Retry command with exponential backoff
retry_command() {
  local max_retries="${1:-3}"
  shift
  local command=("$@")

  local retry_count=0
  local delay=2

  while [ $retry_count -lt $max_retries ]; do
    if "${command[@]}"; then
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [ $retry_count -lt $max_retries ]; then
      log_warn "Command failed, retrying in ${delay}s (attempt $((retry_count + 1))/$max_retries)..."
      sleep $delay
      delay=$((delay * 2))
    fi
  done

  log_error "Command failed after $max_retries attempts"
  return 1
}

# Check if port is in use
is_port_in_use() {
  local port="$1"

  if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Find available port
find_available_port() {
  local start_port="${1:-8080}"
  local max_attempts="${2:-100}"

  for i in $(seq 0 $max_attempts); do
    local port=$((start_port + i))
    if ! is_port_in_use $port; then
      echo $port
      return 0
    fi
  done

  log_error "Could not find available port after $max_attempts attempts"
  return 1
}

# Generate random string
random_string() {
  local length="${1:-10}"
  LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$length"
}

# Check command exists
require_command() {
  local cmd="$1"
  local install_hint="${2:-}"

  if ! command -v "$cmd" &> /dev/null; then
    log_error "Required command not found: $cmd"
    if [ -n "$install_hint" ]; then
      log_info "Install with: $install_hint"
    fi
    return 1
  fi

  return 0
}

##############################################################################
# Export all functions
##############################################################################

export -f log_info log_warn log_error log_debug
export -f docker_build_with_retry wait_for_container_health get_container_logs
export -f wait_for_url check_http_status check_response_contains
export -f init_test_results record_test_result print_test_summary
export -f check_required_env load_env_file
export -f register_cleanup run_cleanup
export -f retry_command is_port_in_use find_available_port random_string require_command
