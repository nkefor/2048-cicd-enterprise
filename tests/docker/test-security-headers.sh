#!/bin/bash
set -euo pipefail

##############################################################################
# Security Headers Test
# Validates that all required security headers are present
##############################################################################

echo "================================"
echo "Security Headers Test"
echo "================================"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Build and start container
echo "Building and starting container..."
docker build -t 2048-test:security -q ./2048
CONTAINER_ID=$(docker run -d -p 8082:80 --name 2048-security-test 2048-test:security)
echo "✅ Container started"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    docker rm -f 2048-security-test > /dev/null 2>&1 || true
    docker rmi 2048-test:security > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for container to be ready
sleep 5

# Function to test header
test_header() {
    local header_name="$1"
    local expected_value="$2"
    local actual_value

    actual_value=$(curl -sI http://localhost:8082/ | grep -i "^$header_name:" | cut -d' ' -f2- | tr -d '\r')

    if [ -z "$actual_value" ]; then
        echo "❌ $header_name: MISSING"
        return 1
    elif [ "$actual_value" = "$expected_value" ]; then
        echo "✅ $header_name: $actual_value"
        return 0
    else
        echo "⚠️  $header_name: Expected '$expected_value', got '$actual_value'"
        return 1
    fi
}

# Test all security headers
echo "Testing security headers..."
echo ""

FAILED=0

test_header "X-Content-Type-Options" "nosniff" || FAILED=$((FAILED + 1))
test_header "X-Frame-Options" "DENY" || FAILED=$((FAILED + 1))
test_header "X-XSS-Protection" "1; mode=block" || FAILED=$((FAILED + 1))
test_header "Referrer-Policy" "no-referrer-when-downgrade" || FAILED=$((FAILED + 1))

echo ""
echo "Testing Content-Type header..."
CONTENT_TYPE=$(curl -sI http://localhost:8082/ | grep -i "^Content-Type:" | cut -d' ' -f2- | tr -d '\r')
if echo "$CONTENT_TYPE" | grep -q "text/html"; then
    echo "✅ Content-Type: $CONTENT_TYPE"
else
    echo "❌ Content-Type: Expected 'text/html', got '$CONTENT_TYPE'"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "Testing HTTP status code..."
STATUS_CODE=$(curl -sI http://localhost:8082/ | grep "HTTP" | cut -d' ' -f2)
if [ "$STATUS_CODE" = "200" ]; then
    echo "✅ Status Code: 200"
else
    echo "❌ Status Code: Expected 200, got $STATUS_CODE"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "================================"
if [ $FAILED -eq 0 ]; then
    echo "Security Headers Test: PASSED ✅"
    echo "================================"
    exit 0
else
    echo "Security Headers Test: FAILED ❌"
    echo "$FAILED test(s) failed"
    echo "================================"
    exit 1
fi
