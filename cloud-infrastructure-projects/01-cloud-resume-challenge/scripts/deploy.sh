#!/bin/bash
set -e

# Cloud Resume Challenge - Deployment Script
# This script automates the deployment of the entire infrastructure

echo "========================================"
echo "Cloud Resume Challenge - Deployment"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Load environment variables
source .env

# Function to print section headers
print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command_exists aws; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS CLI is installed${NC}"

if ! command_exists terraform; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform is installed${NC}"

if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3 is installed${NC}"

# Verify AWS credentials
print_header "Verifying AWS Credentials"
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS credentials are valid${NC}"
    echo "Account ID: $ACCOUNT_ID"
else
    echo -e "${RED}❌ AWS credentials are invalid${NC}"
    exit 1
fi

# Create Terraform backend resources if they don't exist
print_header "Setting Up Terraform Backend"

# Check if S3 bucket exists
if aws s3 ls "s3://${TF_STATE_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3api create-bucket \
        --bucket "${TF_STATE_BUCKET}" \
        --region "${AWS_REGION}" || true

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${TF_STATE_BUCKET}" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "${TF_STATE_BUCKET}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    echo -e "${GREEN}✅ S3 bucket created${NC}"
else
    echo -e "${GREEN}✅ S3 bucket already exists${NC}"
fi

# Check if DynamoDB table exists
if ! aws dynamodb describe-table --table-name "${TF_STATE_LOCK_TABLE}" >/dev/null 2>&1; then
    echo "Creating DynamoDB table for Terraform state locking..."
    aws dynamodb create-table \
        --table-name "${TF_STATE_LOCK_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"

    echo "Waiting for table to be created..."
    aws dynamodb wait table-exists --table-name "${TF_STATE_LOCK_TABLE}"
    echo -e "${GREEN}✅ DynamoDB table created${NC}"
else
    echo -e "${GREEN}✅ DynamoDB table already exists${NC}"
fi

# Deploy Lambda function
print_header "Building Lambda Deployment Package"

cd src/lambda

# Install dependencies
echo "Installing Lambda dependencies..."
rm -rf package
mkdir -p package
pip install boto3 -t package/ -q

# Copy Lambda code
cp visitor_counter.py package/

# Create ZIP file
cd package
zip -r ../lambda-deployment.zip . -q
cd ..
rm -rf package

echo -e "${GREEN}✅ Lambda deployment package created${NC}"

cd ../..

# Run Terraform
print_header "Deploying Infrastructure with Terraform"

cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
aws_region      = "${AWS_REGION}"
environment     = "${ENVIRONMENT}"
domain_name     = "${DOMAIN_NAME}"
route53_zone_id = "${ROUTE53_ZONE_ID}"
project_name    = "${PROJECT_NAME}"
EOF

# Initialize Terraform
echo "Initializing Terraform..."
terraform init \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="key=prod/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE}"

# Validate Terraform
echo "Validating Terraform configuration..."
terraform validate

# Plan Terraform
echo "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply Terraform (ask for confirmation)
echo ""
read -p "Do you want to apply these changes? (yes/no): " APPLY_CONFIRM
if [ "$APPLY_CONFIRM" = "yes" ]; then
    echo "Applying Terraform configuration..."
    terraform apply tfplan

    # Get outputs
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Infrastructure Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    WEBSITE_URL=$(terraform output -raw website_url)
    API_ENDPOINT=$(terraform output -raw api_custom_domain)
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    LAMBDA_NAME=$(terraform output -raw lambda_function_name)

    echo "Website URL: $WEBSITE_URL"
    echo "API Endpoint: $API_ENDPOINT"
    echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
    echo "S3 Bucket: $S3_BUCKET"
    echo "Lambda Function: $LAMBDA_NAME"

    # Update .env with outputs
    cd ..
    sed -i "s|^API_ENDPOINT=.*|API_ENDPOINT=${API_ENDPOINT}|" .env
    sed -i "s|^CLOUDFRONT_DISTRIBUTION_ID=.*|CLOUDFRONT_DISTRIBUTION_ID=${CLOUDFRONT_ID}|" .env
    sed -i "s|^S3_BUCKET_NAME=.*|S3_BUCKET_NAME=${S3_BUCKET}|" .env
    sed -i "s|^LAMBDA_FUNCTION_NAME=.*|LAMBDA_FUNCTION_NAME=${LAMBDA_NAME}|" .env

else
    echo -e "${YELLOW}⚠️  Terraform apply cancelled${NC}"
    cd ..
    exit 0
fi

cd ..

# Deploy frontend
print_header "Deploying Frontend to S3"

# Update API endpoint in JavaScript
sed -i "s|https://api.resume.yourdomain.com|${API_ENDPOINT}|g" frontend/js/script.js

# Upload to S3
echo "Uploading files to S3..."
aws s3 sync frontend/ "s3://${S3_BUCKET}/" \
    --delete \
    --cache-control "max-age=31536000" \
    --exclude "*.html"

# Upload HTML with shorter cache
aws s3 sync frontend/ "s3://${S3_BUCKET}/" \
    --cache-control "max-age=3600" \
    --exclude "*" \
    --include "*.html"

echo -e "${GREEN}✅ Frontend uploaded to S3${NC}"

# Invalidate CloudFront cache
print_header "Invalidating CloudFront Cache"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "${CLOUDFRONT_ID}" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

echo "Invalidation ID: $INVALIDATION_ID"
echo -e "${GREEN}✅ CloudFront cache invalidated${NC}"

# Final summary
print_header "Deployment Summary"

echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo "🌐 Website URL: ${WEBSITE_URL}"
echo "🚀 API Endpoint: ${API_ENDPOINT}"
echo "📦 S3 Bucket: ${S3_BUCKET}"
echo "⚡ Lambda Function: ${LAMBDA_NAME}"
echo "🌍 CloudFront Distribution: ${CLOUDFRONT_ID}"
echo ""
echo "Next steps:"
echo "1. Wait a few minutes for CloudFront to propagate"
echo "2. Visit ${WEBSITE_URL} to see your resume"
echo "3. Check CloudWatch logs if needed"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Thank you for using Cloud Resume Challenge!${NC}"
echo -e "${GREEN}========================================${NC}"
