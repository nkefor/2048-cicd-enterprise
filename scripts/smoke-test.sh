#!/bin/bash
set -euo pipefail

# ============================================================
# Post-Deployment Smoke Test
# ============================================================
#
# Runs a comprehensive set of checks against a deployed service
# to verify it's functioning correctly after a blue/green cutover.
#
# Usage:
#   ./scripts/smoke-test.sh --endpoint http://your-alb-dns.com
#   ./scripts/smoke-test.sh --endpoint http://localhost:8080
#
# Exit codes:
#   0 - All smoke tests passed
#   1 - One or more smoke tests failed
# ============================================================

ENDPOINT=""
VERBOSE=false

usage() {
  echo "Usage: $0 --endpoint <url> [options]"
  echo ""
  echo "Options:"
  echo "  --endpoint   URL to test (required)"
  echo "  --verbose    Show detailed output"
  echo "  --help       Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$ENDPOINT" ]; then
  echo "ERROR: --endpoint is required"
  usage
  exit 1
fi

# Remove trailing slash
ENDPOINT="${ENDPOINT%/}"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "  WARN: $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

echo "============================================"
echo "  Smoke Test Suite"
echo "  Endpoint: $ENDPOINT"
echo "  Time:     $(date +'%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# ---------------------------------------------------------
# Test 1: Main page returns HTTP 200
# ---------------------------------------------------------
echo "[Test 1] Main page availability"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  pass "Main page returns HTTP 200"
else
  fail "Main page returned HTTP $HTTP_CODE (expected 200)"
fi

# ---------------------------------------------------------
# Test 2: Health endpoint returns HTTP 200
# ---------------------------------------------------------
echo "[Test 2] Health endpoint"
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT/health" 2>/dev/null || echo "000")
HEALTH_BODY=$(curl -s "$ENDPOINT/health" 2>/dev/null || echo "")
if [ "$HEALTH_CODE" = "200" ]; then
  pass "Health endpoint returns HTTP 200"
  if echo "$HEALTH_BODY" | grep -q "healthy" 2>/dev/null; then
    pass "Health response contains 'healthy' status"
  else
    warn "Health response doesn't contain expected 'healthy' status"
  fi
else
  fail "Health endpoint returned HTTP $HEALTH_CODE (expected 200)"
fi

# ---------------------------------------------------------
# Test 3: Security headers present
# ---------------------------------------------------------
echo "[Test 3] Security headers"
HEADERS=$(curl -sI "$ENDPOINT/" 2>/dev/null)

check_security_header() {
  local header="$1"
  local expected_value="$2"
  if echo "$HEADERS" | grep -qi "$header"; then
    if [ -n "$expected_value" ]; then
      if echo "$HEADERS" | grep -qi "$header.*$expected_value"; then
        pass "$header: $expected_value"
      else
        warn "$header present but value may differ from expected"
      fi
    else
      pass "$header present"
    fi
  else
    fail "$header missing"
  fi
}

check_security_header "X-Content-Type-Options" "nosniff"
check_security_header "X-Frame-Options" "DENY"
check_security_header "X-XSS-Protection" "1"
check_security_header "Referrer-Policy" "no-referrer"
check_security_header "Content-Security-Policy" ""
check_security_header "Strict-Transport-Security" ""
check_security_header "Permissions-Policy" ""

# ---------------------------------------------------------
# Test 4: Server version not disclosed
# ---------------------------------------------------------
echo "[Test 4] Server version disclosure"
if echo "$HEADERS" | grep -qi "server:.*nginx/"; then
  fail "Server version disclosed in headers"
else
  pass "Server version not disclosed"
fi

# ---------------------------------------------------------
# Test 5: Response time within threshold
# ---------------------------------------------------------
echo "[Test 5] Response time"
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$ENDPOINT/" 2>/dev/null || echo "99")
if [ "$(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
  pass "Response time ${RESPONSE_TIME}s (< 2.0s threshold)"
elif [ "$(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
  warn "Response time ${RESPONSE_TIME}s (> 2.0s but < 5.0s)"
else
  fail "Response time ${RESPONSE_TIME}s (> 5.0s threshold)"
fi

# ---------------------------------------------------------
# Test 6: Content validation
# ---------------------------------------------------------
echo "[Test 6] Content validation"
BODY=$(curl -s "$ENDPOINT/" 2>/dev/null || echo "")
if echo "$BODY" | grep -qi "2048" 2>/dev/null; then
  pass "Page contains '2048' content"
else
  warn "Page doesn't contain expected '2048' content"
fi

if echo "$BODY" | grep -qi "<html" 2>/dev/null; then
  pass "Page contains valid HTML"
else
  fail "Page doesn't contain valid HTML"
fi

# ---------------------------------------------------------
# Test 7: 404 handling
# ---------------------------------------------------------
echo "[Test 7] Error handling"
NOT_FOUND_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT/nonexistent-page-test-12345" 2>/dev/null || echo "000")
if [ "$NOT_FOUND_CODE" = "200" ] || [ "$NOT_FOUND_CODE" = "404" ]; then
  pass "Non-existent page handled (HTTP $NOT_FOUND_CODE)"
else
  warn "Unexpected response for non-existent page: HTTP $NOT_FOUND_CODE"
fi

# ---------------------------------------------------------
# Test 8: Hidden files blocked
# ---------------------------------------------------------
echo "[Test 8] Hidden file access"
HIDDEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT/.env" 2>/dev/null || echo "000")
if [ "$HIDDEN_CODE" = "403" ] || [ "$HIDDEN_CODE" = "404" ]; then
  pass "Hidden files blocked (HTTP $HIDDEN_CODE)"
else
  warn "Hidden file access returned HTTP $HIDDEN_CODE (expected 403 or 404)"
fi

# ---------------------------------------------------------
# Test 9: Gzip compression
# ---------------------------------------------------------
echo "[Test 9] Compression"
COMPRESSED_HEADERS=$(curl -sI -H "Accept-Encoding: gzip" "$ENDPOINT/" 2>/dev/null)
if echo "$COMPRESSED_HEADERS" | grep -qi "content-encoding.*gzip"; then
  pass "Gzip compression enabled"
else
  warn "Gzip compression may not be enabled"
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo ""
echo "============================================"
echo "  Smoke Test Results"
echo "============================================"
echo ""
echo "  Passed:   $PASS_COUNT"
echo "  Failed:   $FAIL_COUNT"
echo "  Warnings: $WARN_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "  RESULT: FAILED ($FAIL_COUNT failures)"
  echo "============================================"
  exit 1
else
  if [ "$WARN_COUNT" -gt 0 ]; then
    echo "  RESULT: PASSED (with $WARN_COUNT warnings)"
  else
    echo "  RESULT: ALL TESTS PASSED"
  fi
  echo "============================================"
  exit 0
fi
