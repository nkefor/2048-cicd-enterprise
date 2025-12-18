#!/bin/bash
set -euo pipefail

##############################################################################
# Docker Build Test
# Validates that the Dockerfile builds successfully without errors
##############################################################################

echo "================================"
echo "Docker Build Test"
echo "================================"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Test 1: Build the image
echo "Test 1: Building Docker image..."
if docker build -t 2048-test:build ./2048; then
    echo "✅ Docker build successful"
else
    echo "❌ Docker build failed"
    exit 1
fi

# Test 2: Check image size
echo ""
echo "Test 2: Checking image size..."
IMAGE_SIZE=$(docker images 2048-test:build --format "{{.Size}}")
echo "Image size: $IMAGE_SIZE"

# Extract numeric value (rough check - should be under 100MB)
SIZE_MB=$(docker images 2048-test:build --format "{{.Size}}" | grep -oE '[0-9]+' | head -1)
if [ "$SIZE_MB" -lt 100 ]; then
    echo "✅ Image size is acceptable (< 100MB)"
else
    echo "⚠️  Image size is larger than expected (> 100MB)"
fi

# Test 3: Verify image was created
echo ""
echo "Test 3: Verifying image exists..."
if docker images | grep -q "2048-test.*build"; then
    echo "✅ Image exists in local registry"
else
    echo "❌ Image not found in local registry"
    exit 1
fi

# Test 4: Inspect image layers
echo ""
echo "Test 4: Inspecting image layers..."
LAYER_COUNT=$(docker history 2048-test:build --format "{{.ID}}" | wc -l)
echo "Number of layers: $LAYER_COUNT"

if [ "$LAYER_COUNT" -lt 20 ]; then
    echo "✅ Layer count is reasonable (< 20)"
else
    echo "⚠️  Many layers detected - consider optimizing Dockerfile"
fi

# Cleanup
echo ""
echo "Cleaning up test image..."
docker rmi 2048-test:build

echo ""
echo "================================"
echo "Build Test: PASSED ✅"
echo "================================"
