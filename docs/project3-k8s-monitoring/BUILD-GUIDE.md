# Project 3: Kubernetes & Microservices Monitoring - Build Guide

## What You Will Build

- Kubernetes manifests for the 2048 game with HPA, PDB, and Ingress
- Prometheus for metrics collection with 8 alert rules
- Grafana with a pre-configured 7-panel dashboard
- Alertmanager with severity-based routing
- Node Exporter for host-level metrics

## Deploy Order

```bash
# 1. Namespaces
kubectl apply -f k8s/base/namespace.yaml

# 2. Application
kubectl apply -f k8s/base/deployment.yaml
kubectl apply -f k8s/base/service.yaml
kubectl apply -f k8s/base/hpa.yaml
kubectl apply -f k8s/base/ingress.yaml

# 3. Monitoring stack
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/grafana/
kubectl apply -f k8s/monitoring/alertmanager/

# 4. Create Grafana secret
kubectl create secret generic grafana-credentials \
  --from-literal=admin-password=admin \
  -n monitoring

# 5. Verify
kubectl get pods -n game-2048
kubectl get pods -n monitoring
```

## Access Dashboards

```bash
# Grafana (http://localhost:3000, admin / admin)
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Prometheus (http://localhost:9090)
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Alertmanager (http://localhost:9093)
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
```

## Alert Rules Summary

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | 5xx rate > 5% for 5m | critical |
| HighLatency | P95 > 2s for 5m | warning |
| PodCrashLooping | Restarts in 15m | critical |
| PodNotReady | Not ready for 5m | warning |
| HighCPUUsage | Node CPU > 80% for 10m | warning |
| HighMemoryUsage | Node memory > 90% for 10m | critical |
| DiskSpaceRunningLow | Disk > 85% for 15m | warning |
| HPAMaxedOut | At max replicas for 15m | warning |

---

*Last Updated: 2026-02-03*
