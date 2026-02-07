# Project 5: Centralized Logging Stack (EFK) - Architecture

## High-Level Architecture

```
    ┌────────────────────────────────────────────────────────────────┐
    │                    KUBERNETES CLUSTER                          │
    │                                                                │
    │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
    │  │ App Pod  │  │ App Pod  │  │ App Pod  │  │ App Pod  │    │
    │  │ stdout/  │  │ stdout/  │  │ stdout/  │  │ stdout/  │    │
    │  │ stderr   │  │ stderr   │  │ stderr   │  │ stderr   │    │
    │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
    │       │              │              │              │          │
    │       └──────────────┴──────┬───────┴──────────────┘          │
    │                             │                                  │
    │                             v                                  │
    │  ┌──────────────────────────────────────────────────────────┐│
    │  │              FLUENTD (DaemonSet)                          ││
    │  │              1 pod per node                               ││
    │  │                                                          ││
    │  │  Collect → Parse → Filter → Buffer → Output              ││
    │  │                                                          ││
    │  │  ┌──────────┐ ┌──────────┐ ┌────────┐ ┌─────────────┐  ││
    │  │  │ Tail     │→│ JSON     │→│ Add    │→│ Elasticsearch│  ││
    │  │  │ container│ │ parser   │ │ k8s    │ │ output       │  ││
    │  │  │ logs     │ │          │ │ metadata│ │              │  ││
    │  │  └──────────┘ └──────────┘ └────────┘ └─────────────┘  ││
    │  └──────────────────────────────────────────────────────────┘│
    │                             │                                  │
    └─────────────────────────────┼──────────────────────────────────┘
                                  │
                                  v
    ╔════════════════════════════════════════════════════════════════╗
    ║              ELASTICSEARCH CLUSTER                             ║
    ║                                                                ║
    ║  ┌────────────────────────────────────────────────────────┐   ║
    ║  │  Index: app-logs-YYYY.MM.DD (daily rotation)          │   ║
    ║  │                                                        │   ║
    ║  │  Document fields:                                      │   ║
    ║  │  ├── @timestamp        (ISO 8601)                     │   ║
    ║  │  ├── kubernetes.namespace                              │   ║
    ║  │  ├── kubernetes.pod_name                               │   ║
    ║  │  ├── kubernetes.container_name                         │   ║
    ║  │  ├── level             (info/warn/error)              │   ║
    ║  │  ├── message           (log content)                  │   ║
    ║  │  └── correlation_id    (request tracing)              │   ║
    ║  └────────────────────────────────────────────────────────┘   ║
    ║                                                                ║
    ║  Index Lifecycle:                                              ║
    ║  ├── Hot:   0-7 days   (SSD, full replicas)                  ║
    ║  ├── Warm:  7-30 days  (reduced replicas)                    ║
    ║  └── Delete: 30+ days  (auto-purge)                          ║
    ╚════════════════════════════════════════════════════════════════╝
                                  │
                                  v
    ┌────────────────────────────────────────────────────────────────┐
    │                         KIBANA                                 │
    │                                                                │
    │  Dashboards:                                                   │
    │  ├── Application Overview  (request rate, errors, latency)    │
    │  ├── Error Analysis        (5xx breakdown, stack traces)      │
    │  ├── Container Health      (restarts, OOM, crashes)          │
    │  └── Security Audit        (access patterns, anomalies)      │
    │                                                                │
    │  Saved Searches:                                               │
    │  ├── "All errors last 1h"                                     │
    │  ├── "Slow requests > 2s"                                     │
    │  └── "Pod restart events"                                     │
    └────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
    Container stdout/stderr
         │
         v
    /var/log/containers/*.log    (written by container runtime)
         │
         v
    Fluentd tail input           (reads log files)
         │
         v
    JSON parser                  (structured log extraction)
         │
         v
    Kubernetes metadata filter   (adds namespace, pod, labels)
         │
         v
    Buffer (file-backed)         (prevents data loss on restart)
         │
         v
    Elasticsearch output         (bulk indexing, daily indices)
         │
         v
    Kibana query                 (search, visualize, alert)
```

---

*Last Updated: 2026-02-03*
