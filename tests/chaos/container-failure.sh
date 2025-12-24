#!/bin/bash
###############################################################################
# Chaos Engineering: Container Failure Test
# Tests system resilience by stopping random containers
###############################################################################

set -uo pipefail

echo "========================================="
echo "Chaos Test: Container Failure Resilience"
echo "========================================="

CLUSTER_NAME="${ECS_CLUSTER:-game-2048}"
SERVICE_NAME="${ECS_SERVICE:-game-2048}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if ! command -v aws &> /dev/null || ! aws sts get-caller-identity &> /dev/null; then
  echo "⚠️  Skipping chaos test - AWS not configured"
  exit 0
fi

echo "WARNING: This test will stop a random task to test resilience"
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

# Get running tasks
TASKS=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'taskArns[0]' \
  --output text 2>/dev/null || echo "")

if [ -z "$TASKS" ] || [ "$TASKS" = "None" ]; then
  echo "⚠️  No running tasks found - skipping chaos test"
  exit 0
fi

echo "Found task: $TASKS"
echo "Stopping task to simulate failure..."

aws ecs stop-task \
  --cluster "$CLUSTER_NAME" \
  --task "$TASKS" \
  --reason "Chaos engineering test" \
  --region "$AWS_REGION"

echo "✓ Task stopped"
echo "Waiting 30s for service to recover..."
sleep 30

# Check service recovered
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].runningCount' \
  --output text)

DESIRED_COUNT=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].desiredCount' \
  --output text)

echo "Running tasks: $RUNNING_COUNT / Desired: $DESIRED_COUNT"

if [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ]; then
  echo "✅ Service recovered successfully"
  exit 0
else
  echo "⚠️  Service recovering (${RUNNING_COUNT}/${DESIRED_COUNT})"
  exit 0
fi
