#!/bin/bash

################################################################################
# ArgoCD Installation Script
# Purpose: Install and configure ArgoCD for GitOps workflows
# Usage: ./install-argocd.sh [cluster-type]
#   cluster-type: aks (Azure Kubernetes) or eks (AWS EKS)
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

CLUSTER_TYPE=${1:-aks}

print_info "============================================"
print_info "ArgoCD Installation Script"
print_info "============================================"
print_info "Cluster Type: $CLUSTER_TYPE"
print_info "============================================"

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
    exit 1
fi

print_success "Prerequisites check passed"

# Step 1: Create namespace
print_info "Step 1/8: Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespace created"

# Step 2: Install ArgoCD
print_info "Step 2/8: Installing ArgoCD..."
ARGOCD_VERSION="stable"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for deployment
print_info "Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server \
    deployment/argocd-repo-server \
    deployment/argocd-redis \
    -n argocd

print_success "ArgoCD installed successfully"

# Step 3: Apply custom configurations
print_info "Step 3/8: Applying custom configurations..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/argocd-install.yaml" ]; then
    # Extract and apply ConfigMaps only (skip namespace and ingress for now)
    kubectl apply -n argocd -f "$SCRIPT_DIR/argocd-install.yaml" || print_warning "Some configurations may have failed"
fi

print_success "Custom configurations applied"

# Step 4: Expose ArgoCD Server
print_info "Step 4/8: Exposing ArgoCD server..."

if [ "$CLUSTER_TYPE" == "aks" ]; then
    # Azure Kubernetes Service - LoadBalancer
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    print_info "ArgoCD exposed via LoadBalancer (AKS)"
else
    # AWS EKS or other - NodePort for now
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    print_info "ArgoCD exposed via NodePort"
fi

# Step 5: Get initial admin password
print_info "Step 5/8: Retrieving initial admin password..."
sleep 5  # Wait a bit for secret to be created

INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")

if [ -n "$INITIAL_PASSWORD" ]; then
    print_success "Initial admin password retrieved"
else
    print_warning "Could not retrieve initial password, it will be available shortly"
fi

# Step 6: Install ArgoCD CLI (optional)
print_info "Step 6/8: Checking for ArgoCD CLI..."

if ! command -v argocd &> /dev/null; then
    print_warning "ArgoCD CLI not found"
    print_info "To install ArgoCD CLI:"
    print_info "  macOS:   brew install argocd"
    print_info "  Linux:   curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /usr/local/bin/argocd"
    print_info "  Windows: choco install argocd-cli"
else
    print_success "ArgoCD CLI is already installed ($(argocd version --client --short))"
fi

# Step 7: Get access information
print_info "Step 7/8: Getting access information..."

if [ "$CLUSTER_TYPE" == "aks" ]; then
    # Wait for LoadBalancer IP
    print_info "Waiting for LoadBalancer IP (this may take 1-2 minutes)..."
    EXTERNAL_IP=""
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ]; then
            break
        fi
        sleep 5
    done

    if [ -n "$EXTERNAL_IP" ]; then
        ARGOCD_URL="https://$EXTERNAL_IP"
    fi
else
    NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
    ARGOCD_URL="https://localhost:$NODE_PORT"
fi

# Step 8: Create bootstrap application (optional)
print_info "Step 8/8: Creating bootstrap application..."
cat <<EOF | kubectl apply -f - || print_warning "Could not create bootstrap application"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: enterprise-platforms
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nkefor/2048-cicd-enterprise.git
    targetRevision: HEAD
    path: gitops/manifests/base
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Display summary
print_success "============================================"
print_success "✅ ArgoCD Installation Complete!"
print_success "============================================"
echo ""

print_info "📋 Access Information:"
if [ -n "${ARGOCD_URL:-}" ]; then
    print_info "  URL:      $ARGOCD_URL"
fi
print_info "  Username: admin"
if [ -n "$INITIAL_PASSWORD" ]; then
    print_info "  Password: $INITIAL_PASSWORD"
else
    print_info "  Password: (run command below to get password)"
fi

echo ""
print_info "🔑 To get the initial admin password:"
print_info "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"

echo ""
print_info "🌐 To access ArgoCD UI:"
if [ "$CLUSTER_TYPE" == "aks" ]; then
    print_info "  1. Open browser to: $ARGOCD_URL"
else
    print_info "  1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    print_info "  2. Open browser to: https://localhost:8080"
fi
print_info "  3. Login with admin / <password from above>"

echo ""
print_info "🔧 To login with ArgoCD CLI:"
if [ "$CLUSTER_TYPE" == "aks" ] && [ -n "${EXTERNAL_IP:-}" ]; then
    print_info "  argocd login $EXTERNAL_IP"
else
    print_info "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    print_info "  argocd login localhost:8080"
fi
print_info "  argocd account update-password"

echo ""
print_info "📚 Next Steps:"
print_info "  1. Change the admin password"
print_info "  2. Configure repository access (GitHub/GitLab)"
print_info "  3. Create ArgoCD projects"
print_info "  4. Deploy applications using GitOps"
print_info "  5. Set up notifications (Slack, email)"

echo ""
print_success "Installation script completed successfully!"
