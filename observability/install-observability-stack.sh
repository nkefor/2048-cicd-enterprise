#!/bin/bash

###############################################################################
# Observability Stack Installation
# Installs: Grafana, Prometheus, Loki, Tempo, OpenTelemetry Collector
# Usage: ./install-observability-stack.sh
################################################################################

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

print_info "Installing Observability Stack (Grafana + Prometheus + Loki + Tempo)..."

# Install Prometheus Operator (includes Grafana)
kubectl create namespace observability || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_info "Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.adminPassword=admin \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=10Gi

# Install Loki for logs
print_info "Installing Loki (Log aggregation)..."
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki-stack \
  --namespace observability \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi \
  --set promtail.enabled=true

# Install Tempo for distributed tracing
print_info "Installing Tempo (Distributed tracing)..."
helm upgrade --install tempo grafana/tempo \
  --namespace observability \
  --set persistence.enabled=true \
  --set persistence.size=10Gi

print_success "Observability stack installed!"
print_info "Access Grafana: kubectl port-forward -n observability svc/kube-prometheus-grafana 3000:80"
print_info "Default credentials: admin / admin"
