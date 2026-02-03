#!/bin/bash
set -euo pipefail

# ============================================================
# Rollback Script for Blue/Green Deployment
# ============================================================
#
# Switches ALB traffic back to the previously active environment.
# This is an instant rollback (< 30 seconds) because the old
# environment is still running.
#
# Usage:
#   ./scripts/rollback.sh \
#     --cluster game-2048 \
#     --region us-east-1 \
#     --listener-arn <arn> \
#     --target-tg-arn <arn>
#
#   Or auto-detect previous environment:
#   ./scripts/rollback.sh \
#     --cluster game-2048 \
#     --region us-east-1 \
#     --listener-arn <arn> \
#     --tg-blue-arn <arn> \
#     --tg-green-arn <arn>
#
# Exit codes:
#   0 - Rollback successful
#   1 - Rollback failed
# ============================================================

CLUSTER=""
REGION="us-east-1"
LISTENER_ARN=""
TARGET_TG_ARN=""
TG_BLUE_ARN=""
TG_GREEN_ARN=""

usage() {
  echo "Usage: $0 --cluster <name> --listener-arn <arn> [options]"
  echo ""
  echo "Options:"
  echo "  --cluster        ECS cluster name (required)"
  echo "  --region         AWS region (default: us-east-1)"
  echo "  --listener-arn   ALB listener ARN (required)"
  echo "  --target-tg-arn  Target group ARN to switch to (explicit rollback target)"
  echo "  --tg-blue-arn    Blue target group ARN (for auto-detect mode)"
  echo "  --tg-green-arn   Green target group ARN (for auto-detect mode)"
  echo "  --help           Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --listener-arn) LISTENER_ARN="$2"; shift 2 ;;
    --target-tg-arn) TARGET_TG_ARN="$2"; shift 2 ;;
    --tg-blue-arn) TG_BLUE_ARN="$2"; shift 2 ;;
    --tg-green-arn) TG_GREEN_ARN="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$CLUSTER" ] || [ -z "$LISTENER_ARN" ]; then
  echo "ERROR: --cluster and --listener-arn are required"
  usage
  exit 1
fi

echo "============================================"
echo "  ROLLBACK INITIATED"
echo "============================================"
echo ""
echo "  Cluster:  $CLUSTER"
echo "  Region:   $REGION"
echo "  Listener: ${LISTENER_ARN:0:60}..."
echo ""

# Step 1: Determine rollback target
if [ -z "$TARGET_TG_ARN" ]; then
  echo "[1/3] Auto-detecting rollback target..."

  if [ -z "$TG_BLUE_ARN" ] || [ -z "$TG_GREEN_ARN" ]; then
    echo "ERROR: Either --target-tg-arn or both --tg-blue-arn and --tg-green-arn required"
    exit 1
  fi

  # Get current active target group
  CURRENT_TG=$(aws elbv2 describe-rules \
    --listener-arn "$LISTENER_ARN" \
    --region "$REGION" \
    --query 'Rules[?IsDefault==`true`].Actions[0].TargetGroupArn' \
    --output text)

  echo "  Current active TG: ${CURRENT_TG:0:60}..."

  # Switch to the other one
  if [ "$CURRENT_TG" = "$TG_BLUE_ARN" ]; then
    TARGET_TG_ARN="$TG_GREEN_ARN"
    echo "  Rolling back: blue -> green"
  elif [ "$CURRENT_TG" = "$TG_GREEN_ARN" ]; then
    TARGET_TG_ARN="$TG_BLUE_ARN"
    echo "  Rolling back: green -> blue"
  else
    echo "ERROR: Current target group doesn't match blue or green"
    echo "  Current: $CURRENT_TG"
    echo "  Blue:    $TG_BLUE_ARN"
    echo "  Green:   $TG_GREEN_ARN"
    exit 1
  fi
else
  echo "[1/3] Using explicit rollback target"
  echo "  Target TG: ${TARGET_TG_ARN:0:60}..."
fi

# Step 2: Switch ALB traffic
echo ""
echo "[2/3] Switching ALB traffic..."

RULE_ARN=$(aws elbv2 describe-rules \
  --listener-arn "$LISTENER_ARN" \
  --region "$REGION" \
  --query 'Rules[?IsDefault==`true`].RuleArn' \
  --output text)

aws elbv2 modify-rule \
  --rule-arn "$RULE_ARN" \
  --actions "Type=forward,TargetGroupArn=$TARGET_TG_ARN" \
  --region "$REGION"

echo "  Traffic switched successfully"

# Step 3: Verify rollback
echo ""
echo "[3/3] Verifying rollback..."

VERIFY_TG=$(aws elbv2 describe-rules \
  --listener-arn "$LISTENER_ARN" \
  --region "$REGION" \
  --query 'Rules[?IsDefault==`true`].Actions[0].TargetGroupArn' \
  --output text)

if [ "$VERIFY_TG" = "$TARGET_TG_ARN" ]; then
  echo "  Verified: traffic is now routed to rollback target"
else
  echo "  ERROR: Verification failed - traffic may not be correctly routed"
  echo "  Expected: $TARGET_TG_ARN"
  echo "  Actual:   $VERIFY_TG"
  exit 1
fi

echo ""
echo "============================================"
echo "  ROLLBACK COMPLETED SUCCESSFULLY"
echo "============================================"
echo ""
echo "  Traffic is now routed to the previous version."
echo "  The failed deployment is still running for debugging."
echo ""
echo "  Next steps:"
echo "  1. Investigate the failed deployment logs"
echo "  2. Fix the issue and push a new commit"
echo "  3. The pipeline will deploy to the standby environment"
echo "============================================"
