# End-to-End MLOps Platform on Azure

**Production-grade MLOps platform** with automated model deployment, A/B testing capabilities, and real-time monitoring dashboards on Azure infrastructure.

## 🚀 Features

### Core Capabilities
- ✅ **MLflow Integration**: Integrated MLflow for experiment tracking and model registry with Azure ML
- ✅ **Distributed Training**: Azure ML compute clusters for scalable model training
- ✅ **Hyperparameter Tuning**: Automated hyperparameter optimization with Azure ML HyperDrive
- ✅ **Auto-scaling on Prediction Volume**: Dynamic scaling based on request rate and custom metrics
- ✅ **Continuous Deployment**: Automated model deployment to AKS with zero downtime
- ✅ **A/B Testing**: Built-in traffic splitting and statistical analysis
- ✅ **Real-time Monitoring**: Azure Monitor dashboards with custom metrics
- ✅ **Model Registry**: Centralized model versioning and metadata tracking
- ✅ **Infrastructure as Code**: Complete Terraform automation
- ✅ **CI/CD Pipeline**: GitHub Actions workflow for end-to-end automation

### Key Differentiators
- 🎯 **Intelligent Auto-Scaling**: Scales inference endpoints based on prediction volume, not just CPU/memory
- 🔬 **Experiment Tracking**: Full MLflow integration with Azure ML for tracking all training runs
- ⚡ **Distributed Training**: Leverage multiple compute nodes for faster model training
- 🎛️ **Automated Hyperparameter Tuning**: Find optimal model parameters automatically
- 📊 **Production Model Registry**: Track model lineage, versions, and performance metrics

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Repository                          │
│                   (Code + Models + IaC)                         │
└───────────────┬─────────────────────────────────────────────────┘
                │ git push
                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  GitHub Actions (MLOps CI/CD)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐     │
│  │Train Model│→│Build Image│→│Push to ACR│→│Deploy AKS │     │
│  └──────────┘  └──────────┘  └──────────┘  └───────────┘     │
└───────────────┬─────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Azure Kubernetes Service (AKS)                     │ │
│  │  ┌────────────────────┐   ┌────────────────────┐         │ │
│  │  │   Model A (90%)    │   │   Model B (10%)    │         │ │
│  │  │   Champion Model   │   │  Challenger Model  │         │ │
│  │  │  ┌──┐ ┌──┐ ┌──┐   │   │      ┌──┐          │         │ │
│  │  │  │P1│ │P2│ │P3│   │   │      │P1│          │         │ │
│  │  │  └──┘ └──┘ └──┘   │   │      └──┘          │         │ │
│  │  └────────────────────┘   └────────────────────┘         │ │
│  │            ▲                       ▲                      │ │
│  │            └───────┬───────────────┘                      │ │
│  │                    │ Traffic Split                        │ │
│  │         ┌──────────┴──────────┐                          │ │
│  │         │  NGINX Ingress      │                          │ │
│  │         │  (A/B Testing)      │                          │ │
│  │         └─────────────────────┘                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Azure Machine Learning                        │ │
│  │    (Training, Experiments, Model Registry)                │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │          Azure Container Registry (ACR)                    │ │
│  │    (Model Images, Version Control)                        │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │      Application Insights + Azure Monitor                  │ │
│  │  (Metrics, Logs, Dashboards, Alerts)                      │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Cosmos DB                                     │ │
│  │  (Model Metadata, A/B Test Results)                       │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Business Value

### Cost Savings
- **40-60% reduction** in operational costs vs traditional VM-based deployments
- **Pay-per-use** model with AKS auto-scaling
- **Efficient resource utilization** through Kubernetes orchestration

### Speed to Market
- **90% faster** model deployment (hours → minutes)
- **Automated A/B testing** for rapid model validation
- **Zero-downtime deployments** with rolling updates

### Quality & Reliability
- **99.95%+ uptime** with multi-zone AKS deployment
- **Automated rollback** on deployment failures
- **Real-time monitoring** for proactive issue detection
- **Statistical A/B testing** for confident model promotion

### Developer Productivity
- **Self-service ML deployments** without ops involvement
- **Integrated monitoring** dashboards for debugging
- **Automated training pipelines** with experiment tracking

## 📦 Components

### 1. Infrastructure (Terraform)
- **Azure Kubernetes Service (AKS)**: Container orchestration with auto-scaling
- **Azure Container Registry (ACR)**: Secure, geo-replicated image storage
- **Azure Machine Learning**: Managed ML workspace with experiment tracking
- **Application Insights**: Real-time application performance monitoring
- **Cosmos DB**: NoSQL database for model metadata and A/B test results
- **Azure Monitor**: Centralized logging and metrics collection
- **Key Vault**: Secure secrets management
- **Virtual Network**: Isolated network infrastructure

### 2. Model Training Pipeline
- **Azure ML SDK**: Managed training with compute targets
- **MLflow**: Experiment tracking and model versioning
- **Scikit-learn**: ML algorithms (Random Forest, Gradient Boosting)
- **Automated training**: Triggered via GitHub Actions or scheduled runs

### 3. Model Serving API
- **FastAPI**: High-performance REST API for predictions
- **Containerized deployment**: Docker images on AKS
- **Health checks**: Kubernetes liveness and readiness probes
- **Auto-scaling**: HPA based on CPU/memory metrics
- **A/B testing**: User-consistent variant assignment

### 4. A/B Testing Framework
- **Traffic splitting**: NGINX Ingress with canary deployments
- **Statistical analysis**: T-tests and confidence intervals
- **Experiment tracking**: Cosmos DB for results storage
- **Automated promotion**: Winner selection based on metrics
- **Consistent assignment**: Hash-based user routing

### 5. Monitoring & Observability
- **Azure Monitor**: Metrics, logs, and alerts
- **Application Insights**: Distributed tracing and profiling
- **Custom dashboards**: KQL queries for business metrics
- **Alerting**: Proactive notifications for anomalies
- **Cost tracking**: Resource utilization monitoring

## 🎯 Key Features Deep Dive

### MLflow Integration for Experiment Tracking

This platform integrates MLflow with Azure ML for comprehensive experiment tracking and model registry:

#### Features:
- **Experiment Tracking**: All training runs logged with parameters, metrics, and artifacts
- **Model Registry**: Centralized model versioning with lineage tracking
- **Auto-Promotion**: Models automatically promoted to Production stage based on performance
- **Model Cards**: Automatic generation of model documentation
- **Artifact Management**: Model binaries, scalers, and metadata stored securely

#### Example Usage:

```python
# Training with MLflow tracking
python train_model.py \
  --model-name ml-classifier \
  --experiment-name production-training \
  --model-type random_forest \
  --n-estimators 100 \
  --auto-promote \
  --promotion-threshold 0.90

# View experiments in Azure ML Studio
# All metrics, parameters, and artifacts automatically tracked
```

#### Benefits:
- ✅ **Full Reproducibility**: Every training run is tracked with exact parameters
- ✅ **Model Lineage**: Track which data and code produced each model
- ✅ **Comparison**: Compare multiple models side-by-side
- ✅ **Governance**: Audit trail for regulatory compliance

### Distributed Training with Azure ML

Scale your model training across multiple compute nodes for faster iteration:

#### Features:
- **Compute Clusters**: Auto-scaling Azure ML compute clusters
- **Distributed Execution**: Parallelize training across multiple nodes
- **Cost Optimization**: Scale to zero when not in use
- **GPU Support**: Optional GPU acceleration for deep learning

#### Example Usage:

```python
# Run distributed training
python distributed_training.py \
  --subscription-id YOUR_SUB_ID \
  --resource-group mlops-platform-rg \
  --workspace-name mlops-platform-workspace \
  --mode distributed-training \
  --instance-count 4 \
  --vm-size STANDARD_DS3_V2

# Monitor in Azure ML Studio
# Training distributed across 4 compute nodes
```

#### Benefits:
- ✅ **Faster Training**: 4x faster with 4 nodes
- ✅ **Cost Effective**: Pay only for compute time used
- ✅ **Scalable**: Scale from 1 to 100+ nodes
- ✅ **Managed**: Azure handles infrastructure

### Hyperparameter Tuning with Azure ML HyperDrive

Automatically find optimal model hyperparameters:

#### Features:
- **Automated Search**: Random search, grid search, Bayesian optimization
- **Early Termination**: Bandit policy stops underperforming runs
- **Parallel Execution**: Run multiple trials concurrently
- **Best Model Selection**: Automatically selects best performing model

#### Example Usage:

```python
# Run hyperparameter tuning
python distributed_training.py \
  --subscription-id YOUR_SUB_ID \
  --resource-group mlops-platform-rg \
  --workspace-name mlops-platform-workspace \
  --mode hyperparameter-tuning \
  --max-trials 20 \
  --concurrent-trials 4

# Searches hyperparameter space:
# - n_estimators: [50, 100, 150, 200]
# - max_depth: [5, 10, 15, 20]
# - min_samples_split: [2, 5, 10]
# - learning_rate: [0.01 to 0.3]
```

#### Benefits:
- ✅ **Better Models**: Find optimal hyperparameters automatically
- ✅ **Time Savings**: Parallel search saves hours of manual tuning
- ✅ **Reproducible**: Track all trials in MLflow
- ✅ **Cost Efficient**: Early termination reduces compute costs

### Auto-Scaling Based on Prediction Volume

Dynamically scale inference endpoints based on actual prediction load:

#### Features:
- **Custom Metrics**: Scale based on requests per second, not just CPU/memory
- **Application Insights Integration**: Use real-time metrics from Azure Monitor
- **Intelligent Scaling**: Different policies for scale-up and scale-down
- **KEDA Support**: Advanced auto-scaling with external metrics

#### Scaling Metrics:
- `prediction_requests_per_second`: Request rate per pod
- `azure_application_insights_request_rate`: Request rate from App Insights
- `prediction_latency`: Average prediction latency

#### Example Configuration:

```yaml
# HPA based on prediction volume
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: model-a-prediction-volume-hpa
spec:
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: prediction_requests_per_second
      target:
        type: AverageValue
        averageValue: "10"  # Scale when >10 RPS per pod
```

#### Scaling Behavior:
- **Scale Up**: Immediate (0 sec cooldown) when request volume increases
- **Scale Down**: Conservative (5 min cooldown) to avoid thrashing
- **Max Scale Up**: 100% or 4 pods per 30 seconds
- **Max Scale Down**: 50% or 2 pods per 60 seconds

#### Benefits:
- ✅ **Cost Optimization**: Scale down to min replicas during low traffic
- ✅ **Performance**: Scale up immediately during traffic spikes
- ✅ **Predictable**: Based on actual prediction load, not proxy metrics
- ✅ **Flexible**: Support for multiple scaling metrics

## 🚀 Quick Start

### Prerequisites

- Azure account with Owner/Contributor permissions
- Azure CLI installed and configured
- Terraform v1.6+ installed
- kubectl installed
- Docker installed (for local testing)
- GitHub repository with Actions enabled

### 1. Deploy Infrastructure

```bash
# Clone repository
git clone <repository-url>
cd mlops-azure

# Initialize Terraform
cd infra
terraform init

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_name         = "mlops-platform"
resource_group_name  = "mlops-platform-rg"
location            = "eastus"
environment         = "prod"
alert_email         = "your-email@example.com"
EOF

# Deploy infrastructure
terraform plan
terraform apply -auto-approve

# Save outputs
terraform output -json > ../outputs.json
```

**Deployment time**: ~20-25 minutes

### 2. Configure GitHub Secrets

Set the following secrets in your GitHub repository:

```bash
# Azure credentials
AZURE_CREDENTIALS        # Service principal JSON
AZURE_SUBSCRIPTION_ID    # Your subscription ID
AZURE_RESOURCE_GROUP     # Resource group name
AZURE_ML_WORKSPACE       # Azure ML workspace name

# Container Registry
ACR_LOGIN_SERVER         # ACR URL
ACR_USERNAME            # ACR admin username
ACR_PASSWORD            # ACR admin password

# Kubernetes
AKS_CLUSTER_NAME        # AKS cluster name

# Cosmos DB
COSMOS_DB_ENDPOINT      # Cosmos DB endpoint
COSMOS_DB_KEY           # Cosmos DB key
```

Get these values from Terraform outputs:

```bash
cd infra
terraform output acr_login_server
terraform output acr_admin_username
terraform output acr_admin_password
terraform output cosmos_db_endpoint
# etc.
```

### 3. Train and Deploy Models

```bash
# Trigger full MLOps pipeline
gh workflow run mlops-pipeline.yaml \
  --ref main \
  --field deployment_type=full-pipeline

# Or train models only
gh workflow run mlops-pipeline.yaml \
  --ref main \
  --field deployment_type=train

# Or deploy only
gh workflow run mlops-pipeline.yaml \
  --ref main \
  --field deployment_type=deploy
```

### 4. Verify Deployment

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group mlops-platform-rg \
  --name mlops-platform-aks

# Check deployments
kubectl get deployments -n mlops
kubectl get pods -n mlops
kubectl get svc -n mlops

# Get service endpoint
kubectl get svc ml-model-service -n mlops
```

### 5. Test Predictions

```bash
# Get the external IP
ENDPOINT=$(kubectl get svc ml-model-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health check
curl http://${ENDPOINT}/health

# Make prediction
curl -X POST http://${ENDPOINT}/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.5, 0.3, -0.2, 0.8, 0.1],
    "user_id": "user123"
  }'

# Check A/B test stats
curl http://${ENDPOINT}/ab-test/stats
```

## 🧪 A/B Testing

### How It Works

1. **Deploy two models**: Champion (Model A) and Challenger (Model B)
2. **Traffic splitting**: NGINX routes X% to Model A, Y% to Model B
3. **Consistent assignment**: Users always see the same variant (hash-based)
4. **Metrics collection**: All predictions logged to Cosmos DB
5. **Statistical analysis**: Automated comparison of model performance
6. **Promotion**: Winning model gets 100% traffic

### Running an A/B Test

```bash
# 1. Deploy both models (done automatically in CI/CD)
# Model A gets 90% traffic, Model B gets 10%

# 2. Let test run for sufficient sample size (typically 7-14 days)

# 3. Analyze results
cd mlops-azure/scripts
python ab_test_manager.py \
  --cosmos-endpoint $COSMOS_DB_ENDPOINT \
  --cosmos-key $COSMOS_DB_KEY \
  --experiment-id "ab_test_20250112" \
  --output report.json

# 4. Promote winner (if significant improvement)
kubectl patch ingress model-b-canary-ingress -n mlops \
  --type='json' \
  -p='[{"op": "replace", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1canary-weight", "value":"100"}]'
```

### Adjusting Traffic Split

```bash
# Give Model B 50% traffic
kubectl annotate ingress model-b-canary-ingress -n mlops \
  nginx.ingress.kubernetes.io/canary-weight=50 \
  --overwrite

# Give Model B 25% traffic
kubectl annotate ingress model-b-canary-ingress -n mlops \
  nginx.ingress.kubernetes.io/canary-weight=25 \
  --overwrite
```

## 📊 Monitoring Dashboards

### Access Dashboards

1. **Azure Portal** → Application Insights → Dashboards
2. Import `monitoring/azure-dashboard.json`
3. View real-time metrics:
   - Prediction volume and latency
   - Model accuracy over time
   - A/B test traffic distribution
   - Error rates and exceptions
   - Resource utilization

### Key Metrics

- **Request Rate**: Predictions per minute
- **Latency**: P50, P95, P99 response times
- **Accuracy**: Model prediction confidence
- **Error Rate**: Failed predictions percentage
- **A/B Traffic**: Distribution between variants
- **Cost**: Resource consumption tracking

### Custom Queries

See `monitoring/kql-queries.md` for comprehensive KQL queries for:
- Model performance analysis
- A/B test statistical comparison
- Error tracking and debugging
- Resource utilization trends
- Cost optimization insights

## 🔒 Security Features

- ✅ **Network isolation**: Private subnets for AKS nodes
- ✅ **Secrets management**: Azure Key Vault integration
- ✅ **RBAC**: Fine-grained access control
- ✅ **Container scanning**: Trivy vulnerability detection
- ✅ **SSL/TLS**: Encrypted communication
- ✅ **Service mesh**: Optional Istio integration
- ✅ **Network policies**: Kubernetes security rules
- ✅ **Azure Policy**: Compliance enforcement

## 📈 Scaling

### Horizontal Scaling (Pods)

Automatic via HPA:
- CPU threshold: 70%
- Memory threshold: 80%
- Min replicas: 2
- Max replicas: 20

### Vertical Scaling (Resources)

Adjust in Terraform:
```hcl
variable "aks_vm_size" {
  default = "Standard_D4s_v3"  # 4 vCPU, 16 GB RAM
}
```

### Cluster Scaling (Nodes)

Automatic via AKS cluster autoscaler:
- Min nodes: 2
- Max nodes: 10
- Scale based on pod resource requests

## 💰 Cost Optimization

### Monthly Cost Estimate (Production)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| **AKS** | 3 × D4s_v3 nodes | ~$360 |
| **Azure ML** | Compute + storage | ~$50 |
| **ACR** | Premium tier | ~$41 |
| **Cosmos DB** | 800 RU/s | ~$50 |
| **App Insights** | 5 GB/month | ~$12 |
| **Storage** | 100 GB | ~$3 |
| **Total** | | **~$516/month** |

### Cost Optimization Tips

1. **Use spot instances**: 70-90% savings for training
2. **Auto-scale to zero**: Scale down non-prod environments
3. **Reserved instances**: 30-50% savings for predictable workloads
4. **Optimize images**: Smaller containers = faster deployments
5. **Right-size resources**: Monitor and adjust pod limits
6. **Data retention**: Configure log retention policies

## 🔧 Configuration

### Environment Variables

```bash
# Model serving
MODEL_VERSION=A                              # Model variant (A or B)
APPLICATIONINSIGHTS_CONNECTION_STRING=...    # App Insights connection
COSMOS_DB_ENDPOINT=...                       # Cosmos DB endpoint
COSMOS_DB_KEY=...                           # Cosmos DB key
AB_TEST_TRAFFIC_SPLIT=0.5                   # Traffic split ratio

# Training
AZURE_SUBSCRIPTION_ID=...                    # Azure subscription
AZURE_ML_WORKSPACE=...                       # ML workspace name
AZURE_RESOURCE_GROUP=...                     # Resource group
```

### Terraform Variables

See `infra/variables.tf` for all configurable options:
- Project name and region
- AKS node size and count
- Alert email addresses
- Common tags
- Feature flags

## 📚 Documentation

- **[KQL Queries](monitoring/kql-queries.md)**: Azure Monitor query examples
- **[Terraform Docs](infra/)**: Infrastructure configuration
- **[API Documentation](api/)**: Model serving API reference
- **[Training Guide](models/)**: Model training instructions

## 🔄 CI/CD Pipeline

### Pipeline Stages

1. **Train Models** (optional)
   - Train Model A (Champion)
   - Train Model B (Challenger)
   - Upload artifacts

2. **Build & Push**
   - Build Docker images
   - Security scanning
   - Push to ACR

3. **Deploy**
   - Deploy to AKS
   - Health checks
   - Smoke tests

4. **A/B Test** (optional)
   - Statistical analysis
   - Winner determination
   - Report generation

5. **Promote** (manual approval)
   - Update traffic split
   - Create deployment tag

### Triggering Workflows

```bash
# Full pipeline
gh workflow run mlops-pipeline.yaml --field deployment_type=full-pipeline

# Individual stages
gh workflow run mlops-pipeline.yaml --field deployment_type=train
gh workflow run mlops-pipeline.yaml --field deployment_type=deploy
gh workflow run mlops-pipeline.yaml --field deployment_type=ab-test
```

## 🚨 Alerts and Notifications

Pre-configured alerts:
- Model accuracy drop > 5%
- Error rate > 5%
- Latency P95 > 2 seconds
- Health check failures
- Resource exhaustion

Configure alert emails in `infra/variables.tf`:
```hcl
variable "alert_email" {
  default = "your-email@example.com"
}
```

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details

## 🆘 Troubleshooting

### Common Issues

**Issue**: Pods not starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Check logs
kubectl logs <pod-name> -n mlops
```

**Issue**: Model predictions failing
```bash
# Check service logs
kubectl logs -l app=ml-model -n mlops --tail=100

# Check Application Insights for errors
```

**Issue**: A/B test not working
```bash
# Verify ingress configuration
kubectl get ingress -n mlops
kubectl describe ingress model-b-canary-ingress -n mlops

# Check traffic distribution
curl http://${ENDPOINT}/ab-test/stats
```

**Issue**: High costs
```bash
# Check resource utilization
kubectl top nodes
kubectl top pods -n mlops

# Review Azure Cost Management
az consumption usage list --output table
```

## 📞 Support

For issues and questions:
- GitHub Issues: [Create an issue]
- Documentation: [Wiki]
- Email: mlops-support@example.com

---

**Built with** ❤️ **by the MLOps Team**

**Last Updated**: 2025-01-12

**Version**: 1.0.0
