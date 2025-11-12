# Azure Monitor KQL Queries for MLOps Platform

This document contains useful KQL queries for monitoring the MLOps platform.

## Model Performance Queries

### Prediction Request Volume
```kql
requests
| where name == "POST /predict"
| summarize Count = count() by bin(timestamp, 5m)
| render timechart
```

### Average Prediction Latency
```kql
customMetrics
| where name == "prediction_latency"
| summarize
    avg(value) as AvgLatency,
    percentile(value, 50) as P50,
    percentile(value, 95) as P95,
    percentile(value, 99) as P99
    by bin(timestamp, 5m)
| render timechart
```

### Prediction Confidence Distribution
```kql
customMetrics
| where name == "prediction_confidence"
| summarize avg(value), min(value), max(value), stdev(value) by bin(timestamp, 15m)
| render timechart
```

## A/B Testing Queries

### Traffic Split Analysis
```kql
requests
| where name == "POST /predict"
| extend model_version = tostring(customDimensions.assigned_variant)
| where isnotempty(model_version)
| summarize Count = count() by model_version
| extend Percentage = round(100.0 * Count / toscalar(
    requests
    | where name == "POST /predict"
    | count
), 2)
```

### Model Performance Comparison
```kql
customMetrics
| where name == "prediction_confidence"
| extend model_version = tostring(customDimensions.model_version)
| summarize
    AvgConfidence = avg(value),
    Count = count()
    by model_version, bin(timestamp, 1h)
| render timechart
```

### A/B Test Statistical Summary
```kql
let ModelAMetrics = customMetrics
| where name == "prediction_confidence"
| extend model_version = tostring(customDimensions.model_version)
| where model_version contains "_A"
| summarize
    ModelA_Avg = avg(value),
    ModelA_StdDev = stdev(value),
    ModelA_Count = count();
let ModelBMetrics = customMetrics
| where name == "prediction_confidence"
| extend model_version = tostring(customDimensions.model_version)
| where model_version contains "_B"
| summarize
    ModelB_Avg = avg(value),
    ModelB_StdDev = stdev(value),
    ModelB_Count = count();
ModelAMetrics
| extend dummy = 1
| join kind=inner (ModelBMetrics | extend dummy = 1) on dummy
| project
    ModelA_Avg, ModelA_StdDev, ModelA_Count,
    ModelB_Avg, ModelB_StdDev, ModelB_Count,
    Lift = round(100.0 * (ModelB_Avg - ModelA_Avg) / ModelA_Avg, 2)
```

## Error and Health Monitoring

### Error Rate
```kql
requests
| where name == "POST /predict"
| summarize
    Total = count(),
    Errors = countif(success == false),
    ErrorRate = round(100.0 * countif(success == false) / count(), 2)
    by bin(timestamp, 5m)
| render timechart
```

### Exception Tracking
```kql
exceptions
| where cloud_RoleName == "ml-model-server"
| summarize Count = count() by type, outerMessage, bin(timestamp, 15m)
| order by Count desc
```

### Health Check Failures
```kql
requests
| where name == "GET /health"
| where success == false
| project timestamp, resultCode, duration, cloud_RoleInstance
| order by timestamp desc
```

## Resource Utilization

### Container CPU Usage
```kql
performanceCounters
| where name == "% Processor Time"
| where cloud_RoleInstance contains "model"
| summarize avg(value) by cloud_RoleInstance, bin(timestamp, 5m)
| render timechart
```

### Container Memory Usage
```kql
performanceCounters
| where name == "Available Bytes"
| where cloud_RoleInstance contains "model"
| extend MemoryUsedGB = (value / 1024 / 1024 / 1024)
| summarize avg(MemoryUsedGB) by cloud_RoleInstance, bin(timestamp, 5m)
| render timechart
```

### Request Rate per Instance
```kql
requests
| where name == "POST /predict"
| summarize RequestsPerMinute = count() / 5.0 by cloud_RoleInstance, bin(timestamp, 5m)
| render timechart
```

## Model Accuracy Monitoring

### Model Accuracy Over Time
```kql
customMetrics
| where name == "model_accuracy"
| extend model_version = tostring(customDimensions.model_version)
| summarize avg(value) by bin(timestamp, 1h), model_version
| render timechart
```

### Accuracy Degradation Detection
```kql
let baseline = customMetrics
| where name == "model_accuracy"
| where timestamp between (ago(7d) .. ago(6d))
| summarize BaselineAccuracy = avg(value);
customMetrics
| where name == "model_accuracy"
| where timestamp > ago(1h)
| summarize CurrentAccuracy = avg(value)
| extend dummy = 1
| join kind=inner (baseline | extend dummy = 1) on dummy
| project
    CurrentAccuracy,
    BaselineAccuracy,
    Degradation = round(100.0 * (BaselineAccuracy - CurrentAccuracy) / BaselineAccuracy, 2),
    Alert = iff((BaselineAccuracy - CurrentAccuracy) / BaselineAccuracy > 0.05, "🚨 ALERT", "✅ OK")
```

## Cost Monitoring

### Request Volume by Hour (for cost estimation)
```kql
requests
| where name == "POST /predict"
| summarize RequestCount = count() by bin(timestamp, 1h)
| extend EstimatedCost = RequestCount * 0.0001  // Estimate cost per request
| render timechart
```

### Traffic by Region
```kql
requests
| where name == "POST /predict"
| summarize Count = count() by client_CountryOrRegion
| order by Count desc
| render piechart
```

## Deployment Monitoring

### Deployment Success Rate
```kql
customEvents
| where name == "deployment"
| extend status = tostring(customDimensions.status)
| summarize
    Total = count(),
    Success = countif(status == "success"),
    Failed = countif(status == "failed")
    by bin(timestamp, 1d)
| extend SuccessRate = round(100.0 * Success / Total, 2)
| render barchart
```

### Model Version Distribution
```kql
requests
| where name == "POST /predict"
| extend model_version = tostring(customDimensions.model_version)
| where isnotempty(model_version)
| summarize Count = count() by model_version, bin(timestamp, 1h)
| render areachart
```

## Alert Queries

### High Error Rate Alert
```kql
requests
| where name == "POST /predict"
| where timestamp > ago(5m)
| summarize
    ErrorRate = 100.0 * countif(success == false) / count()
| where ErrorRate > 5  // Alert if error rate > 5%
```

### High Latency Alert
```kql
customMetrics
| where name == "prediction_latency"
| where timestamp > ago(5m)
| summarize P95 = percentile(value, 95)
| where P95 > 2000  // Alert if P95 latency > 2 seconds
```

### Model Accuracy Drop Alert
```kql
customMetrics
| where name == "model_accuracy"
| where timestamp > ago(1h)
| summarize AvgAccuracy = avg(value)
| where AvgAccuracy < 0.85  // Alert if accuracy drops below 85%
```

### Container Health Check Alert
```kql
requests
| where name == "GET /health"
| where timestamp > ago(5m)
| summarize FailureRate = 100.0 * countif(success == false) / count()
| where FailureRate > 20  // Alert if 20% health checks fail
```

## User Behavior Analysis

### Unique Users
```kql
requests
| where name == "POST /predict"
| extend user_id = tostring(customDimensions.user_id)
| where isnotempty(user_id) and user_id != "anonymous"
| summarize UniqueUsers = dcount(user_id) by bin(timestamp, 1h)
| render timechart
```

### Requests per User
```kql
requests
| where name == "POST /predict"
| extend user_id = tostring(customDimensions.user_id)
| where isnotempty(user_id) and user_id != "anonymous"
| summarize RequestCount = count() by user_id
| summarize
    AvgRequestsPerUser = avg(RequestCount),
    MedianRequestsPerUser = percentile(RequestCount, 50),
    MaxRequestsPerUser = max(RequestCount)
```

## Usage Tips

1. **Time Ranges**: Adjust time ranges using `| where timestamp > ago(24h)` or similar
2. **Sampling**: For large datasets, use `| sample 1000` to limit results
3. **Performance**: Create summaries using `summarize` before filtering when possible
4. **Visualization**: Use `| render timechart`, `| render barchart`, or `| render piechart` for visual insights
5. **Alerts**: Save these queries as alert rules in Azure Monitor for proactive monitoring
