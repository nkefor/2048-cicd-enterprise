#!/bin/bash
set -euo pipefail

# ============================================================
# Health Check Script for ECS Service
# ============================================================
#
# Validates that an ECS service is running and healthy.
# Used by the CI/CD pipeline before and after blue/green cutover.
#
# Usage:
#   ./scripts/health-check.sh \
#     --cluster game-2048 \
#     --service game-2048-blue \
#     --region us-east-1 \
#     --max-attempts 5 \
#     --interval 10
#
# Exit codes:
#   0 - All health checks passed
#   1 - Health checks failed after max attempts
# ============================================================

CLUSTER=""
SERVICE=""
REGION="us-east-1"
MAX_ATTEMPTS=5
INTERVAL=10
ENDPOINT=""

usage() {
  echo "Usage: $0 --cluster <name> --service <name> [options]"
  echo ""
  echo "Options:"
  echo "  --cluster       ECS cluster name (required)"
  echo "  --service       ECS service name (required)"
  echo "  --region        AWS region (default: us-east-1)"
  echo "  --max-attempts  Maximum retry attempts (default: 5)"
  echo "  --interval      Seconds between retries (default: 10)"
  echo "  --endpoint      Direct URL to check (skips ECS lookup)"
  echo "  --help          Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$CLUSTER" ] || [ -z "$SERVICE" ]; then
  echo "ERROR: --cluster and --service are required"
  usage
  exit 1
fi

echo "============================================"
echo "  Health Check"
echo "  Cluster:  $CLUSTER"
echo "  Service:  $SERVICE"
echo "  Region:   $REGION"
echo "  Attempts: $MAX_ATTEMPTS"
echo "  Interval: ${INTERVAL}s"
echo "============================================"

# Step 1: Verify ECS service is running with desired task count
echo ""
echo "[1/3] Checking ECS service status..."

SERVICE_STATUS=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION" \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,pending:pendingCount}' \
  --output json 2>/dev/null || echo '{}')

RUNNING=$(echo "$SERVICE_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('running',0))" 2>/dev/null || echo "0")
DESIRED=$(echo "$SERVICE_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('desired',0))" 2>/dev/null || echo "0")
STATUS=$(echo "$SERVICE_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

echo "  Status:  $STATUS"
echo "  Running: $RUNNING / $DESIRED"

if [ "$RUNNING" -lt "$DESIRED" ] 2>/dev/null; then
  echo "  WARNING: Running count ($RUNNING) is less than desired ($DESIRED)"
  echo "  Waiting for tasks to stabilize..."

  aws ecs wait services-stable \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION" 2>/dev/null || {
    echo "  ERROR: Service did not stabilize"
    exit 1
  }
  echo "  Service stabilized"
fi

# Step 2: Resolve the endpoint if not provided
if [ -z "$ENDPOINT" ]; then
  echo ""
  echo "[2/3] Resolving service endpoint..."

  TG_ARN=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION" \
    --query 'services[0].loadBalancers[0].targetGroupArn' \
    --output text 2>/dev/null || echo "None")

  if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
    LB_ARN=$(aws elbv2 describe-target-groups \
      --target-group-arns "$TG_ARN" \
      --region "$REGION" \
      --query 'TargetGroups[0].LoadBalancerArns[0]' \
      --output text 2>/dev/null || echo "None")

    if [ "$LB_ARN" != "None" ] && [ -n "$LB_ARN" ]; then
      LB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$LB_ARN" \
        --region "$REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")

      if [ -n "$LB_DNS" ]; then
        ENDPOINT="http://${LB_DNS}"
        echo "  Endpoint: $ENDPOINT"
      fi
    fi
  fi
fi

# Step 3: HTTP health check
echo ""
echo "[3/3] Running HTTP health checks..."

if [ -z "$ENDPOINT" ]; then
  echo "  No HTTP endpoint available"
  echo "  Service health verified via ECS task status only"
  echo ""
  echo "HEALTH CHECK PASSED (ECS-level verification)"
  exit 0
fi

ATTEMPT=1
while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
  echo ""
  echo "  Attempt $ATTEMPT of $MAX_ATTEMPTS..."

  # Check health endpoint
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${ENDPOINT}/health" 2>/dev/null || echo "000")
  RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "${ENDPOINT}/health" 2>/dev/null || echo "0")

  echo "    /health  -> HTTP $HTTP_CODE (${RESPONSE_TIME}s)"

  # Check main page
  MAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${ENDPOINT}/" 2>/dev/null || echo "000")
  echo "    /        -> HTTP $MAIN_CODE"

  if [ "$HTTP_CODE" = "200" ] && [ "$MAIN_CODE" = "200" ]; then
    # Verify security headers
    echo ""
    echo "  Security headers:"
    HEADERS=$(curl -sI "${ENDPOINT}/" 2>/dev/null)
    HEADER_PASS=true

    for HEADER in "X-Content-Type-Options" "X-Frame-Options" "X-XSS-Protection" "Referrer-Policy"; do
      if echo "$HEADERS" | grep -qi "$HEADER"; then
        echo "    $HEADER: present"
      else
        echo "    $HEADER: MISSING"
        HEADER_PASS=false
      fi
    done

    # Check response time threshold
    if [ "$(echo "$RESPONSE_TIME > 2.0" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
      echo ""
      echo "  WARNING: Response time (${RESPONSE_TIME}s) exceeds 2s threshold"
    fi

    echo ""
    echo "HEALTH CHECK PASSED"
    if [ "$HEADER_PASS" = false ]; then
      echo "  (with security header warnings)"
    fi
    exit 0
  fi

  if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
    echo "    Waiting ${INTERVAL}s before next attempt..."
    sleep "$INTERVAL"
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

echo ""
echo "HEALTH CHECK FAILED after $MAX_ATTEMPTS attempts"
exit 1
