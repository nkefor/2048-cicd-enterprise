# Serverless Event-Driven Application

A production-ready serverless task management system built with AWS Lambda, API Gateway, EventBridge, DynamoDB, and Step Functions — featuring automated CI/CD with security scanning and comprehensive monitoring.

## 🎯 Project Overview

This serverless application demonstrates enterprise-grade cloud-native architecture using:

- **AWS Lambda** - Serverless compute for API and event processing
- **API Gateway** - HTTP API for RESTful endpoints
- **DynamoDB** - NoSQL database with encryption at rest
- **EventBridge** - Event-driven workflow orchestration
- **Step Functions** - Complex workflow automation (task approval)
- **CloudWatch** - Monitoring, logging, and alerting
- **KMS** - Data encryption and key management
- **Terraform** - Infrastructure as Code
- **GitHub Actions** - CI/CD automation with Trivy security scanning

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          GitHub Actions                         │
│   (CI/CD Pipeline with Trivy Security Scanning)               │
└────────────────┬────────────────────────────────────────────────┘
                 │ Deploy
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              API Gateway (HTTP API)                      │  │
│  │         /tasks (GET, POST, PUT, DELETE)                  │  │
│  └────────────────┬────────────────────────────────────────┘  │
│                   │                                             │
│                   ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  Lambda Functions                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│  │
│  │  │ Create   │  │ Get      │  │ Update   │  │ Delete  ││  │
│  │  │ Task     │  │ Task     │  │ Task     │  │ Task    ││  │
│  │  └─────┬────┘  └──────────┘  └────┬─────┘  └─────────┘│  │
│  └────────┼─────────────────────────┼────────────────────┘  │
│           │                         │ Emit Events             │
│           │                         ▼                          │
│           │           ┌─────────────────────────────┐         │
│           │           │    EventBridge Event Bus    │         │
│           │           │  (Custom Event Routing)     │         │
│           │           └─┬──────────┬────────────┬──┘         │
│           │             │          │            │             │
│           │             ▼          ▼            ▼             │
│           │      ┌──────────┐ ┌─────────┐ ┌─────────┐       │
│           │      │Task      │ │Task     │ │Task     │       │
│           │      │Created   │ │Updated  │ │Completed│       │
│           │      │Handler   │ │Handler  │ │Handler  │       │
│           │      └────┬─────┘ └─────────┘ └─────────┘       │
│           │           │                                       │
│           │           │ High Priority?                        │
│           │           ▼                                       │
│           │    ┌────────────────────────┐                   │
│           │    │   Step Functions       │                   │
│           │    │ (Task Approval Flow)   │                   │
│           │    └────────────────────────┘                   │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    DynamoDB                          │   │
│  │         (Tasks Table + GSI Indexes)                  │   │
│  │    Encrypted with KMS, Point-in-Time Recovery       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              CloudWatch Monitoring                   │   │
│  │   Dashboards | Metrics | Logs | Alarms              │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
serverless/
├── lambda/                      # Lambda function code
│   ├── api/                     # API endpoint handlers
│   │   ├── create-task/        # POST /tasks
│   │   ├── get-task/           # GET /tasks/{taskId}
│   │   ├── update-task/        # PUT /tasks/{taskId}
│   │   ├── delete-task/        # DELETE /tasks/{taskId}
│   │   └── list-tasks/         # GET /tasks
│   ├── events/                  # Event-driven handlers
│   │   ├── task-created/       # TaskCreated event handler
│   │   ├── task-updated/       # TaskUpdated event handler
│   │   └── task-completed/     # TaskCompleted event handler
│   └── requirements.txt         # Python dependencies
├── infra/                       # Terraform infrastructure
│   ├── main.tf                  # Provider and backend config
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── kms.tf                   # KMS encryption keys
│   ├── dynamodb.tf              # DynamoDB table
│   ├── lambda.tf                # Lambda functions
│   ├── api-gateway.tf           # API Gateway config
│   ├── eventbridge.tf           # EventBridge rules
│   ├── stepfunctions.tf         # Step Functions state machine
│   ├── iam.tf                   # IAM roles and policies
│   └── cloudwatch.tf            # Monitoring and alarms
├── scripts/                     # Deployment scripts
│   └── package-lambdas.sh      # Lambda packaging script
├── tests/                       # Unit and integration tests
└── docs/                        # Additional documentation
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- Python >= 3.12
- AWS CLI configured
- GitHub repository with required secrets

### Required GitHub Secrets

Configure these secrets in your GitHub repository:

```bash
AWS_REGION              # e.g., us-east-1
AWS_ROLE_ARN            # IAM role ARN for GitHub Actions OIDC
TERRAFORM_STATE_BUCKET  # S3 bucket for Terraform state
```

### Deployment Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd 2048-cicd-enterprise/serverless
   ```

2. **Package Lambda functions**
   ```bash
   chmod +x scripts/package-lambdas.sh
   ./scripts/package-lambdas.sh
   ```

3. **Deploy infrastructure with Terraform**
   ```bash
   cd infra
   terraform init \
     -backend-config="bucket=YOUR_BUCKET" \
     -backend-config="region=us-east-1"

   terraform plan -var="aws_region=us-east-1" -var="environment=dev"
   terraform apply -var="aws_region=us-east-1" -var="environment=dev"
   ```

4. **Get the API Gateway URL**
   ```bash
   terraform output api_gateway_url
   ```

## 📡 API Endpoints

### Create Task
```bash
POST /tasks
Content-Type: application/json

{
  "title": "Complete project documentation",
  "description": "Write comprehensive README and deployment guide",
  "priority": "high",
  "userId": "user123",
  "tags": ["documentation", "urgent"]
}
```

### Get Task
```bash
GET /tasks/{taskId}
```

### Update Task
```bash
PUT /tasks/{taskId}
Content-Type: application/json

{
  "status": "in_progress",
  "priority": "high"
}
```

### Delete Task
```bash
DELETE /tasks/{taskId}
```

### List Tasks
```bash
GET /tasks?status=pending&limit=20
GET /tasks?userId=user123&limit=50
```

## 🔄 Event-Driven Workflows

### Event Flow

1. **Task Created** → Publishes `TaskCreated` event to EventBridge
   - High-priority tasks trigger Step Functions approval workflow
   - Logs creation for analytics
   - Sends notifications

2. **Task Updated** → Publishes `TaskUpdated` event
   - Tracks status changes
   - Publishes CloudWatch metrics
   - Sends status notifications

3. **Task Completed** → Publishes `TaskCompleted` event
   - Calculates completion metrics
   - Updates user statistics
   - Archives completed tasks

### Step Functions Workflow

High-priority tasks trigger an approval workflow:

```
Start → Validate Task → Check Priority → Wait for Approval
  → Auto/Manual Approval → Process Task → Complete
```

## 🔒 Security Features

- **Encryption at Rest**: KMS encryption for DynamoDB and CloudWatch Logs
- **Encryption in Transit**: HTTPS for all API calls
- **IAM Least Privilege**: Minimal permissions for Lambda execution roles
- **Dependency Scanning**: Trivy scans for vulnerabilities in CI/CD
- **Automated Updates**: Dependabot for dependency management
- **CORS Configuration**: Configurable CORS policies for API Gateway

## 📊 Monitoring & Observability

### CloudWatch Dashboard

Includes metrics for:
- Lambda invocations, errors, duration, throttles
- DynamoDB read/write capacity, errors
- API Gateway request count, latency, errors
- Step Functions executions

### CloudWatch Alarms

Pre-configured alarms for:
- Lambda error rate > 10 errors
- Lambda throttles > 5
- DynamoDB throttle events
- API Gateway 5XX errors > 10
- API Gateway latency > 2000ms
- Step Functions execution failures

### X-Ray Tracing

Optional distributed tracing for:
- End-to-end request tracking
- Performance bottleneck identification
- Service map visualization

## 💰 Cost Optimization

### Monthly Cost Estimate (Low Traffic)

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| Lambda | 1M requests, 256MB, 200ms avg | ~$0.20 |
| API Gateway | 1M requests | ~$1.00 |
| DynamoDB | 1GB storage, on-demand | ~$0.25 |
| EventBridge | 1M events | ~$1.00 |
| Step Functions | 10K executions | ~$0.25 |
| CloudWatch | Logs + Metrics | ~$5.00 |
| **Total** | | **~$7.70/month** |

### Cost Optimization Tips

1. **Use DynamoDB On-Demand** for unpredictable workloads
2. **Enable Lambda SnapStart** for faster cold starts (Python 3.12)
3. **Set CloudWatch log retention** to 30 days (configurable)
4. **Use DynamoDB TTL** to auto-delete old tasks
5. **Right-size Lambda memory** based on actual usage

## 🔧 Configuration

### Terraform Variables

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "dev"
}

variable "lambda_memory_size" {
  default = 256  # MB
}

variable "cloudwatch_retention_days" {
  default = 30
}

variable "alarm_email" {
  default = ""  # Email for CloudWatch alarms
}
```

## 🧪 Testing

### Unit Tests
```bash
cd serverless
pip install pytest pytest-cov moto
pytest tests/ --cov=lambda
```

### Integration Tests
```bash
# Export API Gateway URL
export API_URL=$(cd infra && terraform output -raw api_gateway_url)

# Test API endpoints
curl -X POST $API_URL/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task","userId":"test123","priority":"medium"}'
```

### Load Testing
```bash
# Using Apache Bench
ab -n 1000 -c 10 $API_URL/tasks
```

## 🎓 What You'll Learn

- ✅ Building serverless APIs with Lambda and API Gateway
- ✅ Event-driven architecture with EventBridge
- ✅ Workflow orchestration with Step Functions
- ✅ NoSQL database design with DynamoDB
- ✅ Infrastructure as Code with Terraform
- ✅ CI/CD automation with GitHub Actions
- ✅ Security scanning with Trivy
- ✅ Monitoring and alerting with CloudWatch
- ✅ Encryption with KMS
- ✅ Cost optimization strategies

## 📝 Best Practices Implemented

1. **Infrastructure as Code** - All resources defined in Terraform
2. **Immutable Deployments** - Lambda versioning and aliases
3. **Observability** - Comprehensive logging and metrics
4. **Security** - Encryption, least privilege IAM, vulnerability scanning
5. **Automation** - Fully automated CI/CD pipeline
6. **Cost Optimization** - Serverless pay-per-use model
7. **Scalability** - Auto-scaling for all components
8. **High Availability** - Multi-AZ deployment

## 🔗 Resources

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## 📄 License

MIT License - See LICENSE file for details

---

**Built with ❤️ using AWS Serverless Technologies**

**Perfect for**: Cloud Engineers, DevOps Engineers, Backend Developers, Solutions Architects

**Skills Demonstrated**: Serverless Architecture, Event-Driven Design, Infrastructure as Code, CI/CD, Security Best Practices
