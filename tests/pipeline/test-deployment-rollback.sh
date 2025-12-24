#!/bin/bash

###############################################################################
# Deployment Rollback Test
# Tests ECS deployment rollback functionality
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================="
echo "ECS Deployment Rollback Test"
echo "========================================="

# Configuration
CLUSTER_NAME="${ECS_CLUSTER:-game-2048}"
SERVICE_NAME="${ECS_SERVICE:-game-2048}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
  echo "❌ Error: AWS CLI is not installed"
  echo "Please install AWS CLI: https://aws.amazon.com/cli/"
  exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
  echo "⚠️  Warning: AWS credentials not configured"
  echo "This test requires AWS credentials to validate rollback capability"
  echo ""
  echo "Skipping deployment rollback test..."
  exit 0
fi

echo "✓ AWS CLI found and configured"
echo ""

# Check if cluster exists
echo "Checking if ECS cluster exists..."
if aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'clusters[0].status' \
  --output text 2>/dev/null | grep -q "ACTIVE"; then
  echo "✓ Cluster '$CLUSTER_NAME' exists"
else
  echo "⚠️  Cluster '$CLUSTER_NAME' not found"
  echo "Rollback test requires an existing ECS cluster"
  echo "Skipping deployment rollback test..."
  exit 0
fi

# Check if service exists
echo "Checking if ECS service exists..."
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].status' \
  --output text 2>/dev/null || echo "MISSING")

if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
  echo "✓ Service '$SERVICE_NAME' exists"
else
  echo "⚠️  Service '$SERVICE_NAME' not found or inactive"
  echo "Rollback test requires an active ECS service"
  echo "Skipping deployment rollback test..."
  exit 0
fi

echo ""
echo "Running rollback capability checks..."
echo "----------------------------------------"

# 1. Check deployment configuration
echo "1. Checking deployment configuration..."
DEPLOYMENT_CONFIG=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].deploymentConfiguration' \
  --output json)

MAX_PERCENT=$(echo "$DEPLOYMENT_CONFIG" | jq -r '.maximumPercent')
MIN_HEALTHY=$(echo "$DEPLOYMENT_CONFIG" | jq -r '.minimumHealthyPercent')

echo "   Maximum Percent: $MAX_PERCENT%"
echo "   Minimum Healthy Percent: $MIN_HEALTHY%"

# Validate deployment configuration allows zero-downtime rollback
if [ "$MAX_PERCENT" -ge 200 ] && [ "$MIN_HEALTHY" -ge 100 ]; then
  echo "   ✅ Configuration supports zero-downtime rollback"
elif [ "$MIN_HEALTHY" -ge 50 ]; then
  echo "   ⚠️  Configuration allows some downtime during rollback"
else
  echo "   ❌ Configuration may cause significant downtime"
  exit 1
fi

# 2. Check deployment circuit breaker
echo ""
echo "2. Checking deployment circuit breaker..."
CIRCUIT_BREAKER=$(echo "$DEPLOYMENT_CONFIG" | jq -r '.deploymentCircuitBreaker // {}')
CB_ENABLED=$(echo "$CIRCUIT_BREAKER" | jq -r '.enable // false')
CB_ROLLBACK=$(echo "$CIRCUIT_BREAKER" | jq -r '.rollback // false')

if [ "$CB_ENABLED" = "true" ]; then
  echo "   ✅ Deployment circuit breaker is enabled"
  if [ "$CB_ROLLBACK" = "true" ]; then
    echo "   ✅ Automatic rollback is enabled"
  else
    echo "   ⚠️  Automatic rollback is disabled"
  fi
else
  echo "   ⚠️  Deployment circuit breaker is disabled"
  echo "   Recommendation: Enable circuit breaker for automatic rollback"
fi

# 3. Check task definition versions
echo ""
echo "3. Checking task definition versions (rollback targets)..."
TASK_DEFINITION_FAMILY=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].taskDefinition' \
  --output text | cut -d'/' -f2 | cut -d':' -f1)

# List recent task definition versions
RECENT_VERSIONS=$(aws ecs list-task-definitions \
  --family-prefix "$TASK_DEFINITION_FAMILY" \
  --region "$AWS_REGION" \
  --max-items 5 \
  --sort DESC \
  --query 'taskDefinitionArns' \
  --output json)

VERSION_COUNT=$(echo "$RECENT_VERSIONS" | jq 'length')
echo "   Available task definition versions: $VERSION_COUNT"

if [ "$VERSION_COUNT" -ge 2 ]; then
  echo "   ✅ Multiple versions available for rollback"
  echo "$RECENT_VERSIONS" | jq -r '.[] | "   - \(.)"'
else
  echo "   ⚠️  Only one version available - cannot rollback"
fi

# 4. Check service events for rollback history
echo ""
echo "4. Checking deployment history..."
RECENT_EVENTS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].events[0:5]' \
  --output json)

echo "   Recent service events:"
echo "$RECENT_EVENTS" | jq -r '.[] | "   [\(.createdAt)] \(.message)"' | head -5

# 5. Validate health check configuration
echo ""
echo "5. Checking health check configuration..."
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].taskDefinition' \
  --output text)

HEALTH_CHECK=$(aws ecs describe-task-definition \
  --task-definition "$CURRENT_TASK_DEF" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.containerDefinitions[0].healthCheck' \
  --output json)

if [ "$HEALTH_CHECK" != "null" ] && [ -n "$HEALTH_CHECK" ]; then
  echo "   ✅ Health check configured in task definition"
  INTERVAL=$(echo "$HEALTH_CHECK" | jq -r '.interval // 30')
  RETRIES=$(echo "$HEALTH_CHECK" | jq -r '.retries // 3')
  echo "   - Interval: ${INTERVAL}s"
  echo "   - Retries: $RETRIES"
else
  echo "   ⚠️  No health check configured"
  echo "   Recommendation: Add health check for faster failure detection"
fi

# 6. Check load balancer configuration
echo ""
echo "6. Checking load balancer integration..."
LOAD_BALANCERS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].loadBalancers' \
  --output json)

if [ "$LOAD_BALANCERS" != "[]" ] && [ "$LOAD_BALANCERS" != "null" ]; then
  echo "   ✅ Load balancer configured"
  LB_COUNT=$(echo "$LOAD_BALANCERS" | jq 'length')
  echo "   - Load balancers: $LB_COUNT"

  # Get target group health check settings
  TARGET_GROUP_ARN=$(echo "$LOAD_BALANCERS" | jq -r '.[0].targetGroupArn')
  if [ -n "$TARGET_GROUP_ARN" ] && [ "$TARGET_GROUP_ARN" != "null" ]; then
    TG_HEALTH=$(aws elbv2 describe-target-groups \
      --target-group-arns "$TARGET_GROUP_ARN" \
      --region "$AWS_REGION" \
      --query 'TargetGroups[0].[HealthCheckIntervalSeconds,HealthyThresholdCount,UnhealthyThresholdCount]' \
      --output json 2>/dev/null || echo "[]")

    if [ "$TG_HEALTH" != "[]" ]; then
      INTERVAL=$(echo "$TG_HEALTH" | jq -r '.[0]')
      HEALTHY=$(echo "$TG_HEALTH" | jq -r '.[1]')
      UNHEALTHY=$(echo "$TG_HEALTH" | jq -r '.[2]')

      echo "   - Health check interval: ${INTERVAL}s"
      echo "   - Healthy threshold: $HEALTHY"
      echo "   - Unhealthy threshold: $UNHEALTHY"

      # Calculate rollback detection time
      ROLLBACK_TIME=$((INTERVAL * UNHEALTHY))
      echo "   - Estimated failure detection time: ${ROLLBACK_TIME}s"
    fi
  fi
else
  echo "   ⚠️  No load balancer configured"
fi

# Summary
echo ""
echo "========================================="
echo "Rollback Capability Summary"
echo "========================================="
echo "✅ Cluster and service exist"
echo "✅ Deployment configuration validated"

if [ "$CB_ENABLED" = "true" ] && [ "$CB_ROLLBACK" = "true" ]; then
  echo "✅ Automatic rollback enabled"
  ROLLBACK_SCORE=100
elif [ "$CB_ENABLED" = "true" ]; then
  echo "⚠️  Manual rollback required"
  ROLLBACK_SCORE=75
else
  echo "⚠️  No automatic rollback configured"
  ROLLBACK_SCORE=50
fi

if [ "$VERSION_COUNT" -ge 2 ]; then
  echo "✅ Previous versions available for rollback"
else
  echo "⚠️  Limited rollback options"
fi

echo ""
if [ $ROLLBACK_SCORE -ge 75 ]; then
  echo "✅ Rollback capability: GOOD"
  exit 0
elif [ $ROLLBACK_SCORE -ge 50 ]; then
  echo "⚠️  Rollback capability: ACCEPTABLE"
  echo "Recommendation: Enable automatic rollback for better reliability"
  exit 0
else
  echo "❌ Rollback capability: NEEDS IMPROVEMENT"
  echo "Recommendation: Configure deployment circuit breaker with automatic rollback"
  exit 1
fi
