# MLOps Platform Deployment Guide

Complete step-by-step guide for deploying the end-to-end MLOps platform on Azure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Setup](#azure-setup)
3. [Infrastructure Deployment](#infrastructure-deployment)
4. [GitHub Configuration](#github-configuration)
5. [First Deployment](#first-deployment)
6. [Verification](#verification)
7. [Post-Deployment](#post-deployment)

## Prerequisites

### Required Tools

Install the following tools:

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# GitHub CLI (optional)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

### Azure Permissions

You need:
- Azure subscription with Owner or Contributor role
- Ability to create service principals
- Resource quota for:
  - 3+ vCPUs
  - Azure Kubernetes Service
  - Azure Container Registry

## Azure Setup

### 1. Login to Azure

```bash
az login
az account show

# Set subscription (if you have multiple)
az account set --subscription <subscription-id>
```

### 2. Create Service Principal

```bash
# Create service principal for Terraform
az ad sp create-for-rbac --name "mlops-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/<subscription-id>"

# Save the output:
# {
#   "appId": "...",          # CLIENT_ID
#   "displayName": "...",
#   "password": "...",       # CLIENT_SECRET
#   "tenant": "..."          # TENANT_ID
# }
```

### 3. Set Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant>"

# Reload
source ~/.bashrc
```

### 4. Create Terraform Backend Storage

```bash
# Create resource group for Terraform state
az group create \
  --name mlops-tfstate-rg \
  --location eastus

# Create storage account
az storage account create \
  --name mlopsplatformtfstate \
  --resource-group mlops-tfstate-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name mlopsplatformtfstate
```

## Infrastructure Deployment

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd mlops-azure
```

### 2. Configure Terraform

```bash
cd infra

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_name         = "mlops-platform"
resource_group_name  = "mlops-platform-rg"
location            = "eastus"
secondary_location  = "westus2"
environment         = "prod"
aks_node_count      = 3
aks_vm_size         = "Standard_D4s_v3"
alert_email         = "your-email@example.com"
EOF
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy (takes ~20-25 minutes)
terraform apply -auto-approve
```

### 4. Save Outputs

```bash
# Save all outputs to JSON
terraform output -json > ../outputs.json

# Save individual outputs
echo "ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)" >> ../env.sh
echo "ACR_USERNAME=$(terraform output -raw acr_admin_username)" >> ../env.sh
echo "ACR_PASSWORD=$(terraform output -raw acr_admin_password)" >> ../env.sh
echo "AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)" >> ../env.sh
echo "COSMOS_DB_ENDPOINT=$(terraform output -raw cosmos_db_endpoint)" >> ../env.sh
echo "COSMOS_DB_KEY=$(terraform output -raw cosmos_db_primary_key)" >> ../env.sh
echo "APP_INSIGHTS_KEY=$(terraform output -raw app_insights_instrumentation_key)" >> ../env.sh

# Load environment variables
source ../env.sh
```

## GitHub Configuration

### 1. Create GitHub Repository Secrets

Navigate to: `GitHub Repository → Settings → Secrets and variables → Actions`

Add the following secrets:

```bash
# Azure Credentials (for GitHub Actions)
# Create the JSON manually or use:
cat > azure-credentials.json <<EOF
{
  "clientId": "${ARM_CLIENT_ID}",
  "clientSecret": "${ARM_CLIENT_SECRET}",
  "subscriptionId": "${ARM_SUBSCRIPTION_ID}",
  "tenantId": "${ARM_TENANT_ID}"
}
EOF

# Add secrets via GitHub CLI
gh secret set AZURE_CREDENTIALS < azure-credentials.json
gh secret set AZURE_SUBSCRIPTION_ID -b"${ARM_SUBSCRIPTION_ID}"
gh secret set AZURE_RESOURCE_GROUP -b"mlops-platform-rg"
gh secret set AZURE_ML_WORKSPACE -b"mlops-platform-workspace"

# Container Registry
gh secret set ACR_LOGIN_SERVER -b"${ACR_LOGIN_SERVER}"
gh secret set ACR_USERNAME -b"${ACR_USERNAME}"
gh secret set ACR_PASSWORD -b"${ACR_PASSWORD}"

# Kubernetes
gh secret set AKS_CLUSTER_NAME -b"${AKS_CLUSTER_NAME}"

# Cosmos DB
gh secret set COSMOS_DB_ENDPOINT -b"${COSMOS_DB_ENDPOINT}"
gh secret set COSMOS_DB_KEY -b"${COSMOS_DB_KEY}"
```

Or add manually through GitHub UI:
1. Go to repository Settings
2. Click "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Add each secret from the list above

### 2. Verify Secrets

```bash
# List all secrets
gh secret list
```

## First Deployment

### 1. Get AKS Credentials

```bash
az aks get-credentials \
  --resource-group mlops-platform-rg \
  --name mlops-platform-aks \
  --overwrite-existing
```

### 2. Verify Kubernetes Access

```bash
kubectl get nodes
kubectl get namespaces
kubectl get all -n mlops
```

### 3. Trigger Pipeline

```bash
# Option A: Using GitHub CLI
gh workflow run mlops-pipeline.yaml \
  --ref main \
  --field deployment_type=full-pipeline

# Option B: Push to main branch
git add .
git commit -m "Initial MLOps platform deployment"
git push origin main

# Option C: Manual trigger via GitHub UI
# Go to Actions → MLOps CI/CD Pipeline → Run workflow
```

### 4. Monitor Pipeline

```bash
# Watch workflow status
gh run watch

# Or check in GitHub UI
# Go to Actions tab in your repository
```

## Verification

### 1. Check Deployments

```bash
# Check all resources in mlops namespace
kubectl get all -n mlops

# Check deployments
kubectl get deployments -n mlops
# Expected output:
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# model-a   3/3     3            3           5m
# model-b   3/3     3            3           5m

# Check pods
kubectl get pods -n mlops
# All pods should be in Running state

# Check services
kubectl get svc -n mlops
```

### 2. Get Service Endpoint

```bash
# Get external IP (may take a few minutes)
kubectl get svc ml-model-service -n mlops

# Save endpoint
export ENDPOINT=$(kubectl get svc ml-model-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Model endpoint: http://${ENDPOINT}"
```

### 3. Test Health Check

```bash
curl http://${ENDPOINT}/health

# Expected output:
# {
#   "status": "healthy",
#   "model_version": "A",
#   "model_loaded": true,
#   "timestamp": "2025-01-12T..."
# }
```

### 4. Test Prediction

```bash
curl -X POST http://${ENDPOINT}/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.5, 0.3, -0.2, 0.8, 0.1],
    "user_id": "test-user-123"
  }'

# Expected output:
# {
#   "prediction": 1,
#   "probability": 0.87,
#   "model_version": "A_A",
#   "request_id": "...",
#   "timestamp": "...",
#   "latency_ms": 45.2
# }
```

### 5. Test A/B Test Stats

```bash
curl http://${ENDPOINT}/ab-test/stats

# Expected output:
# {
#   "total_requests": 1,
#   "model_a_requests": 1,
#   "model_b_requests": 0,
#   "model_a_percentage": 100.0,
#   "model_b_percentage": 0.0,
#   "configured_split": 0.5
# }
```

### 6. Check Monitoring Dashboards

1. Open Azure Portal
2. Navigate to Application Insights: `mlops-platform-appinsights`
3. Go to Dashboards
4. Import `monitoring/azure-dashboard.json`
5. View real-time metrics

### 7. Verify A/B Testing

```bash
# Make multiple predictions with different user IDs
for i in {1..100}; do
  curl -s -X POST http://${ENDPOINT}/predict \
    -H "Content-Type: application/json" \
    -d "{\"features\": [0.5, 0.3, -0.2, 0.8, 0.1], \"user_id\": \"user-$i\"}" \
    | jq -r '.model_version'
done | sort | uniq -c

# Should see roughly 50% A and 50% B
```

## Post-Deployment

### 1. Configure Monitoring Alerts

```bash
# Already created by Terraform, verify in Azure Portal
az monitor metrics alert list \
  --resource-group mlops-platform-rg \
  --output table
```

### 2. Set Up Custom Metrics

Add custom metrics in your application code:

```python
from applicationinsights import TelemetryClient
tc = TelemetryClient(instrumentation_key='...')

# Track custom metric
tc.track_metric('model_accuracy', accuracy)
tc.flush()
```

### 3. Configure Log Retention

```bash
# Set Log Analytics retention (default: 30 days)
az monitor log-analytics workspace update \
  --resource-group mlops-platform-rg \
  --workspace-name mlops-platform-logs \
  --retention-time 90
```

### 4. Enable Cost Alerts

```bash
# Create budget alert
az consumption budget create \
  --budget-name mlops-monthly-budget \
  --amount 1000 \
  --resource-group mlops-platform-rg \
  --time-grain Monthly \
  --start-date 2025-01-01 \
  --end-date 2026-01-01
```

### 5. Document Your Deployment

Create a deployment record:

```bash
cat > deployment-info.md <<EOF
# MLOps Platform Deployment Info

**Deployed**: $(date)
**Environment**: Production
**Region**: East US
**Endpoint**: http://${ENDPOINT}

## Access Info
- Resource Group: mlops-platform-rg
- AKS Cluster: mlops-platform-aks
- ACR: ${ACR_LOGIN_SERVER}
- Application Insights: mlops-platform-appinsights

## Team Contacts
- DevOps: devops@example.com
- ML Engineers: ml-team@example.com
- Oncall: oncall@example.com
EOF
```

### 6. Enable Auto-Scaling (if not already)

```bash
# Verify HPA is working
kubectl get hpa -n mlops

# Check autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

### 7. Set Up Backup Strategy

```bash
# Enable AKS backup (optional)
# Configure via Azure Backup service in portal

# Backup Terraform state
az storage blob snapshot \
  --account-name mlopsplatformtfstate \
  --container-name tfstate \
  --name mlops.terraform.tfstate
```

## Troubleshooting

### Issue: Terraform deployment fails

```bash
# Check Azure CLI authentication
az account show

# Check Terraform logs
terraform apply -auto-approve TF_LOG=DEBUG

# Common fixes:
# 1. Check subscription quotas
az vm list-usage --location eastus --output table

# 2. Check service principal permissions
az role assignment list --assignee <sp-app-id>
```

### Issue: Pipeline fails at build step

```bash
# Check GitHub Actions logs in UI
# Common causes:
# 1. Missing secrets
gh secret list

# 2. Wrong ACR credentials
az acr login --name <acr-name>

# 3. Image build failures
docker build -t test ./mlops-azure/api
```

### Issue: Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Check logs
kubectl logs <pod-name> -n mlops

# Common causes:
# 1. Image pull errors - check ACR credentials
# 2. Resource limits - check node capacity
kubectl describe nodes

# 3. ConfigMap/Secret issues
kubectl get configmap -n mlops
kubectl get secrets -n mlops
```

### Issue: Load balancer not getting external IP

```bash
# Check service status
kubectl describe svc ml-model-service -n mlops

# Check events
kubectl get events -n mlops --sort-by='.lastTimestamp'

# Common causes:
# 1. Azure quota limits
# 2. Network configuration issues
# 3. Wait time (can take 5-10 minutes)
```

## Next Steps

1. **Run A/B Test**: See main README.md
2. **Add Custom Models**: Update training pipeline
3. **Configure Auto-Scaling**: Adjust HPA settings
4. **Set Up Monitoring Alerts**: Create custom alerts
5. **Optimize Costs**: Right-size resources

## Support

For help:
- GitHub Issues: [Link]
- Documentation: [Link]
- Email: mlops-support@example.com

---

**Deployment Guide Version**: 1.0.0
**Last Updated**: 2025-01-12
