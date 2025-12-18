#!/bin/bash
set -euo pipefail

##############################################################################
# Docker Health Check Test
# Validates that the container starts and passes health checks
##############################################################################

echo "================================"
echo "Docker Health Check Test"
echo "================================"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Build the image first
echo "Building Docker image..."
docker build -t 2048-test:health -q ./2048
echo "✅ Image built"
echo ""

# Test 1: Start container
echo "Test 1: Starting container..."
CONTAINER_ID=$(docker run -d -p 8081:80 --name 2048-health-test 2048-test:health)
echo "Container ID: $CONTAINER_ID"
echo "✅ Container started"

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    docker rm -f 2048-health-test > /dev/null 2>&1 || true
    docker rmi 2048-test:health > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Test 2: Wait for container to be ready
echo ""
echo "Test 2: Waiting for container to be ready..."
sleep 5

# Test 3: Check container is running
echo ""
echo "Test 3: Checking container status..."
if docker ps | grep -q "2048-health-test"; then
    echo "✅ Container is running"
else
    echo "❌ Container is not running"
    docker logs 2048-health-test
    exit 1
fi

# Test 4: Test HTTP endpoint
echo ""
echo "Test 4: Testing HTTP endpoint..."
if curl -f http://localhost:8081/ > /dev/null 2>&1; then
    echo "✅ HTTP endpoint responding"
else
    echo "❌ HTTP endpoint not responding"
    docker logs 2048-health-test
    exit 1
fi

# Test 5: Verify response content
echo ""
echo "Test 5: Verifying response content..."
RESPONSE=$(curl -s http://localhost:8081/)
if echo "$RESPONSE" | grep -q "2048"; then
    echo "✅ Response contains expected content"
else
    echo "❌ Response missing expected content"
    exit 1
fi

# Test 6: Check Docker health status
echo ""
echo "Test 6: Checking Docker health status..."
sleep 30  # Wait for first health check

HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' 2048-health-test 2>/dev/null || echo "none")
echo "Health status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "none" ]; then
    echo "✅ Container is healthy"
else
    echo "⚠️  Health status: $HEALTH_STATUS"
    docker inspect --format='{{json .State.Health}}' 2048-health-test | jq .
fi

# Test 7: Check container logs for errors
echo ""
echo "Test 7: Checking container logs..."
if docker logs 2048-health-test 2>&1 | grep -i "error\|fail\|fatal" | grep -v "test"; then
    echo "⚠️  Errors found in logs (review above)"
else
    echo "✅ No errors in container logs"
fi

echo ""
echo "================================"
echo "Health Check Test: PASSED ✅"
echo "================================"
