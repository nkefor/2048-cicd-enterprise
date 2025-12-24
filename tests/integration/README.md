# AWS Integration Tests

This directory contains integration tests that validate AWS service configurations and connectivity.

## Overview

These tests verify that AWS resources are properly configured and accessible:
- **ECR** - Container registry configuration and access
- **ECS** - Cluster, service, and task definition validation
- **ALB** - Load balancer, target groups, and health checks
- **CloudWatch Logs** - Log groups, streams, and log retention

## Prerequisites

### AWS Credentials

Tests require AWS credentials to be configured. They will automatically skip if credentials are not available.

**Configure credentials using one of these methods:**

1. **Environment variables:**
   ```bash
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_REGION=us-east-1
   ```

2. **AWS Profile:**
   ```bash
   export AWS_PROFILE=your_profile_name
   export AWS_REGION=us-east-1
   ```

3. **IAM Role (for CI/CD):**
   - GitHub Actions uses OIDC authentication
   - No static credentials needed in CI/CD pipeline

### Required IAM Permissions

The test user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecs:ListClusters",
        "ecs:DescribeClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeListeners",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

## Running Tests

### Run all integration tests:
```bash
npm run test:integration
```

### Run specific test file:
```bash
npx jest tests/integration/aws-ecr.test.js
npx jest tests/integration/aws-ecs.test.js
npx jest tests/integration/aws-alb.test.js
npx jest tests/integration/aws-cloudwatch.test.js
```

### Run with verbose output:
```bash
npx jest tests/integration --verbose
```

## Test Files

### 1. `aws-ecr.test.js`
Tests Amazon Elastic Container Registry configuration.

**Validates:**
- ECR connectivity and authentication
- Repository existence and configuration
- Image scanning settings
- Encryption configuration
- IAM permissions

**Usage:**
```bash
npx jest tests/integration/aws-ecr.test.js
```

### 2. `aws-ecs.test.js`
Tests Amazon ECS cluster, service, and task configuration.

**Validates:**
- Cluster existence and status
- Service configuration (desired/running tasks)
- Load balancer association
- Task definition configuration
- Container health checks
- Deployment configuration
- IAM permissions

**Usage:**
```bash
npx jest tests/integration/aws-ecs.test.js
```

### 3. `aws-alb.test.js`
Tests Application Load Balancer configuration.

**Validates:**
- ALB existence and state
- Target group configuration
- Target health status
- Listener configuration (HTTP/HTTPS)
- SSL/TLS certificates
- Security group configuration
- IAM permissions

**Usage:**
```bash
npx jest tests/integration/aws-alb.test.js
```

### 4. `aws-cloudwatch.test.js`
Tests CloudWatch Logs configuration.

**Validates:**
- Log group existence
- Log retention policies
- Log stream existence and recency
- Recent log events
- IAM permissions

**Usage:**
```bash
npx jest tests/integration/aws-cloudwatch.test.js
```

## Test Behavior

### When Infrastructure Exists
Tests will validate all configurations and report:
- ✅ Configuration details
- ⚠️  Warnings for missing best practices
- ❌ Errors for misconfigurations

### When Infrastructure Doesn't Exist
Tests will gracefully skip with informational messages:
```
⚠️  Skipping AWS tests - AWS credentials not configured
⚠️  Infrastructure not deployed yet
```

This allows tests to pass in environments where infrastructure hasn't been deployed yet.

## CI/CD Integration

Add to `.github/workflows/test.yaml`:

```yaml
integration-tests:
  name: AWS Integration Tests
  runs-on: ubuntu-latest
  permissions:
    contents: read
    id-token: write

  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Run AWS integration tests
      run: npm run test:integration
      env:
        AWS_REGION: ${{ secrets.AWS_REGION }}
```

## Example Output

### Successful Test Run:
```
AWS ECR Integration Tests
  ✓ should be able to connect to ECR (245ms)
  ✓ should find ECR repositories (189ms)
    Found ECR repositories: game-2048
  ✓ should validate game-2048 repository if it exists (198ms)
    Repository 'game-2048' found
    - Image scanning: enabled
    - Encryption: AES256

AWS ECS Integration Tests
  ✓ should validate game-2048 cluster if it exists (234ms)
    Cluster 'game-2048' found:
    - Status: ACTIVE
    - Running tasks: 2
    - Pending tasks: 0
```

### When Infrastructure Not Deployed:
```
AWS ECR Integration Tests
  ✓ should be able to connect to ECR (198ms)
  ○ skipped Repository '${repoName}' not found - infrastructure may not be deployed yet
```

## Troubleshooting

### Issue: "AWS credentials not configured"

**Solution:**
```bash
# Set environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_REGION=us-east-1

# Or use AWS CLI to configure
aws configure
```

### Issue: "AccessDeniedException"

**Solution:**
- Check IAM permissions listed above
- Verify your user/role has required permissions
- Check if MFA is required for your account

### Issue: "ResourceNotFoundException"

**Cause:** Infrastructure not deployed yet

**Solution:**
- This is expected if infrastructure doesn't exist
- Tests will pass with informational messages
- Deploy infrastructure using Terraform or AWS Console

### Issue: Tests timeout

**Solution:**
```bash
# Increase Jest timeout
npx jest tests/integration --testTimeout=60000
```

## Best Practices

1. **Run locally before pushing** - Catch issues early
2. **Check test output** - Even passing tests provide useful info
3. **Monitor AWS costs** - Tests make API calls (usually free tier eligible)
4. **Use least-privilege IAM** - Only grant permissions needed for tests
5. **Run in CI/CD** - Automate validation on every deployment

## Security Considerations

- **Never commit AWS credentials** - Use environment variables or IAM roles
- **Use OIDC for GitHub Actions** - No static credentials needed
- **Limit test permissions** - Read-only access is sufficient
- **Rotate credentials regularly** - Follow AWS security best practices
- **Enable MFA** - For production account access

## Additional Resources

- [AWS SDK for JavaScript v3](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/)
- [Jest Testing Framework](https://jestjs.io/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
