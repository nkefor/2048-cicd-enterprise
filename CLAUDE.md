# CLAUDE.md - AI Assistant Guide

## Repository Overview

**Project**: Enterprise CI/CD Platform for Containerized Web Applications
**Type**: DevOps Infrastructure & Automation Demo
**Primary Technology**: Docker, GitHub Actions, AWS ECS Fargate
**Application**: 2048 Game (Static Web App)
**Last Updated**: 2025-11-26

This repository demonstrates an **enterprise-grade CI/CD pipeline** that automates containerized application deployment to AWS serverless infrastructure. The actual application is intentionally simple (a 2048 game) to focus attention on the infrastructure and automation patterns.

---

## Repository Structure

```
2048-cicd-enterprise/
├── 2048/                           # Application directory
│   ├── Dockerfile                  # NGINX-based container definition
│   └── www/
│       └── index.html              # 2048 game static HTML (single file)
│
├── .github/
│   └── workflows/
│       └── deploy.yaml             # GitHub Actions CI/CD pipeline
│
├── README.md                       # Comprehensive project documentation
├── ENTERPRISE-VALUE.md             # ROI analysis and business case studies
├── LICENSE                         # MIT License
├── .gitignore                      # Standard ignores (Terraform, AWS, IDE)
└── CLAUDE.md                       # This file
```

### Important Notes on Structure

- **No `infra/` directory yet**: README mentions Terraform files (vpc.tf, ecs.tf, etc.) but they don't exist in the repository yet. These are planned infrastructure-as-code files.
- **Single application file**: The 2048 game is a single HTML file with inline CSS/JavaScript
- **Minimal structure**: Intentionally simple to focus on CI/CD patterns rather than application complexity

---

## Key Files & Purposes

### 1. `2048/Dockerfile`
**Purpose**: Multi-stage container definition with security hardening
**Base Image**: `nginx:1.27-alpine`
**Key Features**:
- Copies static files to NGINX html directory
- Custom NGINX configuration with security headers
- Health check configuration (wget every 30s)
- Exposes port 80

**Security Headers Implemented**:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer-when-downgrade`

**When Modifying**:
- Maintain Alpine base for small image size
- Keep health check configuration intact
- Preserve security headers
- Test locally with `docker build -t 2048-game ./2048 && docker run -p 8080:80 2048-game`

### 2. `.github/workflows/deploy.yaml`
**Purpose**: Automated CI/CD pipeline for build and deployment
**Trigger**: Push to `main` branch (paths: `2048/**`, `.github/workflows/deploy.yaml`)
**Permissions**: `contents: read`, `id-token: write` (for OIDC authentication)

**Pipeline Stages**:
1. **Checkout**: Clone repository code
2. **Docker Buildx Setup**: Configure multi-platform builds
3. **AWS Authentication**: OIDC-based (no static credentials)
4. **ECR Login**: Authenticate to container registry
5. **Build & Push**: Docker image with tags `{SHA}` and `latest`
6. **ECS Deploy**: Update service with `--force-new-deployment`
7. **Wait for Stability**: Verify deployment success

**Required Secrets**:
- `AWS_REGION` - AWS region (e.g., us-east-1)
- `ECR_REPO` - Full ECR repository URI
- `AWS_ROLE_ARN` - IAM role ARN for OIDC authentication

**Hardcoded Values** (update if needed):
- ECS Cluster: `game-2048`
- ECS Service: `game-2048`

**When Modifying**:
- Update cluster/service names if deploying to different environments
- Add security scanning steps (e.g., Trivy) before push
- Consider adding approval steps for production deployments
- Add rollback logic on health check failures

### 3. `README.md`
**Purpose**: Comprehensive documentation for human readers
**Sections**:
- Business value & ROI calculations
- Architecture diagrams (ASCII art)
- Technology stack matrix
- Cost analysis comparisons
- Security features
- Quick start guide
- Troubleshooting (references non-existent docs)

**Important**: README describes infrastructure files that don't exist yet in the repository

### 4. `ENTERPRISE-VALUE.md`
**Purpose**: Business case justification with real-world examples
**Contents**:
- 5 detailed use case studies (SaaS, E-Commerce, FinTech, Media, Gaming)
- ROI calculator with sample calculations
- Before/after metrics comparison
- Annual savings breakdowns ($165K-$580K range)

### 5. `2048/www/index.html`
**Purpose**: Demo application (2048 game)
**Structure**: Single HTML file with inline CSS and JavaScript
**Dependencies**: None (completely self-contained)
**Size**: ~3.3 KB

---

## Development Workflows

### Local Development

#### Building the Docker Image
```bash
cd /home/user/2048-cicd-enterprise
docker build -t 2048-game ./2048
```

#### Testing Locally
```bash
docker run -p 8080:80 2048-game
# Visit http://localhost:8080
```

#### Testing Health Check
```bash
docker inspect --format='{{json .State.Health}}' <container-id>
```

### CI/CD Deployment Flow

**Automated Deployment Trigger**:
```bash
# 1. Make changes to application
vim 2048/www/index.html

# 2. Commit with conventional commits format
git add 2048/www/index.html
git commit -m "feat: Update game styling"

# 3. Push to main branch (triggers pipeline)
git push origin main
```

**What Happens Automatically**:
1. GitHub Actions triggers on push to `main`
2. Docker image built with context `./2048`
3. Image tagged with git SHA and `latest`
4. Pushed to AWS ECR
5. ECS service updated with new image
6. AWS waits for service stability (health checks pass)
7. Old tasks drained, new tasks receive traffic

**Deployment Time**: ~5-10 minutes from commit to production

### Manual Testing Workflows

#### Test Dockerfile Changes
```bash
# Build with custom tag
docker build -t 2048-game:test ./2048

# Run with custom port
docker run -p 9090:80 2048-game:test

# Check security headers
curl -I http://localhost:9090
```

#### Test Workflow Changes
```bash
# Trigger workflow manually via GitHub Actions UI
# Or use workflow_dispatch trigger
gh workflow run deploy.yaml
```

---

## Conventions & Standards

### Git Workflow

**Branch Strategy**:
- Main branch: `main` (production)
- Feature branches: `claude/{feature-name}-{session-id}`
- All deployments from `main` branch only

**Commit Message Format** (Conventional Commits):
```
<type>: <description>

Examples:
feat: Add new security headers to NGINX config
fix: Correct health check endpoint
docs: Update deployment guide
chore: Update Docker base image to 1.27-alpine
```

**Types**:
- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation changes
- `chore` - Maintenance tasks
- `refactor` - Code restructuring
- `test` - Test additions/changes
- `ci` - CI/CD pipeline changes

### Code Style

**Dockerfile**:
- Use Alpine-based images for minimal size
- Multi-line RUN commands with `\` continuation
- Security hardening is mandatory
- Always include HEALTHCHECK directive
- Use COPY over ADD for transparency
- Explicit EXPOSE directives

**YAML (GitHub Actions)**:
- 2-space indentation
- Descriptive step names (sentence case)
- Use official actions from verified publishers
- Pin action versions with `@v4` not `@latest`
- Environment variables at workflow level
- Secrets for all sensitive data

**Shell Scripts** (if added):
- Use `#!/bin/bash` shebang
- `set -euo pipefail` for safety
- Descriptive variable names
- Comments for complex logic

### Documentation Standards

**README Structure**:
- Executive summary first
- ASCII diagrams for architecture
- Tables for comparisons
- Code blocks with language hints
- Emoji for visual scanning (sparingly)

**Code Comments**:
- Explain "why" not "what"
- Security decisions must be documented
- Mark TODOs with `# TODO:` prefix

---

## AWS Infrastructure

### Current Deployment Architecture

**Note**: Infrastructure code (Terraform) is not yet in the repository, but the deployment targets are documented here.

**AWS Resources Referenced**:
- **ECS Cluster**: `game-2048`
- **ECS Service**: `game-2048`
- **ECR Repository**: Stored in `${{ secrets.ECR_REPO }}`
- **Region**: Configurable via `${{ secrets.AWS_REGION }}`

**Authentication Method**:
- OIDC (OpenID Connect) - No static AWS credentials
- GitHub Actions assumes IAM role via `${{ secrets.AWS_ROLE_ARN }}`

**Deployment Strategy**:
- Rolling update (ECS default)
- `--force-new-deployment` triggers task replacement
- Health checks determine task readiness
- Old tasks drained after new tasks healthy

### Planned Infrastructure (from README)

The README describes a complete Terraform setup that should include:
```
infra/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── vpc.tf                  # Network configuration
├── ecr.tf                  # Container registry
├── ecs.tf                  # Fargate cluster/service
├── alb.tf                  # Application Load Balancer
├── iam.tf                  # Roles and policies
├── cloudwatch.tf           # Monitoring
└── security-groups.tf      # Network security
```

**If Creating Terraform Files**:
1. Create `infra/` directory
2. Follow AWS provider best practices
3. Use variables for all environment-specific values
4. Output important values (ALB DNS, ECR URI, etc.)
5. Use remote state (S3 backend)
6. Enable state locking (DynamoDB)

---

## Common Tasks for AI Assistants

### 1. Updating the Application

**Task**: Modify the 2048 game appearance or functionality

**Steps**:
1. Read current file: `/home/user/2048-cicd-enterprise/2048/www/index.html`
2. Make requested changes (HTML/CSS/JavaScript all inline)
3. Test locally if possible: `docker build && docker run`
4. Commit with `feat:` or `fix:` prefix
5. Push to trigger deployment

**Example**:
```bash
# Edit the HTML file
vim 2048/www/index.html

# Test build
docker build -t 2048-test ./2048

# Commit
git add 2048/www/index.html
git commit -m "feat: Update game color scheme"
git push origin main
```

### 2. Modifying Docker Configuration

**Task**: Update NGINX config or security headers

**Steps**:
1. Read: `/home/user/2048-cicd-enterprise/2048/Dockerfile`
2. Modify the RUN command that generates NGINX config
3. Preserve security headers unless explicitly asked to change
4. Test build: `docker build -t test ./2048`
5. Verify headers: `docker run -p 8080:80 test` then `curl -I localhost:8080`
6. Commit with appropriate prefix

**Security Checklist**:
- [ ] Security headers still present
- [ ] Health check still configured
- [ ] Alpine base image maintained
- [ ] No secrets in Dockerfile

### 3. Updating CI/CD Pipeline

**Task**: Add new pipeline steps or modify deployment

**Steps**:
1. Read: `/home/user/2048-cicd-enterprise/.github/workflows/deploy.yaml`
2. Understand current pipeline flow
3. Add new steps in appropriate sequence
4. Update required secrets documentation
5. Test with workflow_dispatch or push to feature branch
6. Commit with `ci:` prefix

**Common Additions**:
- Security scanning (Trivy, Snyk)
- Automated testing
- Slack/email notifications
- Multi-environment deployments
- Approval gates

### 4. Creating Infrastructure Code

**Task**: Implement the Terraform files described in README

**Steps**:
1. Create `infra/` directory
2. Start with `main.tf` and `variables.tf`
3. Reference AWS provider version constraints
4. Create resources in logical order: VPC → ECR → IAM → ECS → ALB
5. Use data sources for existing resources if any
6. Add outputs for important values
7. Document required variables
8. Test with `terraform plan`

**Terraform Conventions**:
- Use `terraform fmt` for formatting
- Resource naming: `resource "aws_ecs_cluster" "game"`
- Variable validation where possible
- Tags on all resources: `Name`, `Environment`, `ManagedBy`

### 5. Adding Documentation

**Task**: Create missing documentation files

**The README references these missing files**:
- `docs/DEPLOYMENT-GUIDE.md`
- `docs/TROUBLESHOOTING.md`
- `docs/ARCHITECTURE.md`

**Steps**:
1. Create `docs/` directory if missing
2. Follow README structure and tone
3. Include code examples and screenshots
4. Cross-reference between docs
5. Update README links to point correctly
6. Commit with `docs:` prefix

### 6. Troubleshooting Deployments

**Task**: Debug failed GitHub Actions deployment

**Investigation Steps**:
1. Check GitHub Actions logs for the specific workflow run
2. Look for failures in specific steps
3. Common issues:
   - **ECR authentication failed**: Check `AWS_ROLE_ARN` secret
   - **Image push failed**: Verify `ECR_REPO` format and permissions
   - **ECS deployment failed**: Check cluster/service names match
   - **Health check timeout**: Verify container starts and responds on port 80

**Debugging Commands** (run locally):
```bash
# Test Docker build
docker build -t debug ./2048

# Test container starts
docker run -p 8080:80 debug

# Test health check endpoint
curl http://localhost:8080/

# Check container logs
docker logs <container-id>
```

### 7. Security Enhancements

**Task**: Improve security posture

**Recommended Enhancements**:
1. Add Trivy scanning to GitHub Actions
2. Implement container image signing
3. Add SAST (static analysis) tools
4. Enable ECR image scanning
5. Add secrets scanning (git-secrets, trufflehog)
6. Implement Content Security Policy headers
7. Add rate limiting in NGINX

**Example: Add Trivy Scanning**:
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REPO }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

---

## Important Constraints & Considerations

### What EXISTS in Repository
- ✅ Application code (2048 game HTML)
- ✅ Dockerfile with NGINX configuration
- ✅ GitHub Actions CI/CD pipeline
- ✅ Comprehensive documentation
- ✅ Business value analysis
- ✅ .gitignore with common patterns

### What DOESN'T EXIST (but is referenced)
- ❌ Terraform infrastructure code (`infra/` directory)
- ❌ Deployment scripts (`scripts/deploy.sh`, `scripts/cleanup.sh`)
- ❌ Documentation files (`docs/DEPLOYMENT-GUIDE.md`, etc.)
- ❌ Testing framework or test files
- ❌ Multiple environments (dev, staging, prod)

### When Creating Missing Components

**For Terraform Infrastructure**:
- Match the structure described in README
- Use AWS provider ~> 5.0
- Include all resources shown in architecture diagram
- Support multiple environments via workspaces or variables
- Use remote state (S3 + DynamoDB locking)

**For Documentation Files**:
- Match the tone and style of existing README
- Include practical examples and commands
- Add troubleshooting sections
- Keep business value perspective

**For Scripts**:
- Use bash with error handling
- Document prerequisites
- Include help text (`./script.sh --help`)
- Follow existing conventions

---

## Deployment Requirements

### GitHub Secrets (Required)

These must be configured in repository settings:

| Secret Name | Description | Example Format |
|------------|-------------|----------------|
| `AWS_REGION` | AWS region for deployment | `us-east-1` |
| `ECR_REPO` | Full ECR repository URI | `123456789012.dkr.ecr.us-east-1.amazonaws.com/game-2048` |
| `AWS_ROLE_ARN` | IAM role for OIDC auth | `arn:aws:iam::123456789012:role/GitHubActionsRole` |

### AWS Prerequisites

**IAM Role Requirements**:
- Trust relationship with GitHub OIDC provider
- Permissions: ECR (push), ECS (update service), CloudWatch Logs (write)
- Minimal permissions (least privilege)

**Infrastructure Prerequisites**:
- ECS cluster named `game-2048` must exist
- ECS service named `game-2048` must exist
- ECR repository must exist at `$ECR_REPO`
- Task definition compatible with new image tags

### Local Development Prerequisites

**For Docker Testing**:
- Docker installed and running
- Port 8080 available (or change mapping)

**For Terraform** (when adding):
- Terraform ~> 1.0 installed
- AWS CLI configured
- AWS credentials with appropriate permissions

---

## Error Handling & Debugging

### Common Issues

#### 1. GitHub Actions Deployment Fails

**Symptom**: Pipeline fails at "Deploy to Amazon ECS" step

**Causes**:
- Cluster/service name mismatch
- IAM role lacks permissions
- Service doesn't exist

**Resolution**:
```bash
# Verify cluster exists
aws ecs list-clusters --region us-east-1

# Verify service exists
aws ecs list-services --cluster game-2048 --region us-east-1

# Check service status
aws ecs describe-services --cluster game-2048 --services game-2048 --region us-east-1
```

#### 2. Container Health Check Fails

**Symptom**: Tasks start but fail health checks and are replaced

**Causes**:
- NGINX not starting correctly
- Port 80 not exposed
- Health check command fails

**Resolution**:
```bash
# Test locally
docker build -t test ./2048
docker run -p 8080:80 test

# Check if responding
curl http://localhost:8080/

# View container logs
docker logs <container-id>

# Exec into container
docker exec -it <container-id> sh
wget -qO- http://127.0.0.1/  # Test health check command
```

#### 3. ECR Push Fails

**Symptom**: "denied: Your authorization token has expired"

**Causes**:
- OIDC role not configured correctly
- Role doesn't have ECR permissions

**Resolution**:
- Verify `AWS_ROLE_ARN` secret is correct
- Check IAM role trust relationship includes GitHub OIDC
- Verify role has `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, etc.

#### 4. Docker Build Fails

**Symptom**: Build fails during Dockerfile execution

**Common Causes**:
- Syntax error in NGINX config generation
- Missing files in `www/` directory
- Network issues pulling base image

**Resolution**:
```bash
# Build with verbose output
docker build --progress=plain -t test ./2048

# Verify source files exist
ls -la 2048/www/

# Test NGINX config syntax (after build)
docker run --rm test nginx -t
```

---

## Performance Considerations

### Docker Image Optimization

**Current Image Size**: ~50-60 MB (Alpine base + NGINX + static files)

**Optimization Strategies**:
- Already using Alpine Linux (minimal)
- Could use multi-stage build (not needed for this simple app)
- Could compress static assets further
- Could use nginx:alpine-slim if available

### Build Time Optimization

**Current Build Time**: ~30-60 seconds

**Optimization Strategies**:
- Enable GitHub Actions build cache
- Use Docker layer caching
- Minimize layer count in Dockerfile

**Example: Add Caching**:
```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v6
  with:
    context: ./2048
    push: true
    tags: |
      ${{ env.ECR_REPO }}:${{ github.sha }}
      ${{ env.ECR_REPO }}:latest
    cache-from: type=registry,ref=${{ env.ECR_REPO }}:buildcache
    cache-to: type=registry,ref=${{ env.ECR_REPO }}:buildcache,mode=max
```

### Deployment Time Optimization

**Current Deployment**: ~2-5 minutes

**Factors**:
- ECS task replacement speed (30-90 seconds)
- Health check intervals (30 seconds)
- Container startup time (10-20 seconds)

**Optimization**:
- Reduce health check interval (trade-off: more checks)
- Optimize container startup (already minimal)
- Use deployment circuit breaker (fail fast)

---

## Security Best Practices

### Container Security

**Already Implemented**:
- ✅ Alpine base (smaller attack surface)
- ✅ Security headers in NGINX
- ✅ Health checks for availability
- ✅ Explicit port exposure

**Recommended Additions**:
- Run NGINX as non-root user
- Use read-only root filesystem
- Drop unnecessary Linux capabilities
- Scan images for vulnerabilities (Trivy)
- Sign images (Docker Content Trust)

**Example: Enhanced Dockerfile**:
```dockerfile
FROM nginx:1.27-alpine

# Create non-root user
RUN addgroup -g 1001 -S nginx-app && \
    adduser -u 1001 -S nginx-app -G nginx-app

# Copy files
COPY --chown=nginx-app:nginx-app www /usr/share/nginx/html

# Configure NGINX
RUN rm -f /etc/nginx/conf.d/default.conf && \
    printf '%s\n' \
    'server {' \
    '  listen 8080;' \
    '  ...' \
    '}' > /etc/nginx/conf.d/2048.conf

# Switch to non-root user
USER nginx-app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1
```

### Pipeline Security

**Already Implemented**:
- ✅ OIDC authentication (no static AWS keys)
- ✅ Minimal IAM permissions pattern
- ✅ Secrets stored in GitHub Secrets

**Recommended Additions**:
- Add vulnerability scanning step
- Add secrets scanning (prevent committing credentials)
- Enable branch protection on `main`
- Require PR reviews before merge
- Add SAST (Static Application Security Testing)

### Network Security

**AWS Infrastructure Should Include**:
- Private subnets for ECS tasks
- Security groups with minimal ingress
- ALB in public subnets only
- VPC Flow Logs enabled
- Network ACLs for defense in depth

---

## Testing Strategy

### Current State
- ❌ No automated tests exist
- ❌ No testing framework configured

### Recommended Testing Levels

**1. Container Testing**:
```bash
# Build test
docker build -t 2048-test ./2048

# Run test
docker run -d -p 8080:80 --name test-container 2048-test

# Smoke test
curl -f http://localhost:8080/ || exit 1

# Health check test
docker inspect --format='{{json .State.Health}}' test-container

# Cleanup
docker rm -f test-container
```

**2. Security Testing**:
```bash
# Vulnerability scan
trivy image 2048-test

# Secrets scan
trufflehog filesystem ./

# NGINX config test
docker run --rm 2048-test nginx -t
```

**3. Integration Testing**:
- Deploy to test environment
- Run automated UI tests
- Verify health endpoints
- Check security headers
- Test rollback procedures

**4. Load Testing**:
- Use tools like k6, Artillery, or Apache Bench
- Test concurrent users
- Verify auto-scaling triggers
- Monitor resource utilization

---

## Monitoring & Observability

### Expected CloudWatch Integration

**Logs**:
- ECS task logs (STDOUT/STDERR)
- NGINX access logs
- NGINX error logs
- Application-specific logs

**Metrics**:
- Task CPU utilization
- Task memory utilization
- Request count (from ALB)
- Response time (from ALB)
- HTTP error rates (4xx, 5xx)

**Alarms** (should be configured):
- High CPU (> 80%)
- High memory (> 90%)
- Task count drops to 0
- High error rate (> 5%)
- Health check failures

### Custom Metrics

**If Adding Application Metrics**:
```javascript
// Example CloudWatch custom metric
const AWS = require('aws-sdk');
const cloudwatch = new AWS.CloudWatch();

const putMetric = (metricName, value) => {
  const params = {
    Namespace: 'Game2048',
    MetricData: [{
      MetricName: metricName,
      Value: value,
      Unit: 'Count',
      Timestamp: new Date()
    }]
  };
  cloudwatch.putMetricData(params).promise();
};
```

---

## Cost Optimization

### Current Cost Profile

**Estimated Monthly AWS Costs**:
- ECS Fargate (3 tasks, 0.5 vCPU, 1 GB): ~$32
- Application Load Balancer: ~$16
- ECR Storage (5 GB): ~$0.50
- CloudWatch Logs: ~$5
- Data Transfer: ~$5
- **Total**: ~$58-60/month

### Optimization Strategies

**1. Right-Sizing**:
- Start with smallest task size (0.25 vCPU, 0.5 GB)
- Monitor metrics and increase if needed
- This app likely needs minimal resources

**2. Fargate Spot**:
- Use Spot pricing for 70% savings
- Good for fault-tolerant workloads
- Not recommended for production single-region

**3. Auto-Scaling**:
- Scale to minimum (1-2 tasks) during off-hours
- Scale up during peak traffic
- Use target tracking policies

**4. ECR Lifecycle Policies**:
```json
{
  "rules": [{
    "rulePriority": 1,
    "description": "Keep last 10 images",
    "selection": {
      "tagStatus": "any",
      "countType": "imageCountMoreThan",
      "countNumber": 10
    },
    "action": {
      "type": "expire"
    }
  }]
}
```

**5. CloudWatch Logs Retention**:
- Set retention to 7-30 days (not indefinite)
- Archive to S3 for long-term storage

---

## Future Enhancements

### Infrastructure Improvements
- [ ] Add Terraform infrastructure code
- [ ] Implement multi-environment support (dev/staging/prod)
- [ ] Add CloudFront CDN for global performance
- [ ] Implement auto-scaling policies
- [ ] Add RDS database (if dynamic features added)
- [ ] Multi-region deployment for DR

### Application Improvements
- [ ] Add backend API for features (leaderboard, user accounts)
- [ ] Implement progressive web app (PWA) features
- [ ] Add analytics tracking
- [ ] Implement A/B testing framework
- [ ] Add user authentication

### CI/CD Improvements
- [ ] Add automated testing (unit, integration, e2e)
- [ ] Implement security scanning (Trivy, Snyk)
- [ ] Add deployment approval gates
- [ ] Implement canary deployments
- [ ] Add rollback automation
- [ ] Multi-environment promotion pipeline

### Observability Improvements
- [ ] Add distributed tracing (AWS X-Ray)
- [ ] Implement structured logging
- [ ] Create CloudWatch dashboards
- [ ] Add synthetic monitoring
- [ ] Implement error tracking (Sentry)

### Security Improvements
- [ ] Add AWS WAF rules
- [ ] Implement rate limiting
- [ ] Add DDoS protection
- [ ] Enable GuardDuty monitoring
- [ ] Implement secrets rotation
- [ ] Add compliance scanning

---

## AI Assistant Quick Reference

### Before Making Changes
1. ✅ Read the relevant file completely
2. ✅ Understand current implementation
3. ✅ Check for dependencies
4. ✅ Verify changes align with conventions
5. ✅ Consider security implications

### When Creating New Files
1. ✅ Check if similar files exist for patterns
2. ✅ Follow established naming conventions
3. ✅ Add appropriate documentation
4. ✅ Update .gitignore if needed
5. ✅ Reference in README if significant

### When Modifying Workflows
1. ✅ Understand full pipeline flow
2. ✅ Test changes in feature branch first
3. ✅ Document required secrets
4. ✅ Consider failure scenarios
5. ✅ Add appropriate error handling

### When Adding Documentation
1. ✅ Match existing tone and structure
2. ✅ Include practical examples
3. ✅ Add code blocks with syntax highlighting
4. ✅ Cross-reference related documents
5. ✅ Update README if needed

### Git Operations
1. ✅ Use conventional commit messages
2. ✅ Push to feature branch first (claude/*)
3. ✅ Use `git push -u origin <branch-name>`
4. ✅ Retry on network errors (exponential backoff)
5. ✅ Verify branch starts with `claude/` before pushing

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-26 | 1.0.0 | Initial CLAUDE.md creation based on repository analysis |

---

## Contact & Support

This is a demonstration project. For questions about:
- **AWS ECS/Fargate**: See [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- **GitHub Actions**: See [GitHub Actions Documentation](https://docs.github.com/en/actions)
- **Docker**: See [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- **Terraform**: See [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**Last Updated**: 2025-11-26
**Repository**: nkefor/2048-cicd-enterprise
**License**: MIT
