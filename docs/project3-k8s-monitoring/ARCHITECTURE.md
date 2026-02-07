# Project 3: Kubernetes Cluster & Microservices Monitoring - Architecture

## High-Level Architecture

```
                        KUBERNETES CLUSTER
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  ┌─────────────────────────────────────────────────────────┐ ║
    ║  │              INGRESS CONTROLLER (NGINX)                  │ ║
    ║  │         External traffic → routing rules                 │ ║
    ║  └────────┬──────────────────────┬──────────────────────────┘ ║
    ║           │                      │                            ║
    ║           │ /                    │ /grafana                   ║
    ║           v                      v                            ║
    ║  ┌────────────────┐     ┌────────────────┐                  ║
    ║  │  APPLICATION   │     │  MONITORING     │                  ║
    ║  │  NAMESPACE     │     │  NAMESPACE      │                  ║
    ║  │                │     │                 │                  ║
    ║  │ ┌────────────┐ │     │ ┌─────────────┐ │                  ║
    ║  │ │ 2048-game  │ │     │ │  Grafana    │ │                  ║
    ║  │ │ Deployment │ │     │ │  Dashboard  │ │                  ║
    ║  │ │ (3 replicas)│ │     │ └─────────────┘ │                  ║
    ║  │ └──────┬─────┘ │     │ ┌─────────────┐ │                  ║
    ║  │        │        │     │ │ Prometheus  │ │                  ║
    ║  │ ┌──────▼─────┐ │     │ │ (Metrics)   │ │                  ║
    ║  │ │  Service   │ │     │ └─────────────┘ │                  ║
    ║  │ │ ClusterIP  │◄├─────┤ ┌─────────────┐ │                  ║
    ║  │ └────────────┘ │     │ │Alertmanager │ │                  ║
    ║  │                │     │ │ (Alerts)    │ │                  ║
    ║  │ ┌────────────┐ │     │ └─────────────┘ │                  ║
    ║  │ │    HPA     │ │     │                 │                  ║
    ║  │ │ min:2      │ │     │ ┌─────────────┐ │                  ║
    ║  │ │ max:10     │ │     │ │ Node        │ │                  ║
    ║  │ │ cpu:70%    │ │     │ │ Exporter    │ │                  ║
    ║  │ └────────────┘ │     │ └─────────────┘ │                  ║
    ║  └────────────────┘     └────────────────┘                  ║
    ╚═══════════════════════════════════════════════════════════════╝

    MONITORING DATA FLOW:
    ════════════════════

    ┌──────────┐  scrape/15s   ┌────────────┐  query   ┌──────────┐
    │ App Pods │──────────────>│ Prometheus  │<─────────│ Grafana  │
    │ /metrics │               │ (TSDB)     │          │(Dashboard)│
    └──────────┘               └─────┬──────┘          └──────────┘
                                     │ evaluate
    ┌──────────┐  scrape/15s         │ rules
    │ Node     │──────────────>      │
    │ Exporter │               ┌─────▼──────┐  notify  ┌──────────┐
    └──────────┘               │Alertmanager│─────────>│ Slack/   │
                               │            │          │ Email    │
                               └────────────┘          └──────────┘
```

## Namespace Layout

```
    Namespaces:
    ├── game-2048          Application workloads
    │   ├── Deployment     (2048 game, 3 replicas)
    │   ├── Service        (ClusterIP, port 80)
    │   ├── HPA            (auto-scale 2-10 pods)
    │   ├── ConfigMap      (NGINX config)
    │   └── PDB            (min 1 available)
    │
    └── monitoring         Observability stack
        ├── Prometheus     (metrics collection)
        │   ├── Deployment (1 replica, 2Gi storage)
        │   ├── ConfigMap  (scrape targets, rules)
        │   └── Service    (ClusterIP, port 9090)
        ├── Grafana        (visualization)
        │   ├── Deployment (1 replica)
        │   ├── ConfigMap  (dashboards, datasources)
        │   └── Service    (ClusterIP, port 3000)
        ├── Alertmanager   (alert routing)
        │   ├── Deployment (1 replica)
        │   ├── ConfigMap  (routing rules)
        │   └── Service    (ClusterIP, port 9093)
        └── Node Exporter  (host metrics)
            ├── DaemonSet  (1 per node)
            └── Service    (ClusterIP, port 9100)
```

---

*Last Updated: 2026-02-03*
