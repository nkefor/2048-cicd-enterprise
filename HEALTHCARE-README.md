# Enterprise Healthcare DevOps Platform
## HIPAA/HITRUST/NIST 800-53 Compliant AWS Serverless Architecture

---

## 🏥 Overview

This platform delivers a **production-ready, HIPAA-compliant healthcare DevOps solution** on AWS serverless infrastructure with comprehensive security controls, AI-driven clinical data extraction, and automated workflow orchestration.

### Key Features

- ✅ **HIPAA/HITRUST/NIST 800-53 Compliant**: Full compliance framework implementation
- ✅ **Zero-Trust Security**: AWS Verified Access with continuous device verification
- ✅ **AI-Powered**: Amazon Comprehend Medical for clinical entity extraction
- ✅ **Workflow Orchestration**: AWS Step Functions for patient intake → lab → billing
- ✅ **Complete Security Stack**: WAF, GuardDuty, Security Hub, Macie, Config, Inspector
- ✅ **Audit & Compliance**: CloudTrail, 6-year audit log retention, automated compliance checks
- ✅ **Encryption Everywhere**: KMS encryption at rest and TLS 1.3 in transit
- ✅ **Service Control Policies**: Organizational compliance boundaries

---

## 📋 Table of Contents

1. [Architecture](#architecture)
2. [Security & Compliance](#security--compliance)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Detailed Documentation](#detailed-documentation)
6. [Cost Analysis](#cost-analysis)
7. [Compliance Certifications](#compliance-certifications)
8. [Support](#support)

---

## 🏗 Architecture

### High-Level Architecture

The platform consists of 7 layers:

1. **Security & Compliance Layer**: Security Hub, GuardDuty, CloudTrail, Config, Macie, Inspector
2. **Identity & Access Layer**: Cognito, Verified Access, IAM (RBAC/ABAC), SCPs
3. **Network Security Layer**: WAF, CloudFront, Shield, VPC with endpoints
4. **Application Layer**: API Gateway, Lambda, Step Functions
5. **AI/ML Layer**: Amazon Comprehend Medical
6. **Data Layer**: DynamoDB, S3 (encrypted with KMS)
7. **Monitoring Layer**: CloudWatch, EventBridge, SNS/SQS

### Healthcare Workflow Example

```
Patient Intake → Insurance Eligibility → Lab Scheduling →
Lab Results → AI Entity Extraction → Billing Generation →
Claims Submission → Patient Record Update
```

**Full architecture diagram**: See [HEALTHCARE-DEVOPS-ARCHITECTURE.md](HEALTHCARE-DEVOPS-ARCHITECTURE.md)

---

## 🔒 Security & Compliance

### HIPAA Compliance

| Requirement | Implementation |
|-------------|----------------|
| **Access Control (§164.312(a))** | Cognito MFA, IAM roles, Verified Access |
| **Audit Controls (§164.312(b))** | CloudTrail (6-year retention), CloudWatch Logs |
| **Integrity (§164.312(c))** | WAF, digital signatures, versioning |
| **Person Authentication (§164.312(d))** | Cognito with MFA, device tracking |
| **Transmission Security (§164.312(e))** | TLS 1.3, KMS encryption |

### Security Services Enabled

- ✅ **AWS WAF**: OWASP Top 10, rate limiting, geo-blocking
- ✅ **Amazon GuardDuty**: Threat detection (VPC, CloudTrail, DNS)
- ✅ **AWS Security Hub**: Centralized security findings (HIPAA, NIST, CIS)
- ✅ **AWS Config**: Continuous compliance monitoring
- ✅ **Amazon Macie**: PHI discovery and data privacy
- ✅ **Amazon Inspector**: Vulnerability scanning (Lambda, ECR)
- ✅ **AWS CloudTrail**: Audit logging with log file validation
- ✅ **AWS KMS**: FIPS 140-2 Level 3 encryption keys

### Service Control Policies (SCPs)

8 organizational SCPs enforce compliance:

1. **Require Encryption in Transit**: Deny non-HTTPS requests
2. **Require Encryption at Rest**: Enforce KMS encryption for all data stores
3. **Restrict Regions**: Limit operations to approved regions (data residency)
4. **Prevent Public S3 Buckets**: Block public access to all S3 buckets
5. **Require MFA**: Enforce MFA for sensitive operations
6. **Require CloudTrail**: Prevent disabling audit logging
7. **Require VPC Endpoints**: Enforce private connectivity to AWS services
8. **Protect Security Controls**: Prevent disabling security services

---

## 📚 Prerequisites

### Required Tools

```bash
- AWS CLI v2.x
- Terraform >= 1.5.0
- Python >= 3.11
- Docker (for local Lambda development)
- jq (for JSON processing)
```

### AWS Account Requirements

- AWS account with Administrator access (for initial setup)
- AWS Organizations configured (optional, for SCPs)
- Business Associate Agreement (BAA) signed with AWS
- Domain name (for API Gateway custom domain)

### Required AWS Service Quotas

- Lambda concurrent executions: 1000+
- API Gateway requests: 10,000/second
- Step Functions executions: 1,000/second
- DynamoDB: On-demand mode or provisioned capacity

---

## 🚀 Quick Start

### Step 1: Clone Repository

```bash
git clone https://github.com/nkefor/2048-cicd-enterprise.git
cd 2048-cicd-enterprise
```

### Step 2: Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Update with your values
```

**Required variables**:
- `domain_name`: Your domain (e.g., healthcare.example.com)
- `security_alert_email`: Email for security alerts
- `compliance_alert_email`: Email for compliance alerts
- `operational_alert_email`: Email for operational alerts

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review Plan

```bash
terraform plan -out=tfplan
```

### Step 5: Deploy Infrastructure

```bash
terraform apply tfplan
```

**Deployment time**: ~20-30 minutes

### Step 6: Configure Cognito Users

```bash
# Create admin user
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com \
  --temporary-password "TempPassword123!" \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username admin@example.com \
  --password "YourSecurePassword123!" \
  --permanent
```

### Step 7: Test API Endpoint

```bash
# Get API endpoint
API_URL=$(terraform output -raw api_gateway_url)

# Authenticate and get JWT token
# (Use your Cognito credentials)

# Test patient intake API
curl -X POST $API_URL/patients \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "patientId": "P12345",
    "personalInfo": {
      "firstName": "John",
      "lastName": "Doe",
      "dob": "1980-01-01"
    },
    "insurance": {
      "provider": "Blue Cross",
      "policyId": "BC123456"
    },
    "requestedTests": ["Blood Test", "X-Ray"]
  }'
```

---

## 📖 Detailed Documentation

### Core Documentation

- **[HEALTHCARE-DEVOPS-ARCHITECTURE.md](HEALTHCARE-DEVOPS-ARCHITECTURE.md)**: Complete architecture guide
  - Security components
  - Compliance framework
  - Workflow orchestration
  - AI/ML integration
  - Deployment architecture

### Infrastructure Documentation

- **[infra/README.md](infra/README.md)**: Terraform infrastructure guide
- **[infra/modules/security/README.md](infra/modules/security/README.md)**: Security module details
- **[infra/modules/compute/README.md](infra/modules/compute/README.md)**: Compute & Step Functions
- **[infra/modules/monitoring/README.md](infra/modules/monitoring/README.md)**: Monitoring & compliance

### Workflow Documentation

- **Healthcare Workflows**:
  - Patient Intake → Lab → Billing
  - Prior Authorization
  - Claims Processing
  - Medication Reconciliation
  - Clinical Trial Enrollment

### Compliance Documentation

- **HIPAA Compliance Checklist**: [HEALTHCARE-DEVOPS-ARCHITECTURE.md#hipaa-compliance-checklist](HEALTHCARE-DEVOPS-ARCHITECTURE.md#hipaa-compliance-checklist)
- **HITRUST CSF Mapping**: [HEALTHCARE-DEVOPS-ARCHITECTURE.md#hitrust-csf-implementation](HEALTHCARE-DEVOPS-ARCHITECTURE.md#hitrust-csf-implementation)
- **NIST 800-53 Controls**: [HEALTHCARE-DEVOPS-ARCHITECTURE.md#nist-800-53-controls](HEALTHCARE-DEVOPS-ARCHITECTURE.md#nist-800-53-controls)

---

## 💰 Cost Analysis

### Monthly AWS Costs (Production)

| Service Category | Monthly Cost |
|-----------------|--------------|
| **Compute** (Lambda, Step Functions) | ~$165 |
| **Data** (DynamoDB, S3) | ~$187 |
| **Security** (WAF, GuardDuty, Macie) | ~$245 |
| **Networking** (VPC, Verified Access) | ~$132 |
| **Monitoring** (CloudWatch, CloudTrail) | ~$97 |
| **Total** | **~$1,026/month** |

### Cost Optimization Tips

1. **Use Reserved Capacity**: 30-50% savings for predictable workloads
2. **Right-size Lambda**: Start with 512MB, optimize based on metrics
3. **S3 Intelligent-Tiering**: Automatic cost optimization
4. **DynamoDB On-Demand**: Pay per request (ideal for variable workloads)
5. **Scheduled Macie Scans**: Weekly instead of continuous

**Annual cost**: ~$12,312/year for full HIPAA-compliant stack

---

## 🎯 Compliance Certifications

### AWS HIPAA Eligible Services Used

This architecture uses only **HIPAA-eligible AWS services**:

✅ API Gateway, Lambda, Step Functions, DynamoDB, S3, KMS, Cognito, CloudWatch, CloudTrail, VPC, WAF, GuardDuty, Security Hub, Config, Macie, Inspector, Comprehend Medical, Secrets Manager, Systems Manager

### Required Compliance Steps

1. **Sign BAA with AWS**: [AWS HIPAA Compliance](https://aws.amazon.com/compliance/hipaa-compliance/)
2. **Enable Compliance Standards** in Security Hub:
   - HIPAA Security Rule
   - NIST 800-53
   - CIS AWS Foundations Benchmark
3. **Conduct Risk Assessment**: Document in `docs/risk-assessment.md`
4. **Security Training**: All personnel with PHI access
5. **Regular Audits**: Quarterly penetration testing, annual compliance audit

---

## 📊 Monitoring & Dashboards

### CloudWatch Dashboards

- **Security Dashboard**: GuardDuty findings, WAF metrics, unauthorized API calls
- **Compliance Dashboard**: Config rule compliance, Security Hub score
- **Operational Dashboard**: Lambda errors, API latency, Step Functions executions
- **Cost Dashboard**: Daily spend, cost anomalies

### Alerts Configured

- **Critical Alerts** (PagerDuty):
  - GuardDuty critical findings
  - Security Hub critical/high findings
  - Unauthorized API calls
  - Failed authentication attempts

- **Warning Alerts** (Email):
  - Config rule violations
  - High error rates
  - Cost anomalies
  - Backup failures

---

## 🔧 Troubleshooting

### Common Issues

**Issue**: Terraform apply fails with "Access Denied"
```bash
# Solution: Verify IAM permissions
aws sts get-caller-identity
aws iam get-user
```

**Issue**: Lambda functions timeout in VPC
```bash
# Solution: Check VPC endpoints and security groups
terraform output vpc_id
aws ec2 describe-vpc-endpoints
```

**Issue**: Cognito authentication fails
```bash
# Solution: Verify user pool configuration
aws cognito-idp describe-user-pool --user-pool-id <POOL_ID>
```

**Issue**: Step Functions execution fails
```bash
# Solution: Check CloudWatch Logs
aws logs tail /aws/vendedlogs/states/production-patient-workflow --follow
```

---

## 🤝 Support

### Get Help

- **Documentation**: [HEALTHCARE-DEVOPS-ARCHITECTURE.md](HEALTHCARE-DEVOPS-ARCHITECTURE.md)
- **Issues**: [GitHub Issues](https://github.com/nkefor/2048-cicd-enterprise/issues)
- **AWS Support**: [AWS Health Dashboard](https://phd.aws.amazon.com/)

### Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

## 🏆 Credits

**Created By**: Healthcare DevOps Team
**Last Updated**: 2025-11-14
**Version**: 2.0.0
**Compliance**: HIPAA, HITRUST CSF, NIST 800-53

---

## 🔗 References

- [AWS HIPAA Compliance](https://aws.amazon.com/compliance/hipaa-compliance/)
- [HITRUST CSF](https://hitrustalliance.net/csf/)
- [NIST 800-53](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [AWS Well-Architected Framework - Healthcare](https://docs.aws.amazon.com/wellarchitected/latest/healthcare-lens/)
- [Amazon Comprehend Medical](https://aws.amazon.com/comprehend/medical/)
- [AWS Step Functions for Healthcare](https://aws.amazon.com/step-functions/use-cases/healthcare/)

---

**🚀 Ready to deploy your HIPAA-compliant healthcare platform? Start with the [Quick Start](#quick-start) guide!**
