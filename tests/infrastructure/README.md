# Infrastructure Tests

This directory contains tests for infrastructure-as-code (Terraform) validation and security scanning.

## Overview

These tests ensure that Terraform configurations are:
- **Syntactically valid** - Proper Terraform syntax
- **Correctly formatted** - Consistent code style
- **Secure** - No security vulnerabilities or misconfigurations
- **Compliant** - Meets policy and compliance requirements

## Test Scripts

### 1. `terraform-validate.sh`
Validates Terraform configuration files for syntax and consistency.

**Checks:**
- Terraform formatting (`terraform fmt -check`)
- Terraform initialization (`terraform init`)
- Terraform validation (`terraform validate`)

**Usage:**
```bash
bash tests/infrastructure/terraform-validate.sh
```

### 2. `tfsec-scan.sh`
Scans Terraform code for security vulnerabilities using [tfsec](https://github.com/aquasecurity/tfsec).

**Checks:**
- Unencrypted resources (S3, EBS, RDS, etc.)
- Publicly accessible resources
- Missing or weak security groups
- IAM policy issues
- Insecure network configurations
- And 100+ other security checks

**Installation:**
```bash
# macOS
brew install tfsec

# Linux
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Windows
choco install tfsec
```

**Usage:**
```bash
bash tests/infrastructure/tfsec-scan.sh
```

### 3. `checkov-scan.sh`
Scans infrastructure code for policy violations using [Checkov](https://www.checkov.io/).

**Checks:**
- CIS compliance (AWS, Azure, GCP)
- Cloud security best practices
- Resource misconfigurations
- Compliance frameworks (HIPAA, PCI-DSS, etc.)
- Policy-as-code violations

**Installation:**
```bash
# Using pip
pip3 install checkov

# Using Homebrew
brew install checkov
```

**Usage:**
```bash
bash tests/infrastructure/checkov-scan.sh
```

### 4. `run-all-tests.sh`
Runs all infrastructure tests in sequence and provides a summary.

**Usage:**
```bash
bash tests/infrastructure/run-all-tests.sh
```

## Current Status

⚠️ **Note:** The `infra/` directory does not exist yet, so these tests will currently pass with warnings.

These tests are ready to use once you add Terraform infrastructure code to the repository.

## Adding Terraform Infrastructure

When you're ready to add infrastructure-as-code:

1. **Create the `infra/` directory:**
   ```bash
   mkdir -p infra
   ```

2. **Add Terraform files:**
   ```
   infra/
   ├── main.tf              # Main configuration
   ├── variables.tf         # Input variables
   ├── outputs.tf           # Output values
   ├── vpc.tf               # VPC configuration
   ├── ecr.tf               # ECR repository
   ├── ecs.tf               # ECS cluster and service
   ├── alb.tf               # Application Load Balancer
   ├── iam.tf               # IAM roles and policies
   ├── cloudwatch.tf        # Monitoring and logs
   └── security-groups.tf   # Network security
   ```

3. **Run the tests:**
   ```bash
   bash tests/infrastructure/run-all-tests.sh
   ```

4. **Fix any issues found**

5. **Integrate with CI/CD** (see below)

## CI/CD Integration

Add to `.github/workflows/test.yaml`:

```yaml
infrastructure-tests:
  name: Infrastructure Tests
  runs-on: ubuntu-latest

  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0

    - name: Install tfsec
      run: |
        curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
        sudo mv tfsec /usr/local/bin/

    - name: Install checkov
      run: pip3 install checkov

    - name: Run infrastructure tests
      run: bash tests/infrastructure/run-all-tests.sh
```

## Test Coverage

Once Terraform is added, these tests will cover:

| Category | Coverage |
|----------|----------|
| **Syntax Validation** | 100% of Terraform files |
| **Security Scanning** | 100+ security checks (tfsec) |
| **Policy Compliance** | 1000+ policy checks (checkov) |
| **Best Practices** | AWS, Azure, GCP best practices |

## Common Issues and Fixes

### Issue: Terraform formatting failures

**Fix:**
```bash
terraform fmt -recursive
```

### Issue: tfsec findings

**Fix:** Address each finding individually or add exceptions:
```hcl
# tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "example" {
  # Encryption handled separately
}
```

### Issue: Checkov policy violations

**Fix:** Address violations or add skip annotations:
```hcl
# checkov:skip=CKV_AWS_20: ALB is internal only
resource "aws_lb" "example" {
  # ...
}
```

## Best Practices

1. **Run tests locally** before pushing code
2. **Fix security issues** before policy issues
3. **Document exceptions** when skipping checks
4. **Keep tools updated** for latest security rules
5. **Review scan results** even when tests pass

## Additional Resources

- [Terraform Validate Documentation](https://www.terraform.io/docs/cli/commands/validate.html)
- [TFSec Documentation](https://aquasecurity.github.io/tfsec/)
- [Checkov Documentation](https://www.checkov.io/1.Welcome/Quick%20Start.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

## Support

For issues with these tests, check:
1. Terraform syntax in your configuration files
2. Tool installation and versions
3. Network connectivity for downloading providers
4. AWS credentials (if running locally with backend)
