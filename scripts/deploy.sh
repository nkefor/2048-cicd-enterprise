#!/bin/bash
set -euo pipefail

# ============================================================
# Deployment Orchestration Script
# ============================================================
#
# Orchestrates a full blue/green deployment locally or in CI.
# Wraps the individual steps: build, push, deploy, switch, verify.
#
# Usage:
#   ./scripts/deploy.sh \
#     --cluster game-2048 \
#     --region us-east-1 \
#     --ecr-repo <uri> \
#     --image-tag <tag>
#
# Exit codes:
#   0 - Deployment successful
#   1 - Deployment failed (rollback may have been triggered)
# ============================================================

CLUSTER=""
REGION="us-east-1"
ECR_REPO=""
IMAGE_TAG=""
SERVICE_BLUE="game-2048-blue"
SERVICE_GREEN="game-2048-green"
LISTENER_ARN=""
TG_BLUE_ARN=""
TG_GREEN_ARN=""
SKIP_BUILD=false
DRY_RUN=false

usage() {
  echo "Usage: $0 --cluster <name> --ecr-repo <uri> --image-tag <tag> [options]"
  echo ""
  echo "Required:"
  echo "  --cluster        ECS cluster name"
  echo "  --ecr-repo       ECR repository URI"
  echo "  --image-tag      Docker image tag to deploy"
  echo ""
  echo "Options:"
  echo "  --region          AWS region (default: us-east-1)"
  echo "  --service-blue    Blue ECS service name (default: game-2048-blue)"
  echo "  --service-green   Green ECS service name (default: game-2048-green)"
  echo "  --listener-arn    ALB listener ARN (for blue/green switch)"
  echo "  --tg-blue-arn     Blue target group ARN"
  echo "  --tg-green-arn    Green target group ARN"
  echo "  --skip-build      Skip Docker build (image already in ECR)"
  echo "  --dry-run         Show what would be done without executing"
  echo "  --help            Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --ecr-repo) ECR_REPO="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="$2"; shift 2 ;;
    --service-blue) SERVICE_BLUE="$2"; shift 2 ;;
    --service-green) SERVICE_GREEN="$2"; shift 2 ;;
    --listener-arn) LISTENER_ARN="$2"; shift 2 ;;
    --tg-blue-arn) TG_BLUE_ARN="$2"; shift 2 ;;
    --tg-green-arn) TG_GREEN_ARN="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$CLUSTER" ] || [ -z "$ECR_REPO" ] || [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: --cluster, --ecr-repo, and --image-tag are required"
  usage
  exit 1
fi

IMAGE_URI="${ECR_REPO}:${IMAGE_TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S UTC")

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             DEPLOYMENT STARTED                             ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
echo "║  Cluster:  $CLUSTER"
echo "║  Region:   $REGION"
echo "║  Image:    $IMAGE_URI"
echo "║  Time:     $TIMESTAMP"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] No changes will be made"
  echo ""
fi

# ============================================================
# Step 1: Identify active environment
# ============================================================
echo "============================================"
echo "  Step 1: Identify Active Environment"
echo "============================================"

ACTIVE_ENV="none"
STANDBY_ENV="blue"

if [ -n "$LISTENER_ARN" ] && [ -n "$TG_BLUE_ARN" ] && [ -n "$TG_GREEN_ARN" ]; then
  CURRENT_TG=$(aws elbv2 describe-rules \
    --listener-arn "$LISTENER_ARN" \
    --region "$REGION" \
    --query 'Rules[?IsDefault==`true`].Actions[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

  if [ "$CURRENT_TG" = "$TG_BLUE_ARN" ]; then
    ACTIVE_ENV="blue"
    STANDBY_ENV="green"
  elif [ "$CURRENT_TG" = "$TG_GREEN_ARN" ]; then
    ACTIVE_ENV="green"
    STANDBY_ENV="blue"
  fi
fi

if [ "$STANDBY_ENV" = "blue" ]; then
  STANDBY_SERVICE="$SERVICE_BLUE"
else
  STANDBY_SERVICE="$SERVICE_GREEN"
fi

echo "  Active:  $ACTIVE_ENV"
echo "  Standby: $STANDBY_ENV (deploy target)"
echo "  Service: $STANDBY_SERVICE"
echo ""

# ============================================================
# Step 2: Build and push (optional)
# ============================================================
if [ "$SKIP_BUILD" = false ]; then
  echo "============================================"
  echo "  Step 2: Build & Push Docker Image"
  echo "============================================"

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would build and push $IMAGE_URI"
  else
    echo "  Building image..."
    docker build -t "$IMAGE_URI" ./2048

    echo "  Pushing to ECR..."
    docker push "$IMAGE_URI"

    echo "  Also tagging as latest..."
    docker tag "$IMAGE_URI" "${ECR_REPO}:latest"
    docker push "${ECR_REPO}:latest"
  fi
  echo ""
else
  echo "  [SKIP] Build skipped (--skip-build flag)"
  echo ""
fi

# ============================================================
# Step 3: Deploy to standby environment
# ============================================================
echo "============================================"
echo "  Step 3: Deploy to Standby ($STANDBY_ENV)"
echo "============================================"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would update $STANDBY_SERVICE with $IMAGE_URI"
else
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$STANDBY_SERVICE" \
    --force-new-deployment \
    --region "$REGION" > /dev/null

  echo "  Deployment initiated"
  echo "  Waiting for service stability..."

  aws ecs wait services-stable \
    --cluster "$CLUSTER" \
    --services "$STANDBY_SERVICE" \
    --region "$REGION"

  echo "  Service is stable"
fi
echo ""

# ============================================================
# Step 4: Health check
# ============================================================
echo "============================================"
echo "  Step 4: Health Check"
echo "============================================"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would run health checks"
else
  bash "${SCRIPT_DIR}/health-check.sh" \
    --cluster "$CLUSTER" \
    --service "$STANDBY_SERVICE" \
    --region "$REGION" \
    --max-attempts 5 \
    --interval 10
fi
echo ""

# ============================================================
# Step 5: Switch traffic (blue/green cutover)
# ============================================================
echo "============================================"
echo "  Step 5: Traffic Switch"
echo "============================================"

if [ -n "$LISTENER_ARN" ]; then
  if [ "$STANDBY_ENV" = "blue" ]; then
    NEW_TG="$TG_BLUE_ARN"
  else
    NEW_TG="$TG_GREEN_ARN"
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would switch ALB to $STANDBY_ENV target group"
  else
    RULE_ARN=$(aws elbv2 describe-rules \
      --listener-arn "$LISTENER_ARN" \
      --region "$REGION" \
      --query 'Rules[?IsDefault==`true`].RuleArn' \
      --output text)

    aws elbv2 modify-rule \
      --rule-arn "$RULE_ARN" \
      --actions "Type=forward,TargetGroupArn=$NEW_TG" \
      --region "$REGION" > /dev/null

    echo "  Traffic switched to $STANDBY_ENV"
  fi
else
  echo "  No ALB configured - single service mode"
fi
echo ""

# ============================================================
# Step 6: Post-deploy verification
# ============================================================
echo "============================================"
echo "  Step 6: Post-Deploy Verification"
echo "============================================"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would verify deployment"
else
  bash "${SCRIPT_DIR}/health-check.sh" \
    --cluster "$CLUSTER" \
    --service "$STANDBY_SERVICE" \
    --region "$REGION" \
    --max-attempts 3 \
    --interval 5
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             DEPLOYMENT COMPLETED                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
echo "║  Image:      $IMAGE_URI"
echo "║  Active Env: $STANDBY_ENV (was: $ACTIVE_ENV)"
echo "║  Time:       $(date +'%Y-%m-%d %H:%M:%S UTC')"
echo "║                                                           ║"
echo "║  Rollback:   ./scripts/rollback.sh --cluster $CLUSTER"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
