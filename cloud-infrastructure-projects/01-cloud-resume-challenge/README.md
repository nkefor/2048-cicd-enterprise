# Cloud Resume Challenge - Production-Grade Serverless Architecture

**Complete AWS Cloud Resume Challenge with serverless technologies, CI/CD automation, and infrastructure as code**

## 🎯 Project Overview

This project implements the **AWS Cloud Resume Challenge** - a hands-on project that demonstrates end-to-end cloud architecture skills by building a personal resume website using serverless technologies.

### What This Demonstrates

- ✅ **Serverless Architecture** - Lambda, API Gateway, DynamoDB
- ✅ **Static Website Hosting** - S3, CloudFront, Route 53
- ✅ **Infrastructure as Code** - Terraform for all AWS resources
- ✅ **CI/CD Automation** - GitHub Actions for continuous deployment
- ✅ **Frontend Development** - HTML, CSS, JavaScript
- ✅ **Backend API** - RESTful API with Lambda functions
- ✅ **Database Design** - DynamoDB for visitor tracking
- ✅ **Security** - HTTPS, IAM least privilege, encryption
- ✅ **Monitoring** - CloudWatch logs and metrics
- ✅ **Cost Optimization** - Serverless = pay only for usage

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Internet Users                                │
└────────────────┬────────────────────────────────────────────────────┘
                 │ HTTPS
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Route 53 (DNS)                                    │
│                  resume.yourdomain.com                               │
└────────────────┬────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                CloudFront Distribution                               │
│    • Global CDN (edge caching)                                       │
│    • SSL/TLS certificate (ACM)                                       │
│    • HTTPS redirect                                                  │
│    • Custom domain                                                   │
└────────────────┬────────────────────────────────────────────────────┘
                 │
    ┌────────────┴────────────────┬─────────────────────────────┐
    ▼                             ▼                              ▼
┌─────────────┐         ┌──────────────────┐         ┌──────────────────┐
│   S3 Bucket │         │   API Gateway    │         │   CloudWatch     │
│  (Static    │         │   (REST API)     │         │   (Monitoring)   │
│   Website)  │         │                  │         │                  │
│             │         │  GET /visitors   │         │  • Logs          │
│ • index.html│         │  POST /visitors  │         │  • Metrics       │
│ • style.css │         │                  │         │  • Alarms        │
│ • script.js │         └────────┬─────────┘         └──────────────────┘
│ • resume.pdf│                  │
└─────────────┘                  │
                                 ▼
                    ┌────────────────────────────┐
                    │   Lambda Function          │
                    │   (Python 3.11)            │
                    │                            │
                    │   visitor_counter.py       │
                    │   • Get current count      │
                    │   • Increment counter      │
                    │   • Return to frontend     │
                    └────────┬───────────────────┘
                             │
                             ▼
                    ┌────────────────────────────┐
                    │   DynamoDB Table           │
                    │                            │
                    │   visitor_count            │
                    │   • id (partition key)     │
                    │   • count (number)         │
                    │   • last_updated (string)  │
                    └────────────────────────────┘
```

### CI/CD Pipeline Flow

```
Developer Push → GitHub → GitHub Actions → Build & Test → Deploy
                                              │
                    ┌─────────────────────────┴──────────────────────┐
                    │                                                 │
                    ▼                                                 ▼
            Terraform Apply                                   Deploy Frontend
            • Lambda function                                 • Sync to S3
            • API Gateway                                     • Invalidate CloudFront
            • DynamoDB                                        • Update DNS
            • IAM roles
            └─────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
01-cloud-resume-challenge/
├── frontend/
│   ├── index.html              # Resume HTML
│   ├── css/
│   │   └── style.css           # Custom styling
│   ├── js/
│   │   └── script.js           # Visitor counter API call
│   └── assets/
│       ├── resume.pdf          # Downloadable resume
│       └── profile.jpg         # Profile picture
├── src/
│   └── lambda/
│       ├── visitor_counter.py  # Lambda function code
│       ├── requirements.txt    # Python dependencies
│       └── tests/
│           └── test_visitor_counter.py
├── terraform/
│   ├── main.tf                 # Main configuration
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── s3.tf                   # S3 bucket configuration
│   ├── cloudfront.tf           # CloudFront distribution
│   ├── lambda.tf               # Lambda function
│   ├── api_gateway.tf          # API Gateway
│   ├── dynamodb.tf             # DynamoDB table
│   ├── iam.tf                  # IAM roles and policies
│   └── route53.tf              # DNS configuration
├── .github/
│   └── workflows/
│       ├── deploy-frontend.yml # Frontend deployment
│       └── deploy-backend.yml  # Backend deployment
├── docs/
│   ├── SETUP.md               # Setup instructions
│   ├── DEPLOYMENT.md          # Deployment guide
│   └── ARCHITECTURE.md        # Architecture details
├── README.md
└── .gitignore
```

---

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform v1.5+
- Node.js 18+ (for local testing)
- Python 3.11+ (for Lambda development)
- AWS CLI configured
- Custom domain (optional but recommended)

### Step 1: Clone and Configure (5 minutes)

```bash
# Clone the repository
git clone https://github.com/yourusername/cloud-resume-challenge.git
cd cloud-resume-challenge/01-cloud-resume-challenge

# Configure AWS credentials
aws configure

# Set up Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 2: Deploy Infrastructure (10 minutes)

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy all AWS resources
terraform apply -auto-approve

# Note the outputs (CloudFront URL, API Gateway endpoint, etc.)
```

### Step 3: Deploy Frontend (2 minutes)

```bash
# Get S3 bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Sync frontend files to S3
cd ../frontend
aws s3 sync . s3://$BUCKET_NAME --delete

# Invalidate CloudFront cache
DISTRIBUTION_ID=$(cd ../terraform && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
```

### Step 4: Test Everything (3 minutes)

```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(cd ../terraform && terraform output -raw cloudfront_url)

# Open in browser
echo "Visit: https://$CLOUDFRONT_URL"

# Test API
API_URL=$(cd ../terraform && terraform output -raw api_gateway_url)
curl $API_URL/visitors
```

**Total Deployment Time**: ~20 minutes from zero to production! 🎉

---

## 💻 Frontend Code

### index.html

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>John Doe - Cloud Engineer</title>
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    <header>
        <div class="container">
            <div class="profile">
                <img src="assets/profile.jpg" alt="John Doe" class="profile-pic">
                <h1>John Doe</h1>
                <p class="title">Cloud Engineer | DevOps Specialist</p>
                <div class="social-links">
                    <a href="https://github.com/johndoe" target="_blank"><i class="fab fa-github"></i></a>
                    <a href="https://linkedin.com/in/johndoe" target="_blank"><i class="fab fa-linkedin"></i></a>
                    <a href="mailto:john@example.com"><i class="fas fa-envelope"></i></a>
                </div>
            </div>
        </div>
    </header>

    <main class="container">
        <!-- Visitor Counter -->
        <section class="visitor-counter">
            <p>
                <i class="fas fa-eye"></i>
                This resume has been viewed <span id="visitor-count">Loading...</span> times
            </p>
        </section>

        <!-- About Section -->
        <section class="about">
            <h2><i class="fas fa-user"></i> About Me</h2>
            <p>
                Experienced Cloud Engineer with 5+ years building scalable,
                secure infrastructure on AWS. Passionate about automation,
                DevOps practices, and continuous improvement.
            </p>
        </section>

        <!-- Experience Section -->
        <section class="experience">
            <h2><i class="fas fa-briefcase"></i> Experience</h2>

            <div class="job">
                <h3>Senior Cloud Engineer</h3>
                <p class="company">Tech Company Inc. | 2021 - Present</p>
                <ul>
                    <li>Designed and implemented serverless architectures saving $250K annually</li>
                    <li>Led migration of 50+ applications to Kubernetes, improving deployment speed by 70%</li>
                    <li>Implemented Infrastructure as Code with Terraform across 200+ resources</li>
                    <li>Built CI/CD pipelines reducing deployment time from hours to minutes</li>
                </ul>
            </div>

            <div class="job">
                <h3>DevOps Engineer</h3>
                <p class="company">Startup Co. | 2019 - 2021</p>
                <ul>
                    <li>Automated infrastructure provisioning with Ansible, managing 100+ servers</li>
                    <li>Implemented monitoring with Prometheus and Grafana</li>
                    <li>Reduced infrastructure costs by 40% through optimization</li>
                </ul>
            </div>
        </section>

        <!-- Skills Section -->
        <section class="skills">
            <h2><i class="fas fa-code"></i> Skills</h2>
            <div class="skill-grid">
                <div class="skill-category">
                    <h3>Cloud Platforms</h3>
                    <ul>
                        <li>AWS (Lambda, ECS, EC2, S3, CloudFront)</li>
                        <li>Azure</li>
                        <li>GCP</li>
                    </ul>
                </div>
                <div class="skill-category">
                    <h3>Infrastructure as Code</h3>
                    <ul>
                        <li>Terraform</li>
                        <li>CloudFormation</li>
                        <li>Pulumi</li>
                    </ul>
                </div>
                <div class="skill-category">
                    <h3>Containers & Orchestration</h3>
                    <ul>
                        <li>Docker</li>
                        <li>Kubernetes</li>
                        <li>ECS/Fargate</li>
                    </ul>
                </div>
                <div class="skill-category">
                    <h3>CI/CD & Automation</h3>
                    <ul>
                        <li>GitHub Actions</li>
                        <li>Jenkins</li>
                        <li>GitLab CI</li>
                    </ul>
                </div>
            </div>
        </section>

        <!-- Certifications -->
        <section class="certifications">
            <h2><i class="fas fa-certificate"></i> Certifications</h2>
            <ul>
                <li>AWS Certified Solutions Architect - Professional</li>
                <li>AWS Certified DevOps Engineer - Professional</li>
                <li>Certified Kubernetes Administrator (CKA)</li>
                <li>HashiCorp Certified: Terraform Associate</li>
            </ul>
        </section>

        <!-- Projects -->
        <section class="projects">
            <h2><i class="fas fa-project-diagram"></i> Featured Projects</h2>

            <div class="project">
                <h3>Cloud Resume Challenge</h3>
                <p>
                    Built this serverless resume website using AWS Lambda, API Gateway,
                    DynamoDB, S3, and CloudFront. Automated deployment with Terraform
                    and GitHub Actions.
                </p>
                <p class="tech-stack"><strong>Tech:</strong> AWS, Terraform, Python, JavaScript, GitHub Actions</p>
            </div>

            <div class="project">
                <h3>Microservices Monitoring Platform</h3>
                <p>
                    Deployed full observability stack with Prometheus, Grafana, and Jaeger
                    for monitoring 20+ microservices.
                </p>
                <p class="tech-stack"><strong>Tech:</strong> Kubernetes, Prometheus, Grafana, Jaeger</p>
            </div>
        </section>

        <!-- Download Resume -->
        <section class="download">
            <a href="assets/resume.pdf" class="btn" download>
                <i class="fas fa-download"></i> Download Resume (PDF)
            </a>
        </section>
    </main>

    <footer>
        <div class="container">
            <p>&copy; 2025 John Doe. Built with ❤️ using AWS Serverless</p>
            <p class="challenge-info">
                <a href="https://cloudresumechallenge.dev" target="_blank">
                    Part of the Cloud Resume Challenge
                </a>
            </p>
        </div>
    </footer>

    <script src="js/script.js"></script>
</body>
</html>
```

### js/script.js (Visitor Counter)

```javascript
// API Gateway endpoint (will be replaced by Terraform output)
const API_ENDPOINT = 'YOUR_API_GATEWAY_URL_HERE';

// Fetch and display visitor count
async function updateVisitorCount() {
    const countElement = document.getElementById('visitor-count');

    try {
        // Call API to get and increment visitor count
        const response = await fetch(`${API_ENDPOINT}/visitors`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            throw new Error('Network response was not ok');
        }

        const data = await response.json();

        // Animate counter
        animateCounter(countElement, 0, data.count, 1000);

    } catch (error) {
        console.error('Error fetching visitor count:', error);
        countElement.textContent = '---';
    }
}

// Animate counter with easing
function animateCounter(element, start, end, duration) {
    let startTimestamp = null;

    const step = (timestamp) => {
        if (!startTimestamp) startTimestamp = timestamp;
        const progress = Math.min((timestamp - startTimestamp) / duration, 1);

        const currentCount = Math.floor(progress * (end - start) + start);
        element.textContent = currentCount.toLocaleString();

        if (progress < 1) {
            window.requestAnimationFrame(step);
        }
    };

    window.requestAnimationFrame(step);
}

// Load visitor count when page loads
document.addEventListener('DOMContentLoaded', updateVisitorCount);
```

---

## 🔧 Backend Code

### src/lambda/visitor_counter.py

```python
import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function to track and return visitor count
    """

    # CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
    }

    # Handle OPTIONS request (CORS preflight)
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': ''
        }

    try:
        # Get current count
        response = table.get_item(Key={'id': 'visitor_count'})

        if 'Item' in response:
            current_count = int(response['Item']['count'])
        else:
            current_count = 0

        # Increment count
        new_count = current_count + 1

        # Update DynamoDB
        table.put_item(
            Item={
                'id': 'visitor_count',
                'count': new_count,
                'last_updated': datetime.utcnow().isoformat()
            }
        )

        # Return response
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'count': new_count,
                'last_updated': datetime.utcnow().isoformat()
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
```

### src/lambda/tests/test_visitor_counter.py

```python
import pytest
import json
from unittest.mock import MagicMock, patch
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from visitor_counter import lambda_handler

@patch('visitor_counter.table')
def test_visitor_counter_new(mock_table):
    """Test visitor counter with no existing count"""

    # Mock DynamoDB response (no existing item)
    mock_table.get_item.return_value = {}
    mock_table.put_item.return_value = {}

    # Create test event
    event = {
        'httpMethod': 'POST',
        'body': '{}'
    }

    # Call Lambda function
    response = lambda_handler(event, {})

    # Verify response
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] == 1

@patch('visitor_counter.table')
def test_visitor_counter_existing(mock_table):
    """Test visitor counter with existing count"""

    # Mock DynamoDB response (existing count)
    mock_table.get_item.return_value = {
        'Item': {'id': 'visitor_count', 'count': 42}
    }
    mock_table.put_item.return_value = {}

    # Create test event
    event = {
        'httpMethod': 'POST',
        'body': '{}'
    }

    # Call Lambda function
    response = lambda_handler(event, {})

    # Verify response
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] == 43

def test_cors_preflight():
    """Test CORS preflight OPTIONS request"""

    event = {
        'httpMethod': 'OPTIONS'
    }

    response = lambda_handler(event, {})

    assert response['statusCode'] == 200
    assert 'Access-Control-Allow-Origin' in response['headers']
```

---

## ☁️ Infrastructure as Code (Terraform)

### terraform/main.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloud-resume-terraform-state"
    key            = "resume/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Cloud-Resume-Challenge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
```

### terraform/variables.tf

```hcl
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cloud-resume"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Custom domain name for the resume website"
  type        = string
  default     = ""  # Leave empty if not using custom domain
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID (if using custom domain)"
  type        = string
  default     = ""
}
```

---

## 🔄 CI/CD Pipeline

### .github/workflows/deploy-frontend.yml

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]
    paths:
      - 'frontend/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Sync files to S3
        run: |
          aws s3 sync frontend/ s3://${{ secrets.S3_BUCKET_NAME }} \
            --delete \
            --cache-control "public, max-age=31536000" \
            --exclude "*.html" \
            --exclude "*.json"

          # HTML files with shorter cache
          aws s3 sync frontend/ s3://${{ secrets.S3_BUCKET_NAME }} \
            --exclude "*" \
            --include "*.html" \
            --cache-control "public, max-age=300"

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"

      - name: Notify deployment
        run: |
          echo "✅ Frontend deployed successfully!"
          echo "Visit: https://${{ secrets.CLOUDFRONT_URL }}"
```

---

## 📊 Monitoring & Costs

### CloudWatch Dashboards

- **Lambda Invocations**: Track API calls
- **Error Rates**: Monitor failures
- **Latency**: P50, P95, P99 response times
- **Visitor Trends**: Daily/weekly/monthly views

### Monthly Cost Estimate

| Service | Usage | Cost |
|---------|-------|------|
| **CloudFront** | 10K requests/month | ~$0.10 |
| **S3** | 1 GB storage + requests | ~$0.05 |
| **Lambda** | 10K invocations | ~$0.00 (free tier) |
| **API Gateway** | 10K requests | ~$0.04 |
| **DynamoDB** | On-demand, low traffic | ~$0.01 |
| **Route 53** | 1 hosted zone (optional) | ~$0.50 |
| **ACM Certificate** | Free | $0.00 |
| **Total** | | **~$0.70/month** |

*Scales automatically with traffic. Free tier covers most usage for personal resume.*

---

## 🎓 Skills Demonstrated

### Cloud Architecture
- ✅ Serverless design patterns
- ✅ Content delivery networks (CDN)
- ✅ API design and implementation
- ✅ Database selection and optimization
- ✅ Security best practices

### DevOps & Automation
- ✅ Infrastructure as Code (Terraform)
- ✅ CI/CD pipeline design
- ✅ Git workflow
- ✅ Automated testing
- ✅ Deployment automation

### Development
- ✅ Frontend development (HTML/CSS/JS)
- ✅ Backend development (Python)
- ✅ RESTful API design
- ✅ Responsive web design
- ✅ Version control (Git)

---

## 🚀 Deployment

**Total Time**: ~20 minutes
**Cost**: ~$0.70/month
**Uptime**: 99.99%+ (CloudFront SLA)
**Global Performance**: <100ms latency worldwide

---

**Project Status**: ✅ Production-Ready
**Last Updated**: 2025-11-18
**Version**: 1.0.0
