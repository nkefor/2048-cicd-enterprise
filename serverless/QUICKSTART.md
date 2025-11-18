# Quick Start - Deploy in 15 Minutes

Fast-track deployment guide to get your serverless application running on AWS.

## Prerequisites ✅

- AWS Account
- AWS CLI configured (`aws configure`)
- Terraform installed
- Python 3.12+

---

## Step 1: AWS Setup (5 minutes)

### Create S3 Bucket for Terraform State

```bash
# Replace with your unique bucket name
BUCKET_NAME="my-serverless-terraform-state-$(date +%s)"

aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
```

### Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Save your bucket name** - you'll need it in Step 3!

---

## Step 2: Package Lambda Functions (2 minutes)

```bash
cd serverless

# Make script executable
chmod +x scripts/package-lambdas.sh

# Package all Lambda functions
./scripts/package-lambdas.sh
```

You should see:
```
✅ create-task packaged successfully
✅ get-task packaged successfully
...
✅ All Lambda functions packaged successfully!
```

---

## Step 3: Deploy Infrastructure (5 minutes)

```bash
cd infra

# Initialize Terraform (replace YOUR_BUCKET with the bucket from Step 1)
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="region=us-east-1"

# Deploy everything
terraform apply \
  -var="aws_region=us-east-1" \
  -var="environment=dev" \
  -auto-approve
```

⏳ **Deployment takes ~5 minutes**

---

## Step 4: Test Your API (3 minutes)

### Get API URL

```bash
# Still in serverless/infra directory
API_URL=$(terraform output -raw api_gateway_url)
echo "Your API URL: $API_URL"
```

### Run Automated Tests

```bash
cd ..
./scripts/test-api.sh $API_URL
```

You should see:
```
✓ Task created successfully
✓ Task retrieved successfully
✓ Task updated successfully
...
All tests passed successfully! ✓
```

---

## 🎉 Done! Your Serverless App is Live

### What You Just Deployed

| Component | Details |
|-----------|---------|
| **API Gateway** | RESTful API with 5 endpoints |
| **Lambda Functions** | 8 functions (5 API + 3 event handlers) |
| **DynamoDB** | Tasks table with encryption |
| **EventBridge** | Custom event bus |
| **Step Functions** | Approval workflow |
| **CloudWatch** | Dashboard + 8 alarms |

### Your Endpoints

```bash
# Create a task
curl -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Task",
    "description": "Testing serverless API",
    "priority": "high",
    "userId": "user123"
  }'

# List tasks
curl -X GET "$API_URL/tasks"

# Get specific task
curl -X GET "$API_URL/tasks/{taskId}"

# Update task
curl -X PUT "$API_URL/tasks/{taskId}" \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'

# Delete task
curl -X DELETE "$API_URL/tasks/{taskId}"
```

---

## View in AWS Console

### CloudWatch Dashboard
1. Go to AWS Console → CloudWatch → Dashboards
2. Open `task-manager-dashboard-dev`
3. View real-time metrics

### Lambda Functions
1. Go to AWS Console → Lambda
2. You'll see 8 functions starting with `task-manager-`
3. Click any function to view code and logs

### DynamoDB Table
1. Go to AWS Console → DynamoDB → Tables
2. Open `task-manager-tasks-dev`
3. Click "Explore items" to see your data

### Step Functions
1. Go to AWS Console → Step Functions
2. Open `task-manager-task-approval-dev`
3. View workflow executions

### API Gateway
1. Go to AWS Console → API Gateway
2. Find your HTTP API
3. View routes and integrations

---

## Monitor Your Application

### View Logs

```bash
# View create-task function logs
aws logs tail /aws/lambda/task-manager-create-task-dev --follow

# View all Lambda logs
aws logs tail --follow --filter-pattern "ERROR"
```

### Check Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix task-manager

# Check alarm status
aws cloudwatch describe-alarms \
  --state-value ALARM
```

---

## Cost Tracking

### Current Month Costs

```bash
# Estimated cost for current month
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE
```

**Expected**: ~$7-10 for first month (mostly CloudWatch logs)

---

## Troubleshooting

### ❌ Terraform Init Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify S3 bucket exists
aws s3 ls s3://YOUR_BUCKET_NAME
```

### ❌ Lambda Function Errors

```bash
# Check function logs
aws logs tail /aws/lambda/task-manager-create-task-dev --since 10m

# Test function directly
aws lambda invoke \
  --function-name task-manager-create-task-dev \
  --payload '{"body":"{\"title\":\"Test\",\"userId\":\"user1\",\"priority\":\"low\"}"}' \
  response.json
```

### ❌ API Returns 403

- Check Lambda execution role has correct permissions
- Verify API Gateway integration permissions
- Check CloudWatch logs for errors

---

## GitHub Actions Setup (Optional)

To enable automated deployments:

### Add GitHub Secrets

Go to your repo → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_REGION`: `us-east-1`
- `AWS_ROLE_ARN`: Your IAM role ARN for GitHub Actions
- `TERRAFORM_STATE_BUCKET`: Your S3 bucket name

### Trigger Deployment

```bash
# Push to main branch
git push origin main

# Or manually trigger
# Go to GitHub → Actions → Serverless CI/CD Pipeline → Run workflow
```

---

## Clean Up (When Done Testing)

### Destroy All Resources

```bash
cd serverless/infra

terraform destroy \
  -var="aws_region=us-east-1" \
  -var="environment=dev" \
  -auto-approve
```

### Delete State Storage

```bash
# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks

# Delete S3 bucket (must be empty)
aws s3 rb s3://YOUR_BUCKET_NAME --force
```

**⚠️ Warning**: This permanently deletes all data!

---

## Next Steps

### Add Custom Domain
```bash
# Register domain in Route 53
# Create ACM certificate
# Add custom domain to API Gateway
```

### Enable Authentication
```bash
# Set up Cognito user pool
# Add JWT authorizer to API Gateway
```

### Add More Features
- WebSocket support for real-time updates
- S3 integration for file uploads
- SNS/SES for email notifications
- Cognito for user authentication

### Multi-Environment Setup
```bash
# Create staging environment
terraform workspace new staging
terraform apply -var="environment=staging"

# Create production environment
terraform workspace new prod
terraform apply -var="environment=prod"
```

---

## Support

- **Full Guide**: See `DEPLOYMENT-GUIDE.md` for detailed instructions
- **Architecture**: See `../README.md` for architecture details
- **API Docs**: See `../README.md` for API documentation
- **Troubleshooting**: Check CloudWatch logs first

---

## Summary

You've successfully deployed:

✅ Serverless API with 5 endpoints
✅ Event-driven architecture
✅ DynamoDB database
✅ Step Functions workflow
✅ Complete monitoring

**Deployment Time**: ~15 minutes
**Monthly Cost**: ~$7-10
**Endpoints**: Live and ready to use!

---

**Happy Serverless Building! 🚀**
