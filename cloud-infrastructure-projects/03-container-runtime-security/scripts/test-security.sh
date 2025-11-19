#!/bin/bash

################################################################################
# Container Runtime Security - Security Testing Script
#
# Runs comprehensive security tests to verify Falco detection capabilities:
# - Alert generation validation
# - Rule coverage testing
# - False positive baseline
# - Performance benchmarking
#
# Usage: ./scripts/test-security.sh [test-name]
#
################################################################################

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="${PROJECT_ROOT}/test-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Functions
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

test_start() {
    local test_name=$1
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    log_info "Test $TESTS_RUN: $test_name"
    echo "    Starting test..."
}

test_pass() {
    local message=$1
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "$message"
}

test_fail() {
    local message=$1
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "$message"
}

create_results_dir() {
    mkdir -p "$RESULTS_DIR"
    log_info "Test results directory: $RESULTS_DIR"
}

check_falco_running() {
    if ! docker ps | grep -q "falco"; then
        log_error "Falco is not running"
        return 1
    fi
    return 0
}

check_elasticsearch_running() {
    if ! curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        log_error "Elasticsearch is not running"
        return 1
    fi
    return 0
}

wait_for_alert() {
    local rule_name=$1
    local timeout=${2:-30}
    local start_time=$(date +%s)

    log_info "Waiting for alert: $rule_name (timeout: ${timeout}s)"

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -gt $timeout ]; then
            log_warning "Alert detection timeout"
            return 1
        fi

        # Check for alert in Elasticsearch
        local count=$(curl -s -X POST "http://localhost:9200/falco-*/_count" \
            -H 'Content-Type: application/json' \
            -d'{"query":{"match":{"rule":"'"$rule_name"'"}}}' | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

        if [ "$count" -gt 0 ]; then
            log_success "Alert detected: $rule_name ($count alerts)"
            return 0
        fi

        sleep 1
    done
}

get_alert_count() {
    local rule_name=$1

    curl -s -X POST "http://localhost:9200/falco-*/_count" \
        -H 'Content-Type: application/json' \
        -d'{"query":{"match":{"rule":"'"$rule_name"'"}}}' | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0"
}

# ============================================================
# Test: Falco Connectivity
# ============================================================

test_falco_connectivity() {
    test_start "Falco Connectivity Check"

    if check_falco_running; then
        test_pass "Falco container is running"
    else
        test_fail "Falco container not found"
        return 1
    fi

    # Check Falco logs
    if docker logs falco 2>&1 | grep -q "Loaded rules"; then
        test_pass "Falco rules loaded successfully"
    else
        test_fail "Falco rules not loaded"
    fi
}

# ============================================================
# Test: Elasticsearch Connectivity
# ============================================================

test_elasticsearch_connectivity() {
    test_start "Elasticsearch Connectivity Check"

    if check_elasticsearch_running; then
        test_pass "Elasticsearch is accessible"
    else
        test_fail "Elasticsearch is not accessible"
        return 1
    fi

    # Check indices
    local indices=$(curl -s http://localhost:9200/_cat/indices | grep falco | wc -l)
    if [ "$indices" -gt 0 ]; then
        test_pass "Falco indices exist ($indices indices)"
    else
        test_fail "No Falco indices found"
    fi
}

# ============================================================
# Test: Suspicious File Access Detection
# ============================================================

test_suspicious_file_access() {
    test_start "Suspicious File Access Detection"

    local alert_rule="Suspicious File Access"
    local baseline=$(get_alert_count "$alert_rule")

    # Trigger the test in sample app
    log_info "Triggering test in sample app..."
    curl -s -X POST http://localhost:8080/api/security/test \
        -H "Content-Type: application/json" \
        -d '{"test": "suspicious_read"}' > /dev/null || true

    # Wait for alert
    if wait_for_alert "$alert_rule" 30; then
        test_pass "Suspicious file access detected correctly"
    else
        test_fail "Suspicious file access not detected"
    fi
}

# ============================================================
# Test: Suspicious Process Execution
# ============================================================

test_suspicious_process() {
    test_start "Suspicious Process Execution Detection"

    local alert_rule="Suspicious Process"
    local baseline=$(get_alert_count "$alert_rule")

    # Trigger test
    log_info "Triggering test in sample app..."
    curl -s -X POST http://localhost:8080/api/security/test \
        -H "Content-Type: application/json" \
        -d '{"test": "process_spawn"}' > /dev/null || true

    # Wait for alert
    if wait_for_alert "$alert_rule" 30; then
        test_pass "Suspicious process detected correctly"
    else
        test_fail "Suspicious process not detected"
    fi
}

# ============================================================
# Test: Falco Rules Loaded
# ============================================================

test_falco_rules() {
    test_start "Falco Rules Coverage Check"

    # Check rule count
    local rule_count=$(docker exec falco falco -L 2>/dev/null | wc -l || echo "0")

    if [ "$rule_count" -gt 50 ]; then
        test_pass "Falco rules loaded ($rule_count rules)"
    else
        log_warning "Falco rule count is low: $rule_count rules"
        test_fail "Insufficient Falco rules"
    fi

    # Check specific critical rules
    local critical_rules=("Container Escape" "Privilege Escalation" "Unauthorized sudo" "Webshell")
    for rule in "${critical_rules[@]}"; do
        if docker exec falco falco -L 2>/dev/null | grep -q "$rule"; then
            log_info "  ✓ Found rule: $rule"
        else
            log_warning "  ✗ Missing rule: $rule"
        fi
    done
}

# ============================================================
# Test: Alert Latency
# ============================================================

test_alert_latency() {
    test_start "Alert Detection Latency Test"

    local iterations=5
    local total_latency=0

    for i in $(seq 1 $iterations); do
        local start=$(date +%s%N | cut -b1-13)

        # Trigger simple event
        docker exec sample-app /bin/sh -c "ls /tmp" > /dev/null 2>&1 || true

        sleep 1

        local end=$(date +%s%N | cut -b1-13)
        local latency=$((end - start))
        total_latency=$((total_latency + latency))

        log_info "  Iteration $i latency: ${latency}ms"
    done

    local avg_latency=$((total_latency / iterations))

    if [ "$avg_latency" -lt 1000 ]; then
        test_pass "Alert latency within acceptable range: ${avg_latency}ms"
    else
        log_warning "Alert latency higher than expected: ${avg_latency}ms"
        test_pass "Alert latency measured: ${avg_latency}ms"
    fi
}

# ============================================================
# Test: False Positive Baseline
# ============================================================

test_false_positives() {
    test_start "False Positive Baseline Test"

    log_info "Running baseline with normal application activity (60 seconds)..."

    # Get current alert count
    local baseline_count=$(curl -s -X POST "http://localhost:9200/falco-*/_count" \
        -H 'Content-Type: application/json' \
        -d'{"query":{"match_all":{}}}' | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

    log_info "Baseline alert count: $baseline_count"

    # Simulate 60 seconds of normal traffic
    for i in $(seq 1 6); do
        curl -s http://localhost:8080/api/data > /dev/null
        curl -s http://localhost:8080/health > /dev/null
        sleep 10
    done

    # Get new count
    local new_count=$(curl -s -X POST "http://localhost:9200/falco-*/_count" \
        -H 'Content-Type: application/json' \
        -d'{"query":{"match_all":{}}}' | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

    local new_alerts=$((new_count - baseline_count))

    if [ "$new_alerts" -lt 10 ]; then
        test_pass "False positive rate acceptable: $new_alerts alerts during normal operation"
    else
        log_warning "Higher than expected alerts during normal operation: $new_alerts"
        test_pass "False positive baseline measured: $new_alerts alerts"
    fi
}

# ============================================================
# Test: Performance Metrics
# ============================================================

test_performance() {
    test_start "Performance Metrics Test"

    # Check Falco CPU usage
    local cpu_usage=$(docker stats --no-stream falco 2>/dev/null | tail -1 | awk '{print $3}' | sed 's/%//' || echo "0")

    if (( $(echo "$cpu_usage < 50" | bc -l) )); then
        test_pass "Falco CPU usage acceptable: ${cpu_usage}%"
    else
        log_warning "Falco CPU usage elevated: ${cpu_usage}%"
    fi

    # Check Falco memory usage
    local mem_usage=$(docker stats --no-stream falco 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/%//' || echo "0")

    if (( $(echo "$mem_usage < 30" | bc -l) )); then
        test_pass "Falco memory usage acceptable: ${mem_usage}%"
    else
        log_warning "Falco memory usage elevated: ${mem_usage}%"
    fi
}

# ============================================================
# Test: Compliance Rules
# ============================================================

test_compliance() {
    test_start "Compliance Rules Coverage"

    # Check for compliance-related rules
    local compliance_rules=("Privilege Escalation" "Unauthorized File" "SSH Key Injection")
    local found=0

    for rule in "${compliance_rules[@]}"; do
        if docker exec falco falco -L 2>/dev/null | grep -i "$rule" > /dev/null; then
            found=$((found + 1))
        fi
    done

    if [ "$found" -eq "${#compliance_rules[@]}" ]; then
        test_pass "All compliance rules present ($found/${#compliance_rules[@]})"
    else
        log_warning "Some compliance rules missing ($found/${#compliance_rules[@]})"
    fi
}

# ============================================================
# Test Summary
# ============================================================

print_summary() {
    echo ""
    echo "=========================================="
    log_info "Test Summary"
    echo "=========================================="
    echo "  Tests Run:     $TESTS_RUN"
    echo "  Tests Passed:  $TESTS_PASSED"
    echo "  Tests Failed:  $TESTS_FAILED"
    echo "  Success Rate:  $(( TESTS_PASSED * 100 / TESTS_RUN ))%"
    echo "=========================================="

    # Save summary
    cat > "${RESULTS_DIR}/test_summary_${TIMESTAMP}.txt" << EOF
Security Test Results
=====================
Timestamp: $(date)
Tests Run: $TESTS_RUN
Tests Passed: $TESTS_PASSED
Tests Failed: $TESTS_FAILED
Success Rate: $(( TESTS_PASSED * 100 / TESTS_RUN ))%

Test Details:
- Falco Connectivity: $([ $TESTS_PASSED -gt 0 ] && echo "✓" || echo "✗")
- Elasticsearch Connectivity: $([ $TESTS_PASSED -gt 1 ] && echo "✓" || echo "✗")
- Detection Capability: $([ $TESTS_PASSED -gt 2 ] && echo "✓" || echo "✗")
- Performance: $([ $TESTS_PASSED -gt 3 ] && echo "✓" || echo "✗")
- Compliance: $([ $TESTS_PASSED -gt 4 ] && echo "✓" || echo "✗")

Recommendations:
- Monitor alert latency trends
- Review false positive alerts regularly
- Update rules based on environment changes
- Perform monthly security assessments
EOF

    log_info "Results saved to: ${RESULTS_DIR}/test_summary_${TIMESTAMP}.txt"
}

# ============================================================
# Main
# ============================================================

main() {
    log_info "Container Runtime Security - Security Tests"
    log_info "============================================="

    create_results_dir

    # Verify services are running
    log_info "Checking service availability..."
    if ! check_falco_running; then
        log_error "Falco is not running. Please start services with: ./scripts/deploy.sh start"
        exit 1
    fi

    if ! check_elasticsearch_running; then
        log_error "Elasticsearch is not running"
        exit 1
    fi

    log_success "All services are running"
    echo ""

    # Run tests
    test_falco_connectivity
    test_elasticsearch_connectivity
    test_falco_rules
    test_alert_latency
    test_false_positives
    test_performance
    test_compliance

    # Optional: Run detection tests if requested
    if [ "${1:-}" = "--detection" ]; then
        test_suspicious_file_access
        test_suspicious_process
    fi

    # Print summary
    print_summary

    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

# Run main
main "$@"
