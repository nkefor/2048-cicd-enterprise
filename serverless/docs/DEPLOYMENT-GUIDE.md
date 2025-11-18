# Serverless Application Deployment Guide

Complete step-by-step guide to deploy the serverless task management system to AWS.

## Prerequisites

### Required Tools

1. **AWS Account** with administrative access
2. **AWS CLI** (v2.x or higher)
   ```bash
   aws --version
   # aws-cli/2.x.x Python/3.x
   ```

3. **Terraform** (v1.7.0 or higher)
   ```bash
   terraform --version
   # Terraform v1.7.0
   ```

4. **Python** (3.12 or higher)
   ```bash
   python --version
   # Python 3.12.x
   ```

5. **Git**
   ```bash
   git --version
   ```

### AWS Permissions

Your AWS IAM user/role needs permissions for:
- Lambda (create, update, invoke)
- API Gateway (create, manage)
- DynamoDB (create, manage tables)
- EventBridge (create event buses, rules)
- Step Functions (create state machines)
- IAM (create roles, policies)
- KMS (create keys, encrypt/decrypt)
- CloudWatch (create log groups, dashboards, alarms)
- S3 (for Terraform state)

## Step 1: AWS Setup

### 1.1 Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json
```

### 1.2 Create S3 Bucket for Terraform State

```bash
# Create bucket
aws s3 mb s3://my-terraform-state-bucket-unique-name --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket-unique-name \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket my-terraform-state-bucket-unique-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 1.3 Create DynamoDB Table for Terraform Locks

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 1.4 Create IAM Role for GitHub Actions (OIDC)

```bash
# Create trust policy
cat > github-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-serverless \
  --assume-role-policy-document file://github-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name github-actions-serverless \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

## Step 2: Local Setup

### 2.1 Clone Repository

```bash
git clone https://github.com/YOUR_ORG/2048-cicd-enterprise.git
cd 2048-cicd-enterprise/serverless
```

### 2.2 Install Python Dependencies

```bash
python -m pip install --upgrade pip
pip install -r lambda/requirements.txt
```

### 2.3 Package Lambda Functions

```bash
chmod +x scripts/package-lambdas.sh
./scripts/package-lambdas.sh
```

Expected output:
```
📦 Packaging Lambda functions...
📦 Packaging API Lambda functions...
Packaging create-task...
✅ create-task packaged successfully
Packaging get-task...
✅ get-task packaged successfully
...
✅ All Lambda functions packaged successfully!
```

## Step 3: Deploy Infrastructure

### 3.1 Initialize Terraform

```bash
cd infra

terraform init \
  -backend-config="bucket=my-terraform-state-bucket-unique-name" \
  -backend-config="region=us-east-1"
```

### 3.2 Review Terraform Plan

```bash
terraform plan \
  -var="aws_region=us-east-1" \
  -var="environment=dev" \
  -var="alarm_email=your.email@example.com"
```

Review the plan carefully to ensure:
- All resources are being created correctly
- No unexpected changes
- Estimated costs are acceptable

### 3.3 Apply Terraform Configuration

```bash
terraform apply \
  -var="aws_region=us-east-1" \
  -var="environment=dev" \
  -var="alarm_email=your.email@example.com"
```

Type `yes` when prompted.

Deployment takes approximately **5-10 minutes**.

### 3.4 Verify Deployment

```bash
# Get API Gateway URL
terraform output api_gateway_url

# Get DynamoDB table name
terraform output dynamodb_table_name

# Get all Lambda function ARNs
terraform output lambda_functions
```

## Step 4: Configure GitHub Actions

### 4.1 Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ROLE_ARN` | IAM role ARN | `arn:aws:iam::123456789012:role/github-actions-serverless` |
| `TERRAFORM_STATE_BUCKET` | S3 bucket name | `my-terraform-state-bucket-unique-name` |

### 4.2 Enable GitHub Actions

1. Go to your repository → Actions
2. Enable workflows if not already enabled
3. Push a commit to trigger the CI/CD pipeline

```bash
git add .
git commit -m "feat: Deploy serverless application"
git push origin main
```

### 4.3 Monitor Workflow

1. Go to GitHub Actions tab
2. Watch the "Serverless CI/CD Pipeline" workflow
3. Ensure all jobs pass:
   - Security Scanning ✅
   - Lint and Test ✅
   - Terraform Validation ✅
   - Package Lambda Functions ✅
   - Deploy Infrastructure ✅

## Step 5: Test the API

### 5.1 Get API URL

```bash
cd serverless/infra
API_URL=$(terraform output -raw api_gateway_url)
echo "API URL: $API_URL"
```

### 5.2 Create a Task

```bash
curl -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing the serverless API",
    "priority": "medium",
    "userId": "user123",
    "tags": ["test"]
  }'
```

Expected response:
```json
{
  "message": "Task created successfully",
  "task": {
    "taskId": "uuid-here",
    "title": "Test Task",
    "status": "pending",
    ...
  }
}
```

### 5.3 List Tasks

```bash
curl -X GET "$API_URL/tasks"
```

### 5.4 Get Specific Task

```bash
TASK_ID="uuid-from-previous-response"
curl -X GET "$API_URL/tasks/$TASK_ID"
```

### 5.5 Update Task

```bash
curl -X PUT "$API_URL/tasks/$TASK_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "priority": "high"
  }'
```

### 5.6 Delete Task

```bash
curl -X DELETE "$API_URL/tasks/$TASK_ID"
```

## Step 6: Monitor and Verify

### 6.1 Check CloudWatch Logs

```bash
# List log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/task-manager"

# Tail logs for create-task function
aws logs tail /aws/lambda/task-manager-create-task-dev --follow
```

### 6.2 View CloudWatch Dashboard

1. Go to AWS Console → CloudWatch → Dashboards
2. Open `task-manager-dashboard-dev`
3. Review metrics for:
   - Lambda invocations and errors
   - DynamoDB operations
   - API Gateway requests
   - Step Functions executions

### 6.3 Check DynamoDB Data

```bash
# List items in tasks table
aws dynamodb scan \
  --table-name task-manager-tasks-dev \
  --max-items 10
```

### 6.4 View EventBridge Events

```bash
# Describe event bus
aws events describe-event-bus \
  --name task-manager-events-dev
```

## Step 7: Test Event-Driven Workflows

### 7.1 Create High-Priority Task

```bash
curl -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Urgent Task",
    "description": "High priority task for testing",
    "priority": "high",
    "userId": "user123"
  }'
```

This should trigger the Step Functions approval workflow.

### 7.2 Check Step Functions Execution

```bash
# List executions
aws stepfunctions list-executions \
  --state-machine-arn $(cd infra && terraform output -raw step_function_arn)
```

### 7.3 View Execution in Console

1. Go to AWS Console → Step Functions
2. Click on `task-manager-task-approval-dev`
3. View recent executions and state transitions

## Step 8: Configure Alarms (Optional)

### 8.1 Confirm SNS Subscription

If you provided an email for `alarm_email`:

1. Check your email for AWS SNS subscription confirmation
2. Click "Confirm subscription"
3. You'll now receive CloudWatch alarm notifications

### 8.2 Test Alarms

Trigger a test alarm by causing errors:

```bash
# Send invalid request to trigger error
curl -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d 'invalid-json'
```

## Troubleshooting

### Issue: Terraform Apply Fails

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify backend configuration
terraform init -reconfigure

# Check for resource naming conflicts
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=Serverless-Event-Driven-App
```

### Issue: Lambda Function Fails

**Solution:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/task-manager-create-task-dev --follow

# Test Lambda function directly
aws lambda invoke \
  --function-name task-manager-create-task-dev \
  --payload '{"body":"{\"title\":\"Test\",\"userId\":\"user1\",\"priority\":\"low\"}"}' \
  response.json

cat response.json
```

### Issue: API Gateway Returns 403

**Solution:**
- Verify Lambda permissions for API Gateway
- Check API Gateway logs in CloudWatch
- Ensure CORS is configured correctly

### Issue: DynamoDB Access Denied

**Solution:**
- Verify Lambda execution role has DynamoDB permissions
- Check KMS key policy allows Lambda to decrypt

## Cost Monitoring

### View Current Costs

```bash
# Get cost estimate
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://cost-filter.json
```

### Set Up Budget Alerts

```bash
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Cleanup

### Remove All Resources

```bash
cd serverless/infra

# Destroy all Terraform-managed resources
terraform destroy \
  -var="aws_region=us-east-1" \
  -var="environment=dev"
```

Type `yes` when prompted.

**Warning:** This will permanently delete:
- All Lambda functions
- DynamoDB table and data
- API Gateway
- EventBridge rules
- Step Functions state machine
- CloudWatch logs and dashboards
- KMS keys (after 7-day waiting period)

## Next Steps

1. **Set up multiple environments** (dev, staging, prod)
   ```bash
   terraform workspace new staging
   terraform workspace new prod
   ```

2. **Add custom domain** for API Gateway
3. **Implement authentication** with Cognito or API Keys
4. **Add more event handlers** for custom workflows
5. **Create integration tests** with pytest
6. **Set up X-Ray tracing** for distributed tracing
7. **Implement API throttling** and request validation

## Support

For issues or questions:
- Check the [main README](../README.md)
- Review [AWS documentation](https://docs.aws.amazon.com/)
- Open a GitHub issue

---

**Deployment Complete!** 🎉

You now have a fully functional serverless event-driven application running on AWS with automated CI/CD.
