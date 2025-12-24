#!/bin/bash

###############################################################################
# Zero-Downtime Deployment Test
# Validates ECS service configuration for zero-downtime deployments
###############################################################################

set -euo pipefail

echo "========================================="
echo "Zero-Downtime Deployment Test"
echo "========================================="

# Configuration
CLUSTER_NAME="${ECS_CLUSTER:-game-2048}"
SERVICE_NAME="${ECS_SERVICE:-game-2048}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
  echo "⚠️  AWS CLI not installed - skipping zero-downtime test"
  exit 0
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
  echo "⚠️  AWS credentials not configured - skipping zero-downtime test"
  exit 0
fi

echo "✓ AWS CLI configured"
echo ""

# Check if service exists
if ! aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].status' \
  --output text 2>/dev/null | grep -q "ACTIVE"; then
  echo "⚠️  Service not found - skipping zero-downtime test"
  exit 0
fi

echo "Analyzing zero-downtime configuration..."
echo "----------------------------------------"

# Get service details
SERVICE_JSON=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --output json)

# 1. Check desired task count
echo ""
echo "1. Task redundancy check..."
DESIRED_COUNT=$(echo "$SERVICE_JSON" | jq -r '.services[0].desiredCount')
RUNNING_COUNT=$(echo "$SERVICE_JSON" | jq -r '.services[0].runningCount')

echo "   Desired tasks: $DESIRED_COUNT"
echo "   Running tasks: $RUNNING_COUNT"

if [ "$DESIRED_COUNT" -ge 2 ]; then
  echo "   ✅ Multiple tasks for redundancy"
  REDUNDANCY_SCORE=100
else
  echo "   ❌ Single task - downtime during deployments"
  REDUNDANCY_SCORE=0
fi

# 2. Check deployment configuration
echo ""
echo "2. Deployment configuration..."
MAX_PERCENT=$(echo "$SERVICE_JSON" | jq -r '.services[0].deploymentConfiguration.maximumPercent')
MIN_HEALTHY=$(echo "$SERVICE_JSON" | jq -r '.services[0].deploymentConfiguration.minimumHealthyPercent')

echo "   Maximum percent: $MAX_PERCENT%"
echo "   Minimum healthy percent: $MIN_HEALTHY%"

# Calculate if zero-downtime is possible
if [ "$MAX_PERCENT" -ge 200 ] && [ "$MIN_HEALTHY" -eq 100 ]; then
  echo "   ✅ Perfect zero-downtime configuration"
  echo "   - New tasks start before old tasks stop"
  echo "   - 100% capacity maintained during deployment"
  DEPLOYMENT_SCORE=100
elif [ "$MIN_HEALTHY" -ge 100 ]; then
  echo "   ✅ Zero-downtime capable"
  echo "   - Full capacity maintained"
  DEPLOYMENT_SCORE=90
elif [ "$MIN_HEALTHY" -ge 50 ] && [ "$DESIRED_COUNT" -ge 2 ]; then
  echo "   ⚠️  Reduced capacity during deployment"
  echo "   - Some requests may be slower"
  DEPLOYMENT_SCORE=60
else
  echo "   ❌ Downtime likely during deployment"
  DEPLOYMENT_SCORE=20
fi

# 3. Check health check configuration
echo ""
echo "3. Health check configuration..."
LOAD_BALANCERS=$(echo "$SERVICE_JSON" | jq -r '.services[0].loadBalancers')

if [ "$LOAD_BALANCERS" != "[]" ] && [ "$LOAD_BALANCERS" != "null" ]; then
  echo "   ✅ Load balancer configured"

  TARGET_GROUP_ARN=$(echo "$LOAD_BALANCERS" | jq -r '.[0].targetGroupArn')
  if [ -n "$TARGET_GROUP_ARN" ] && [ "$TARGET_GROUP_ARN" != "null" ]; then
    TG_INFO=$(aws elbv2 describe-target-groups \
      --target-group-arns "$TARGET_GROUP_ARN" \
      --region "$AWS_REGION" \
      --output json 2>/dev/null || echo "{}")

    if [ "$TG_INFO" != "{}" ]; then
      HC_INTERVAL=$(echo "$TG_INFO" | jq -r '.TargetGroups[0].HealthCheckIntervalSeconds')
      HC_TIMEOUT=$(echo "$TG_INFO" | jq -r '.TargetGroups[0].HealthCheckTimeoutSeconds')
      HEALTHY_THRESHOLD=$(echo "$TG_INFO" | jq -r '.TargetGroups[0].HealthyThresholdCount')
      UNHEALTHY_THRESHOLD=$(echo "$TG_INFO" | jq -r '.TargetGroups[0].UnhealthyThresholdCount')

      echo "   - Health check interval: ${HC_INTERVAL}s"
      echo "   - Health check timeout: ${HC_TIMEOUT}s"
      echo "   - Healthy threshold: $HEALTHY_THRESHOLD"
      echo "   - Unhealthy threshold: $UNHEALTHY_THRESHOLD"

      # Calculate health check times
      TIME_TO_HEALTHY=$((HC_INTERVAL * HEALTHY_THRESHOLD))
      TIME_TO_UNHEALTHY=$((HC_INTERVAL * UNHEALTHY_THRESHOLD))

      echo "   - Time to mark healthy: ${TIME_TO_HEALTHY}s"
      echo "   - Time to mark unhealthy: ${TIME_TO_UNHEALTHY}s"

      if [ "$TIME_TO_HEALTHY" -le 60 ]; then
        echo "   ✅ Fast health check response"
        HEALTH_SCORE=100
      elif [ "$TIME_TO_HEALTHY" -le 120 ]; then
        echo "   ⚠️  Moderate health check response"
        HEALTH_SCORE=75
      else
        echo "   ⚠️  Slow health check response"
        HEALTH_SCORE=50
      fi
    else
      HEALTH_SCORE=50
    fi
  else
    HEALTH_SCORE=50
  fi
else
  echo "   ⚠️  No load balancer configured"
  echo "   - Cannot validate health checks"
  HEALTH_SCORE=0
fi

# 4. Check deregistration delay
echo ""
echo "4. Connection draining configuration..."
if [ -n "$TARGET_GROUP_ARN" ] && [ "$TARGET_GROUP_ARN" != "null" ]; then
  DEREG_DELAY=$(aws elbv2 describe-target-group-attributes \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --region "$AWS_REGION" \
    --query 'Attributes[?Key==`deregistration_delay.timeout_seconds`].Value' \
    --output text 2>/dev/null || echo "300")

  echo "   Deregistration delay: ${DEREG_DELAY}s"

  if [ "$DEREG_DELAY" -le 30 ]; then
    echo "   ✅ Fast connection draining"
    DRAIN_SCORE=100
  elif [ "$DEREG_DELAY" -le 60 ]; then
    echo "   ⚠️  Moderate connection draining"
    DRAIN_SCORE=75
  else
    echo "   ⚠️  Slow connection draining"
    echo "   - Deployment will take longer"
    DRAIN_SCORE=50
  fi
else
  DRAIN_SCORE=50
fi

# 5. Calculate estimated deployment time
echo ""
echo "5. Estimated deployment time..."
if [ -n "$TIME_TO_HEALTHY" ] && [ -n "$DEREG_DELAY" ]; then
  # Time for new task to become healthy
  NEW_TASK_START=30  # Container start time
  DEPLOYMENT_TIME=$((NEW_TASK_START + TIME_TO_HEALTHY + DEREG_DELAY))

  echo "   Container start: ~${NEW_TASK_START}s"
  echo "   Health check validation: ${TIME_TO_HEALTHY}s"
  echo "   Connection draining: ${DEREG_DELAY}s"
  echo "   ----------------------------------------"
  echo "   Total estimated time: ~${DEPLOYMENT_TIME}s ($(($DEPLOYMENT_TIME / 60))m)"

  if [ "$DEPLOYMENT_TIME" -le 120 ]; then
    echo "   ✅ Fast deployment"
  elif [ "$DEPLOYMENT_TIME" -le 300 ]; then
    echo "   ⚠️  Moderate deployment time"
  else
    echo "   ⚠️  Slow deployment"
  fi
fi

# Calculate overall zero-downtime score
echo ""
echo "========================================="
echo "Zero-Downtime Assessment"
echo "========================================="

TOTAL_SCORE=$(( (REDUNDANCY_SCORE + DEPLOYMENT_SCORE + HEALTH_SCORE + DRAIN_SCORE) / 4 ))

echo "Redundancy:        $REDUNDANCY_SCORE/100"
echo "Deployment Config: $DEPLOYMENT_SCORE/100"
echo "Health Checks:     $HEALTH_SCORE/100"
echo "Conn Draining:     $DRAIN_SCORE/100"
echo "----------------------------------------"
echo "Overall Score:     $TOTAL_SCORE/100"
echo ""

if [ "$TOTAL_SCORE" -ge 90 ]; then
  echo "✅ EXCELLENT: True zero-downtime deployments"
  exit 0
elif [ "$TOTAL_SCORE" -ge 70 ]; then
  echo "✅ GOOD: Zero-downtime with minor caveats"
  exit 0
elif [ "$TOTAL_SCORE" -ge 50 ]; then
  echo "⚠️  ACCEPTABLE: Minimal downtime possible"
  echo "Recommendations:"
  [ "$REDUNDANCY_SCORE" -lt 100 ] && echo "  - Increase desired task count to 2+"
  [ "$DEPLOYMENT_SCORE" -lt 90 ] && echo "  - Set minimumHealthyPercent to 100"
  [ "$HEALTH_SCORE" -lt 75 ] && echo "  - Optimize health check intervals"
  [ "$DRAIN_SCORE" -lt 75 ] && echo "  - Reduce deregistration delay"
  exit 0
else
  echo "❌ POOR: Significant downtime expected"
  echo "Critical improvements needed:"
  [ "$REDUNDANCY_SCORE" -eq 0 ] && echo "  - CRITICAL: Add at least 2 tasks"
  [ "$DEPLOYMENT_SCORE" -lt 50 ] && echo "  - CRITICAL: Fix deployment configuration"
  exit 1
fi
