#!/bin/bash
# Quick Deployment Script for MLOps Platform
# This script automates the deployment of the MLOps platform to Azure

set -e  # Exit on error

echo "================================================"
echo "MLOps Platform Deployment Script"
echo "================================================"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check prerequisites
echo ""
echo "Checking prerequisites..."

# Check Azure CLI
if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
print_status "Azure CLI found"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install: https://www.terraform.io/downloads"
    exit 1
fi
print_status "Terraform found"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
print_status "kubectl found"

# Check Azure login
echo ""
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Logging in..."
    az login
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_status "Logged in to Azure subscription: $SUBSCRIPTION_NAME"

# Get configuration from user
echo ""
echo "================================================"
echo "Configuration"
echo "================================================"

read -p "Enter project name [mlops-platform]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-mlops-platform}

read -p "Enter Azure region [eastus]: " LOCATION
LOCATION=${LOCATION:-eastus}

read -p "Enter your email for alerts: " ALERT_EMAIL

read -p "Enter environment [prod]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-prod}

RESOURCE_GROUP="${PROJECT_NAME}-rg"

echo ""
echo "Configuration Summary:"
echo "  Project Name: $PROJECT_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Environment: $ENVIRONMENT"
echo "  Alert Email: $ALERT_EMAIL"
echo ""

read -p "Proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Navigate to infrastructure directory
cd mlops-azure/infra

# Create terraform.tfvars
echo ""
print_status "Creating terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_name         = "$PROJECT_NAME"
resource_group_name  = "$RESOURCE_GROUP"
location            = "$LOCATION"
secondary_location  = "westus2"
environment         = "$ENVIRONMENT"
aks_node_count      = 3
aks_vm_size         = "Standard_D4s_v3"
alert_email         = "$ALERT_EMAIL"
EOF

print_status "Configuration file created"

# Initialize Terraform
echo ""
echo "================================================"
echo "Step 1: Initialize Terraform"
echo "================================================"
terraform init

# Validate configuration
echo ""
echo "================================================"
echo "Step 2: Validate Configuration"
echo "================================================"
terraform validate
print_status "Configuration is valid"

# Plan deployment
echo ""
echo "================================================"
echo "Step 3: Plan Deployment"
echo "================================================"
terraform plan -out=tfplan

# Apply deployment
echo ""
echo "================================================"
echo "Step 4: Deploy Infrastructure"
echo "================================================"
echo "This will take approximately 20-25 minutes..."
echo ""

terraform apply tfplan

print_status "Infrastructure deployed successfully!"

# Save outputs
echo ""
print_status "Saving outputs..."
terraform output -json > ../outputs.json

# Extract important values
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
COSMOS_DB_ENDPOINT=$(terraform output -raw cosmos_db_endpoint)

# Get AKS credentials
echo ""
echo "================================================"
echo "Step 5: Configure kubectl"
echo "================================================"
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME \
    --overwrite-existing

print_status "kubectl configured"

# Verify deployment
echo ""
echo "================================================"
echo "Step 6: Verify Deployment"
echo "================================================"

echo "Checking Kubernetes nodes..."
kubectl get nodes

echo ""
echo "Checking MLOps namespace..."
kubectl get all -n mlops

# Print summary
echo ""
echo "================================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "================================================"
echo ""
echo "📊 Deployment Summary:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $AKS_CLUSTER_NAME"
echo "  ACR: $ACR_LOGIN_SERVER"
echo "  Location: $LOCATION"
echo ""
echo "🔗 Important Values for GitHub Secrets:"
echo "  AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "  AZURE_RESOURCE_GROUP: $RESOURCE_GROUP"
echo "  AKS_CLUSTER_NAME: $AKS_CLUSTER_NAME"
echo "  ACR_LOGIN_SERVER: $ACR_LOGIN_SERVER"
echo ""
echo "📝 Next Steps:"
echo "  1. Configure GitHub Secrets (see DEPLOYMENT-GUIDE.md)"
echo "  2. Trigger CI/CD pipeline to deploy models"
echo "  3. Access Azure ML Studio to view experiments"
echo "  4. Monitor in Azure Portal"
echo ""
echo "📚 Documentation:"
echo "  - Deployment Guide: mlops-azure/DEPLOYMENT-GUIDE.md"
echo "  - README: mlops-azure/README.md"
echo "  - Monitoring Queries: mlops-azure/monitoring/kql-queries.md"
echo ""
echo "🎉 Your MLOps platform is ready!"
