# MLOps Platform - Quick Start Deployment

Deploy the complete MLOps platform to Azure in **30 minutes**.

## ⚡ One-Command Deployment

```bash
# Clone and deploy
git clone https://github.com/nkefor/2048-cicd-enterprise.git
cd 2048-cicd-enterprise/mlops-azure
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

That's it! The script will:
1. ✅ Check prerequisites
2. ✅ Collect configuration
3. ✅ Deploy Azure infrastructure (~20-25 min)
4. ✅ Configure Kubernetes
5. ✅ Verify deployment

## 📋 Prerequisites

### Required:
- **Azure Account** with active subscription
- **Azure CLI** installed ([Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Terraform** v1.6+ installed ([Install](https://www.terraform.io/downloads))
- **kubectl** installed ([Install](https://kubernetes.io/docs/tasks/tools/))

### Check Prerequisites:
```bash
# Check Azure CLI
az --version

# Check Terraform
terraform --version

# Check kubectl
kubectl version --client

# Login to Azure
az login
```

## 🚀 Deployment Options

### Option 1: Automated Script (Recommended)
```bash
cd mlops-azure
./scripts/deploy.sh
```

### Option 2: Manual Deployment
```bash
# 1. Navigate to infrastructure
cd mlops-azure/infra

# 2. Create configuration
cat > terraform.tfvars <<EOF
project_name         = "mlops-platform"
resource_group_name  = "mlops-platform-rg"
location            = "eastus"
environment         = "prod"
alert_email         = "your-email@example.com"
EOF

# 3. Initialize Terraform
terraform init

# 4. Deploy
terraform apply -auto-approve

# 5. Get AKS credentials
az aks get-credentials \
  --resource-group mlops-platform-rg \
  --name mlops-platform-aks
```

## ✅ Verify Deployment

```bash
# Check Azure resources
az resource list \
  --resource-group mlops-platform-rg \
  --output table

# Check Kubernetes
kubectl get nodes
kubectl get all -n mlops

# Check service endpoint
kubectl get svc ml-model-service -n mlops
```

## 🎯 Deploy Your First Model

### 1. Configure GitHub Secrets

Get values from Terraform outputs:
```bash
cd mlops-azure/infra
terraform output acr_login_server
terraform output acr_admin_username
terraform output acr_admin_password
terraform output cosmos_db_endpoint
```

Add to GitHub Secrets:
- `AZURE_CREDENTIALS` - Service principal JSON
- `AZURE_SUBSCRIPTION_ID` - Your subscription ID
- `AZURE_RESOURCE_GROUP` - `mlops-platform-rg`
- `AZURE_ML_WORKSPACE` - `mlops-platform-workspace`
- `ACR_LOGIN_SERVER` - From output above
- `ACR_USERNAME` - From output above
- `ACR_PASSWORD` - From output above
- `AKS_CLUSTER_NAME` - `mlops-platform-aks`
- `COSMOS_DB_ENDPOINT` - From output above
- `COSMOS_DB_KEY` - From output above

### 2. Trigger Pipeline

```bash
# Using GitHub CLI
gh workflow run mlops-pipeline.yaml \
  --ref main \
  --field deployment_type=full-pipeline

# Or push to trigger
git push origin main
```

### 3. Monitor Deployment

```bash
# Watch GitHub Actions
gh run watch

# Check pods
kubectl get pods -n mlops -w

# Check service
ENDPOINT=$(kubectl get svc ml-model-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${ENDPOINT}/health
```

## 🧪 Test Your Model

```bash
# Get endpoint
ENDPOINT=$(kubectl get svc ml-model-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Make prediction
curl -X POST http://${ENDPOINT}/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.5, 0.3, -0.2, 0.8, 0.1],
    "user_id": "test-user-123"
  }'

# Expected response:
{
  "prediction": 1,
  "probability": 0.87,
  "model_version": "A_A",
  "request_id": "...",
  "timestamp": "...",
  "latency_ms": 45.2
}
```

## 📊 Access Dashboards

### Azure ML Studio
```bash
# Get workspace URL
echo "https://ml.azure.com/?workspace=mlops-platform-workspace&tid=$(az account show --query tenantId -o tsv)"
```

### Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to resource group: `mlops-platform-rg`
3. Open Application Insights: `mlops-platform-appinsights`
4. View dashboards and metrics

### Kubernetes Dashboard
```bash
# Port forward to access locally
kubectl port-forward -n mlops svc/ml-model-service 8080:80

# Access at http://localhost:8080
```

## 💰 Cost Estimate

### Development Environment
- **Monthly Cost**: ~$200-300
- **Components**:
  - AKS (3 nodes): ~$150
  - Azure ML: ~$20
  - ACR: ~$5
  - Cosmos DB: ~$25
  - Storage: ~$3

### Production Environment
- **Monthly Cost**: ~$500-700
- **Components**:
  - AKS (5-10 nodes): ~$350
  - Azure ML: ~$50
  - ACR: ~$40
  - Cosmos DB: ~$50
  - Storage: ~$10

**Cost Optimization Tips**:
- Scale AKS nodes to 0 during off-hours
- Use Azure ML Spot instances for training (70% savings)
- Enable auto-scaling to match actual load
- Use lifecycle policies for old container images

## 🧹 Clean Up

### Delete Everything
```bash
cd mlops-azure/infra
terraform destroy -auto-approve
```

### Delete Specific Resources
```bash
# Delete resource group
az group delete \
  --name mlops-platform-rg \
  --yes --no-wait
```

## 🆘 Troubleshooting

### Issue: Terraform timeout
```bash
# Increase timeout
export TF_TIMEOUT=30m
terraform apply
```

### Issue: Insufficient quota
```bash
# Check quota
az vm list-usage --location eastus --output table

# Request quota increase in Azure Portal
```

### Issue: AKS creation fails
```bash
# Check service principal
az ad sp list --display-name mlops-terraform-sp

# Recreate if needed
az ad sp create-for-rbac --name mlops-terraform-sp --role Contributor
```

### Issue: Pods not starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Check events
kubectl get events -n mlops --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n mlops
```

## 📚 Next Steps

1. **Train Models**:
   - Review `models/train_model.py`
   - Run hyperparameter tuning
   - Try distributed training

2. **A/B Testing**:
   - Deploy two model variants
   - Monitor performance metrics
   - Analyze results with `scripts/ab_test_manager.py`

3. **Monitoring**:
   - Set up custom alerts
   - Create KQL queries for business metrics
   - Configure cost alerts

4. **Optimization**:
   - Fine-tune auto-scaling policies
   - Optimize model serving latency
   - Reduce infrastructure costs

## 🔗 Helpful Links

- **Deployment Guide**: [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- **Full README**: [README.md](README.md)
- **Monitoring Queries**: [monitoring/kql-queries.md](monitoring/kql-queries.md)
- **Azure ML Docs**: https://docs.microsoft.com/en-us/azure/machine-learning/
- **AKS Docs**: https://docs.microsoft.com/en-us/azure/aks/

## ✅ Deployment Checklist

- [ ] Azure account with sufficient quota
- [ ] Prerequisites installed (Azure CLI, Terraform, kubectl)
- [ ] Logged in to Azure (`az login`)
- [ ] Run deployment script
- [ ] Configure GitHub secrets
- [ ] Trigger CI/CD pipeline
- [ ] Verify model deployment
- [ ] Test predictions
- [ ] Set up monitoring alerts
- [ ] Configure cost tracking

---

**Estimated Time**: 30 minutes (20 min infrastructure + 10 min configuration)

**Support**: For issues, check [TROUBLESHOOTING section](#-troubleshooting) or create a GitHub issue.
