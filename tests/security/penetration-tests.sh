#!/bin/bash
set -euo pipefail

##############################################################################
# Security Penetration Testing Script
#
# Tests for common web vulnerabilities and security misconfigurations
#
# Priority: HIGH - Prevents security vulnerabilities
#
# Usage:
#   bash tests/security/penetration-tests.sh
#   BASE_URL=https://example.com bash tests/security/penetration-tests.sh
#
# Tests:
#   - XSS (Cross-Site Scripting)
#   - SQL Injection patterns
#   - Directory traversal
#   - Security headers validation
#   - SSL/TLS configuration
#   - Information disclosure
#   - Common vulnerability patterns
##############################################################################

BASE_URL=${BASE_URL:-http://localhost:8080}
FAILED_TESTS=0
TOTAL_TESTS=0

echo "╔════════════════════════════════════════════════════════╗"
echo "║        Security Penetration Tests                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Target: $BASE_URL"
echo ""

# Helper function to run tests
run_test() {
  local test_name="$1"
  local test_command="$2"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo "Test $TOTAL_TESTS: $test_name"

  if eval "$test_command"; then
    echo "✅ PASS"
  else
    echo "❌ FAIL"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo ""
}

##############################################################################
# Test 1: XSS (Cross-Site Scripting) Protection
##############################################################################

test_xss_protection() {
  echo "  → Testing for reflected XSS vulnerabilities..."

  # Test various XSS payloads
  local xss_payloads=(
    "<script>alert('xss')</script>"
    "<img src=x onerror=alert('xss')>"
    "<svg/onload=alert('xss')>"
    "javascript:alert('xss')"
    "<iframe src='javascript:alert(1)'>"
  )

  for payload in "${xss_payloads[@]}"; do
    encoded_payload=$(printf '%s' "$payload" | jq -sRr @uri)
    response=$(curl -s "$BASE_URL/?q=$encoded_payload")

    # Check if payload is reflected unescaped
    if echo "$response" | grep -qF "$payload"; then
      echo "  ⚠️  Potential XSS: Payload reflected unescaped: $payload"
      return 1
    fi
  done

  echo "  ✓ No XSS vulnerabilities detected"
  return 0
}

run_test "XSS Protection" "test_xss_protection"

##############################################################################
# Test 2: SQL Injection Protection
##############################################################################

test_sql_injection() {
  echo "  → Testing for SQL injection vulnerabilities..."

  # Test SQL injection patterns (even though it's a static site)
  local sql_payloads=(
    "' OR '1'='1"
    "1' OR '1' = '1"
    "admin'--"
    "1; DROP TABLE users--"
    "' UNION SELECT NULL--"
  )

  for payload in "${sql_payloads[@]}"; do
    encoded_payload=$(printf '%s' "$payload" | jq -sRr @uri)
    response=$(curl -s "$BASE_URL/?id=$encoded_payload")

    # Check for SQL error messages
    if echo "$response" | grep -qiE "(sql|mysql|postgresql|oracle|syntax error|database)"; then
      echo "  ⚠️  Potential SQL error disclosure: $payload"
      return 1
    fi
  done

  echo "  ✓ No SQL injection vulnerabilities detected"
  return 0
}

run_test "SQL Injection Protection" "test_sql_injection"

##############################################################################
# Test 3: Directory Traversal Protection
##############################################################################

test_directory_traversal() {
  echo "  → Testing for directory traversal vulnerabilities..."

  local traversal_payloads=(
    "../../etc/passwd"
    "../../../etc/shadow"
    "....//....//....//etc/passwd"
    "..%2F..%2F..%2Fetc%2Fpasswd"
  )

  for payload in "${traversal_payloads[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$payload")

    # Should return 404, not 200
    if [ "$status" = "200" ]; then
      echo "  ⚠️  Potential directory traversal: $payload returned HTTP 200"
      return 1
    fi
  done

  echo "  ✓ Directory traversal protection working"
  return 0
}

run_test "Directory Traversal Protection" "test_directory_traversal"

##############################################################################
# Test 4: Security Headers Validation
##############################################################################

test_security_headers() {
  echo "  → Validating security headers..."

  headers=$(curl -s -I "$BASE_URL")

  # Required security headers
  local required_headers=(
    "X-Frame-Options"
    "X-Content-Type-Options"
    "X-XSS-Protection"
    "Referrer-Policy"
  )

  local missing_headers=()

  for header in "${required_headers[@]}"; do
    if ! echo "$headers" | grep -qi "^$header:"; then
      missing_headers+=("$header")
    fi
  done

  if [ ${#missing_headers[@]} -gt 0 ]; then
    echo "  ⚠️  Missing security headers: ${missing_headers[*]}"
    return 1
  fi

  # Validate header values
  if ! echo "$headers" | grep -qi "X-Frame-Options: DENY"; then
    echo "  ⚠️  X-Frame-Options should be DENY"
    return 1
  fi

  if ! echo "$headers" | grep -qi "X-Content-Type-Options: nosniff"; then
    echo "  ⚠️  X-Content-Type-Options should be nosniff"
    return 1
  fi

  echo "  ✓ All required security headers present and correct"
  return 0
}

run_test "Security Headers Validation" "test_security_headers"

##############################################################################
# Test 5: SSL/TLS Configuration (HTTPS only)
##############################################################################

test_ssl_tls() {
  if [[ "$BASE_URL" == https://* ]]; then
    echo "  → Testing SSL/TLS configuration..."

    # Extract hostname
    hostname=$(echo "$BASE_URL" | sed -E 's|https?://([^/]+).*|\1|')

    # Test SSL with OpenSSL (if available)
    if command -v openssl &> /dev/null; then
      # Test for weak protocols
      if echo "" | timeout 5 openssl s_client -connect "$hostname:443" -ssl3 2>&1 | grep -q "SSL3"; then
        echo "  ⚠️  SSLv3 is enabled (vulnerable to POODLE)"
        return 1
      fi

      if echo "" | timeout 5 openssl s_client -connect "$hostname:443" -tls1 2>&1 | grep -q "TLS1"; then
        echo "  ⚠️  TLS 1.0 is enabled (deprecated)"
        return 1
      fi

      echo "  ✓ SSL/TLS configuration appears secure"
    else
      echo "  ℹ  OpenSSL not available, skipping SSL tests"
    fi

    return 0
  else
    echo "  ℹ  Not an HTTPS URL, skipping SSL tests"
    return 0
  fi
}

run_test "SSL/TLS Configuration" "test_ssl_tls"

##############################################################################
# Test 6: Information Disclosure
##############################################################################

test_information_disclosure() {
  echo "  → Testing for information disclosure..."

  # Check for server version disclosure
  headers=$(curl -s -I "$BASE_URL")

  if echo "$headers" | grep -qi "Server: nginx/[0-9]"; then
    echo "  ⚠️  Server version disclosed in headers"
    # Not failing this test as it's informational
  fi

  # Check for common sensitive files
  local sensitive_files=(
    ".git/config"
    ".env"
    "config.json"
    "package.json"
    ".DS_Store"
    "composer.json"
  )

  for file in "${sensitive_files[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$file")

    if [ "$status" = "200" ]; then
      echo "  ⚠️  Sensitive file accessible: $file"
      return 1
    fi
  done

  echo "  ✓ No critical information disclosure detected"
  return 0
}

run_test "Information Disclosure" "test_information_disclosure"

##############################################################################
# Test 7: HTTP Methods Security
##############################################################################

test_http_methods() {
  echo "  → Testing HTTP methods..."

  # Test dangerous methods
  local dangerous_methods=("TRACE" "DELETE" "PUT")

  for method in "${dangerous_methods[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL")

    if [ "$status" = "200" ]; then
      echo "  ⚠️  Dangerous HTTP method $method is allowed"
      return 1
    fi
  done

  echo "  ✓ Dangerous HTTP methods are disabled"
  return 0
}

run_test "HTTP Methods Security" "test_http_methods"

##############################################################################
# Test 8: Clickjacking Protection
##############################################################################

test_clickjacking() {
  echo "  → Testing clickjacking protection..."

  headers=$(curl -s -I "$BASE_URL")

  # Check for X-Frame-Options or CSP frame-ancestors
  if ! echo "$headers" | grep -qiE "(X-Frame-Options|Content-Security-Policy.*frame-ancestors)"; then
    echo "  ⚠️  No clickjacking protection (X-Frame-Options or CSP frame-ancestors)"
    return 1
  fi

  echo "  ✓ Clickjacking protection enabled"
  return 0
}

run_test "Clickjacking Protection" "test_clickjacking"

##############################################################################
# Test 9: MIME Sniffing Protection
##############################################################################

test_mime_sniffing() {
  echo "  → Testing MIME sniffing protection..."

  headers=$(curl -s -I "$BASE_URL")

  if ! echo "$headers" | grep -qi "X-Content-Type-Options: nosniff"; then
    echo "  ⚠️  MIME sniffing protection not enabled"
    return 1
  fi

  echo "  ✓ MIME sniffing protection enabled"
  return 0
}

run_test "MIME Sniffing Protection" "test_mime_sniffing"

##############################################################################
# Test 10: CORS Configuration
##############################################################################

test_cors() {
  echo "  → Testing CORS configuration..."

  # Test CORS with wildcard origin
  headers=$(curl -s -I -H "Origin: https://evil.com" "$BASE_URL")

  if echo "$headers" | grep -qi "Access-Control-Allow-Origin: \*"; then
    echo "  ⚠️  CORS allows all origins (wildcard)"
    # Not failing as this might be intentional for static content
  fi

  echo "  ✓ CORS configuration checked"
  return 0
}

run_test "CORS Configuration" "test_cors"

##############################################################################
# Test 11: Cookie Security (if cookies are used)
##############################################################################

test_cookie_security() {
  echo "  → Testing cookie security..."

  cookies=$(curl -s -I "$BASE_URL" | grep -i "Set-Cookie")

  if [ -n "$cookies" ]; then
    # Check for Secure flag on HTTPS
    if [[ "$BASE_URL" == https://* ]]; then
      if ! echo "$cookies" | grep -qi "Secure"; then
        echo "  ⚠️  Cookies missing Secure flag on HTTPS"
        return 1
      fi
    fi

    # Check for HttpOnly flag
    if ! echo "$cookies" | grep -qi "HttpOnly"; then
      echo "  ⚠️  Cookies missing HttpOnly flag"
      return 1
    fi

    # Check for SameSite
    if ! echo "$cookies" | grep -qi "SameSite"; then
      echo "  ⚠️  Cookies missing SameSite attribute"
      return 1
    fi
  else
    echo "  ℹ  No cookies set, skipping cookie security tests"
  fi

  return 0
}

run_test "Cookie Security" "test_cookie_security"

##############################################################################
# Test 12: Referrer Policy
##############################################################################

test_referrer_policy() {
  echo "  → Testing Referrer Policy..."

  headers=$(curl -s -I "$BASE_URL")

  if ! echo "$headers" | grep -qi "Referrer-Policy:"; then
    echo "  ⚠️  Referrer-Policy header not set"
    return 1
  fi

  echo "  ✓ Referrer-Policy header present"
  return 0
}

run_test "Referrer Policy" "test_referrer_policy"

##############################################################################
# Summary
##############################################################################

echo "═══════════════════════════════════════════════════════"
echo "Security Test Summary"
echo "═══════════════════════════════════════════════════════"
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $((TOTAL_TESTS - FAILED_TESTS))"
echo "Failed: $FAILED_TESTS"
echo "═══════════════════════════════════════════════════════"

if [ $FAILED_TESTS -eq 0 ]; then
  echo "✅ All security tests passed!"
  exit 0
else
  echo "❌ $FAILED_TESTS security test(s) failed"
  echo ""
  echo "Review the failed tests above and address the security issues."
  exit 1
fi
