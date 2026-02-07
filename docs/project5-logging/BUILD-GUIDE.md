# Project 5: Centralized Logging Stack (EFK) - Build Guide

## What You Will Build

- **Elasticsearch** StatefulSet with 10Gi persistent storage and ILM (hot/warm/delete)
- **Fluentd** DaemonSet collecting logs from every node with Kubernetes metadata enrichment
- **Kibana** with pre-configured index patterns and saved searches

## File Structure

```
logging/
├── elasticsearch/
│   ├── deployment.yaml       # StatefulSet + Service + PVC
│   └── ilm-policy.json       # Index lifecycle (hot 7d → warm 30d → delete)
├── fluentd/
│   ├── deployment.yaml       # DaemonSet + RBAC + ServiceAccount
│   └── config.yaml           # ConfigMap: input, filter, parse, output
└── kibana/
    ├── deployment.yaml       # Deployment + Service
    └── saved-objects.ndjson  # Index pattern + 3 saved searches
```

## Deploy Order

```bash
# 1. Elasticsearch (must be ready before Fluentd/Kibana)
kubectl apply -f logging/elasticsearch/deployment.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=elasticsearch -n logging --timeout=120s

# 2. Apply ILM policy
kubectl port-forward svc/elasticsearch 9200:9200 -n logging &
curl -X PUT "localhost:9200/_ilm/policy/app-logs-policy" \
  -H "Content-Type: application/json" \
  -d @logging/elasticsearch/ilm-policy.json

# 3. Fluentd (starts collecting logs immediately)
kubectl apply -f logging/fluentd/config.yaml
kubectl apply -f logging/fluentd/deployment.yaml

# 4. Kibana
kubectl apply -f logging/kibana/deployment.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kibana -n logging --timeout=120s

# 5. Import saved searches
kubectl port-forward svc/kibana 5601:5601 -n logging &
curl -X POST "localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form file=@logging/kibana/saved-objects.ndjson
```

## Access

```bash
# Kibana (http://localhost:5601)
kubectl port-forward svc/kibana 5601:5601 -n logging

# Elasticsearch (http://localhost:9200)
kubectl port-forward svc/elasticsearch 9200:9200 -n logging
```

## Verify Logs Are Flowing

```bash
# Check Fluentd is running on all nodes
kubectl get ds fluentd -n logging

# Check Elasticsearch has data
curl http://localhost:9200/_cat/indices?v

# Count documents in today's index
curl http://localhost:9200/app-logs-$(date +%Y.%m.%d)/_count
```

## Index Lifecycle

| Phase | Age | Actions |
|-------|-----|---------|
| Hot | 0-7 days | Full replicas, rollover at 10GB |
| Warm | 7-30 days | Shrink to 1 shard, force merge |
| Delete | 30+ days | Auto-purge |

## Fluentd Pipeline

```
Tail /var/log/containers/*.log
  → Parse JSON
  → Add Kubernetes metadata (pod, namespace, labels)
  → Parse application JSON logs
  → Drop health check noise
  → Add severity level
  → Buffer to disk (8MB chunks, 5s flush)
  → Output to Elasticsearch (daily indices)
```

## Saved Searches in Kibana

| Search | Query | Use Case |
|--------|-------|----------|
| All Errors | `severity:error` | Incident investigation |
| Slow Requests | `response_time > 2000` | Performance debugging |
| Pod Restarts | `Back-off restarting OR OOMKilled` | Stability monitoring |

---

*Last Updated: 2026-02-03*
