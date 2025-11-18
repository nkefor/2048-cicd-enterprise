# Deployment Checklist ✅

Use this checklist to track your deployment progress.

## Pre-Deployment Setup

### AWS Account Setup
- [ ] AWS account created
- [ ] AWS CLI installed and configured
- [ ] Admin IAM user or role created
- [ ] MFA enabled (recommended)

### Local Tools
- [ ] Terraform installed (v1.7.0+)
- [ ] Python 3.12+ installed
- [ ] Git installed
- [ ] Code editor installed (VS Code recommended)

---

## Infrastructure Preparation

### S3 Backend for Terraform
- [ ] S3 bucket created for Terraform state
  - Bucket name: `____________________________`
- [ ] Versioning enabled on bucket
- [ ] Encryption enabled on bucket

### DynamoDB State Locking
- [ ] DynamoDB table created (`terraform-locks`)
- [ ] Table configured with `LockID` hash key
- [ ] Billing mode set to `PAY_PER_REQUEST`

### GitHub Setup (for CI/CD)
- [ ] Repository forked/cloned
- [ ] GitHub Actions enabled
- [ ] OIDC provider configured in AWS (optional)
- [ ] IAM role created for GitHub Actions (optional)

---

## Deployment Steps

### 1. Lambda Function Packaging
- [ ] Navigated to `serverless/` directory
- [ ] Made `package-lambdas.sh` executable
- [ ] Ran packaging script successfully
- [ ] Verified `.zip` files created in Lambda directories

### 2. Terraform Initialization
- [ ] Navigated to `serverless/infra/` directory
- [ ] Updated `backend-config` with S3 bucket name
- [ ] Ran `terraform init` successfully
- [ ] Backend initialized without errors

### 3. Infrastructure Deployment
- [ ] Reviewed `variables.tf` for configuration options
- [ ] Ran `terraform plan` to preview changes
- [ ] Reviewed plan output (expected ~40+ resources)
- [ ] Ran `terraform apply` successfully
- [ ] Deployment completed (~5-10 minutes)

### 4. Verify Deployment
- [ ] Retrieved API Gateway URL from outputs
- [ ] API URL saved: `____________________________`
- [ ] Lambda functions visible in AWS Console
- [ ] DynamoDB table created
- [ ] EventBridge bus created
- [ ] Step Functions state machine created

---

## Testing & Validation

### API Testing
- [ ] Ran automated test script (`test-api.sh`)
- [ ] All 10 tests passed
- [ ] Created test task via API
- [ ] Retrieved task by ID
- [ ] Updated task status
- [ ] Listed tasks with filters
- [ ] Deleted task successfully

### Event-Driven Workflows
- [ ] Created high-priority task
- [ ] Step Functions execution triggered
- [ ] EventBridge events published
- [ ] Event handler Lambdas executed
- [ ] CloudWatch metrics updated

### Monitoring Setup
- [ ] CloudWatch dashboard visible
- [ ] All metrics populating
- [ ] Alarms configured (8 total)
- [ ] SNS topic created (if email provided)
- [ ] Email subscription confirmed (if applicable)

---

## GitHub Actions CI/CD (Optional)

### GitHub Secrets Configuration
- [ ] `AWS_REGION` secret added
- [ ] `AWS_ROLE_ARN` secret added
- [ ] `TERRAFORM_STATE_BUCKET` secret added

### Workflow Validation
- [ ] Workflow file syntax validated
- [ ] Security scanning job runs
- [ ] Terraform validation job runs
- [ ] Lambda packaging job runs
- [ ] Deployment job runs successfully

### Dependabot Setup
- [ ] `dependabot.yml` file in `.github/`
- [ ] Dependabot enabled for repository
- [ ] Weekly schedule configured

---

## Post-Deployment

### Documentation
- [ ] API URL documented
- [ ] DynamoDB table name recorded
- [ ] CloudWatch dashboard URL bookmarked
- [ ] Step Functions ARN saved

### Security Review
- [ ] IAM roles follow least-privilege principle
- [ ] KMS encryption enabled for DynamoDB
- [ ] CloudWatch logs encrypted
- [ ] API Gateway CORS configured correctly
- [ ] Lambda environment variables secure

### Cost Management
- [ ] Cost allocation tags applied
- [ ] Budget alerts configured (optional)
- [ ] CloudWatch log retention set to 30 days
- [ ] DynamoDB TTL configured for auto-cleanup

### Monitoring Setup
- [ ] CloudWatch dashboard reviewed
- [ ] Alarm thresholds appropriate
- [ ] SNS notifications working
- [ ] Log groups created for all Lambdas
- [ ] X-Ray tracing enabled (optional)

---

## Testing Scenarios

### Basic CRUD Operations
- [ ] ✅ Create task with all fields
- [ ] ✅ Create task with minimal fields
- [ ] ✅ Get task by valid ID
- [ ] ✅ Get task with invalid ID (404)
- [ ] ✅ Update task status
- [ ] ✅ Update task priority
- [ ] ✅ Delete existing task
- [ ] ✅ List all tasks
- [ ] ✅ List tasks filtered by status
- [ ] ✅ List tasks filtered by userId

### Event-Driven Workflows
- [ ] ✅ TaskCreated event published
- [ ] ✅ TaskUpdated event published
- [ ] ✅ TaskCompleted event published
- [ ] ✅ High-priority task triggers Step Functions
- [ ] ✅ Event handlers process events correctly

### Error Handling
- [ ] ✅ Invalid JSON returns 400
- [ ] ✅ Missing required field returns 400
- [ ] ✅ Non-existent task returns 404
- [ ] ✅ Lambda errors logged to CloudWatch
- [ ] ✅ API Gateway errors handled gracefully

---

## Performance & Scale Testing (Optional)

### Load Testing
- [ ] API tested with 100 concurrent requests
- [ ] Lambda cold start times measured
- [ ] DynamoDB read/write capacity monitored
- [ ] API Gateway throttling tested
- [ ] CloudWatch alarms triggered appropriately

### Optimization
- [ ] Lambda memory sizes right-sized
- [ ] DynamoDB indexes optimized
- [ ] CloudWatch log retention optimized
- [ ] Dead letter queues configured (optional)

---

## Production Readiness (Optional)

### Multi-Environment Setup
- [ ] Dev environment deployed
- [ ] Staging environment deployed (optional)
- [ ] Production environment deployed (optional)
- [ ] Environment-specific variables configured

### Advanced Features
- [ ] Custom domain configured
- [ ] SSL certificate provisioned
- [ ] API authentication enabled
- [ ] Rate limiting configured
- [ ] WAF rules configured (optional)

### Disaster Recovery
- [ ] DynamoDB point-in-time recovery enabled
- [ ] Backup retention policy defined
- [ ] Recovery procedures documented
- [ ] Restore tested (recommended)

### Compliance & Security
- [ ] Security audit completed
- [ ] Compliance requirements reviewed
- [ ] Data retention policies defined
- [ ] Access logs enabled
- [ ] Encryption verified end-to-end

---

## Cleanup (When Done)

### Resource Cleanup
- [ ] Ran `terraform destroy`
- [ ] Verified all resources deleted
- [ ] S3 state bucket emptied
- [ ] S3 state bucket deleted
- [ ] DynamoDB locks table deleted
- [ ] CloudWatch log groups deleted (if desired)

### Cost Verification
- [ ] Final AWS bill reviewed
- [ ] No unexpected charges
- [ ] All resources confirmed deleted

---

## Resources & Documentation

### Key Files
- [ ] `QUICKSTART.md` - Fast deployment guide
- [ ] `DEPLOYMENT-GUIDE.md` - Detailed instructions
- [ ] `README.md` - Architecture overview
- [ ] `PROJECT-SUMMARY.md` - Technical summary

### AWS Console URLs
- CloudWatch Dashboard: `____________________________`
- Lambda Functions: `https://console.aws.amazon.com/lambda`
- DynamoDB Tables: `https://console.aws.amazon.com/dynamodb`
- Step Functions: `https://console.aws.amazon.com/states`
- API Gateway: `https://console.aws.amazon.com/apigateway`

### Useful Commands
```bash
# Get API URL
terraform output -raw api_gateway_url

# View logs
aws logs tail /aws/lambda/task-manager-create-task-dev --follow

# List all resources
terraform state list

# Show specific resource
terraform state show aws_lambda_function.create_task
```

---

## Notes & Issues

**Deployment Date**: `____________________`

**Issues Encountered**:
-
-
-

**Resolutions**:
-
-
-

**Custom Configurations**:
-
-
-

---

## Success Criteria ✅

Your deployment is successful when:

- ✅ All Terraform resources created without errors
- ✅ API Gateway URL accessible
- ✅ All API endpoints return valid responses
- ✅ Lambda functions execute successfully
- ✅ DynamoDB table contains test data
- ✅ EventBridge events trigger handlers
- ✅ Step Functions workflow executes
- ✅ CloudWatch dashboard shows metrics
- ✅ All alarms configured and active
- ✅ No critical errors in CloudWatch logs

**Total Monthly Cost**: ~$7-10 (expected)

---

**Deployment Status**: [ ] Not Started | [ ] In Progress | [ ] Complete ✅

**Last Updated**: `____________________`
