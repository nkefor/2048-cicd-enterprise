# Container Runtime Security Policies

## Document Information

**Version**: 1.0.0
**Last Updated**: November 19, 2025
**Maintained By**: Enterprise Security Team
**Classification**: Internal Use

---

## Table of Contents

1. [Policy Overview](#policy-overview)
2. [Access Control](#access-control)
3. [Container Hardening](#container-hardening)
4. [Network Security](#network-security)
5. [Compliance Requirements](#compliance-requirements)
6. [Incident Response](#incident-response)
7. [Audit & Monitoring](#audit--monitoring)
8. [Policy Exceptions](#policy-exceptions)

---

## Policy Overview

### Purpose

This policy establishes security requirements for containerized applications running in production environments. It ensures:
- Real-time threat detection and response
- Compliance with regulatory frameworks (PCI-DSS, HIPAA, SOC 2)
- Prevention of container escapes and privilege escalation
- Protection of sensitive data
- Rapid incident identification and mitigation

### Scope

This policy applies to:
- All production containerized applications
- Development and staging environments
- Container infrastructure and orchestration platforms
- All personnel managing containers

### Effective Date

January 1, 2025

### Review Cycle

Annual review with quarterly updates as needed

---

## Access Control

### 1. Container User Isolation

**Requirement**: All containers must run as non-root users

```yaml
# REQUIRED in Dockerfile
USER appuser:appuser
RUN useradd -m -u 1000 appuser

# REQUIRED in docker-compose.yml or k8s manifests
user: "1000:1000"
```

**Rationale**: Prevents privilege escalation from container compromise

**Enforcement**: Falco rule blocks containers running as root

**Exception Process**: Documented in Exceptions section

### 2. Capability Dropping

**Requirement**: Drop all Linux capabilities except those explicitly needed

```yaml
# Minimum safe configuration
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
  - CHOWN

# Prohibited capabilities (ALWAYS dropped)
# - CAP_SYS_ADMIN       (container escape)
# - CAP_SYS_PTRACE      (process manipulation)
# - CAP_SYS_MODULE      (kernel module loading)
# - CAP_SETUID/SETGID   (privilege escalation)
```

**Enforcement**: Automatic scanning and Falco detection

### 3. Read-Only Filesystem

**Requirement**: Root filesystem must be read-only where possible

```yaml
read_only_root_filesystem: true
tmpfs:
  - /tmp
  - /var/tmp
  - /var/cache
```

**Rationale**: Prevents persistent backdoor installation

**Exceptions**: Only /tmp and /var/log may be writable

### 4. RBAC for Access

**Access Levels**:

| Role | Permissions | Examples |
|------|-------------|----------|
| Admin | All actions | Deployment, policy management |
| SecurityOps | View alerts, trigger remediation | Alert triage, incident response |
| DevOps | Deploy pre-approved images | Container deployment |
| Developer | View logs only | Debugging via read-only logs |
| Auditor | View audit trails only | Compliance reporting |

**Implementation**: Enforced via RBAC in Kibana, Grafana, and Prometheus

### 5. Secret Management

**Requirements**:
- No secrets in environment variables
- Use secret management systems (HashiCorp Vault, AWS Secrets Manager)
- Rotate secrets every 90 days
- Audit all secret access
- Encrypt secrets in transit (TLS 1.2+) and at rest (AES-256)

**Falco Detection**: Alerts on credential exposure patterns

---

## Container Hardening

### 1. Image Scanning

**Requirement**: All images must pass security scanning before production deployment

**Scanning Requirements**:
```bash
./scripts/scan.sh image:tag

# Results must show:
# - Zero CRITICAL vulnerabilities
# - < 5 HIGH vulnerabilities
# - SBoM generated
# - License compliance verified
```

**Frequency**:
- On-demand: Before deployment
- Automated: Weekly for all production images
- Continuous: Registry-level scanning

**Exception**: High vulnerabilities require documented risk acceptance

### 2. Minimal Base Images

**Approved Base Images**:
- `python:3.11-slim` (120MB)
- `node:18-alpine` (170MB)
- `golang:1.21-alpine` (310MB)
- `distroless/base` (10MB) - For production

**Prohibited**:
- ubuntu/centos full distributions
- Images with package managers (apt, yum) in production
- Pre-built images without source verification

### 3. Layer Caching Optimization

**Requirement**: Minimize layer count to reduce attack surface

```dockerfile
# GOOD: Combine multiple RUN commands
RUN apt-get update && \
    apt-get install -y foo bar && \
    rm -rf /var/lib/apt/lists/*

# BAD: Multiple RUN commands (multiple layers)
RUN apt-get update
RUN apt-get install foo
RUN apt-get install bar
```

### 4. Health Checks

**Requirement**: All containers must implement health checks

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 3s
  retries: 3
  start_period: 10s
```

**Purpose**: Automatic detection and recovery from failures

---

## Network Security

### 1. Network Policies

**Requirement**: Implement least-privilege network policies

```yaml
# Example: Allow only necessary connections
Ingress:
  - from: []
    ports:
      - protocol: TCP
        port: 8080  # App port

  - from:
      - namespaceSelector:
          matchLabels:
            role: monitoring
    ports:
      - protocol: TCP
        port: 9090  # Metrics
```

**Implementation**: Docker network, Kubernetes NetworkPolicy, or iptables

### 2. Outbound Restrictions

**Policy**: Container outbound connections restricted to:
- DNS servers (UDP 53)
- Allowed external APIs (documented whitelist)
- Package repositories (for installation only)

**Prohibited**:
- Outbound SSH (port 22)
- Reverse shells
- Data exfiltration channels

**Enforcement**: Falco + network policies

### 3. Service-to-Service Communication

**Requirement**: All inter-service communication must be authenticated

```yaml
# mTLS Configuration (if using service mesh)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT  # Require mTLS
```

### 4. DNS Monitoring

**Monitored Patterns**:
- DNS queries to unusual domains
- Excessive DNS queries (DNS amplification)
- DNS exfiltration attempts (long TXT records)

**Alert Threshold**: > 1000 unique DNS queries/hour

---

## Compliance Requirements

### 1. PCI-DSS (Payment Card Industry)

**Applicable Controls**:
- 3.4: Encryption of cardholder data at rest
- 6.2.4: Separation of duties (dev/test/prod)
- 10.7: Retention of audit logs (minimum 6 months, recommended 1 year)
- 12.3: Documented security policies

**Falco Rules**: 173 PCI-DSS specific rules

**Audit Schedule**: Quarterly

### 2. HIPAA (Healthcare)

**Applicable Controls**:
- § 164.312(a)(2)(i): Audit controls
- § 164.312(b): Audit logs and reports
- § 164.308(a)(5)(ii)(C): Sanctions for policy violations

**Falco Rules**: 89 HIPAA specific rules

**Requirements**:
- PHI access logging
- User identification/authentication
- Log retention: 6 years (minimum 1 year immediate access)

**Audit Schedule**: Annual with continuous monitoring

### 3. SOC 2 Type II

**Trust Service Criteria**:
- CC6.1: Logical access controls
- CC6.2: Prior to issuing system credentials
- CC7.2: System monitoring
- A1.1: Availability
- A1.2: Processing completeness

**Falco Rules**: 156 SOC 2 specific rules

**Audit Schedule**: Biennial

### 4. CIS Docker Benchmarks

**Compliance Level**: Level 2 (Best Practices)

**Key Areas**:
- Host Configuration
- Docker Daemon Configuration
- Docker Daemon Runtime
- Docker Security Operations

**Automated Checks**: Trivy + custom rules

---

## Incident Response

### 1. Detection-to-Response Timeline

| Severity | Detection | Alert | Investigation | Remediation | Resolution |
|----------|-----------|-------|----------------|-------------|------------|
| CRITICAL | < 2s | < 1s | 5 min | 15 min | 30 min |
| HIGH | < 30s | 5 min | 15 min | 30 min | 1 hour |
| MEDIUM | < 2 min | 10 min | 30 min | 1 hour | 4 hours |
| LOW | < 5 min | 30 min | 1 hour | 2 hours | 8 hours |

### 2. Automatic Containment

**CRITICAL Alerts**: Automatic container isolation
```bash
# Automatic actions:
1. Suspend container networking
2. Preserve forensic evidence
3. Notify security team
4. Create incident ticket
5. Prepare rollback procedure
```

**HIGH Alerts**: Manual approval required for remediation

### 3. Evidence Preservation

**Collected During Incident**:
- Container filesystem snapshot
- Process execution history
- Network connection logs
- System call traces
- Environment variables
- Credentials (encrypted)

**Retention**: Minimum 1 year for regulatory compliance

---

## Audit & Monitoring

### 1. Continuous Monitoring

**Monitored Activities**:
- All container execution
- File system modifications
- Network connections
- Privilege escalation attempts
- Secret access
- System configuration changes

**Monitoring Tool**: Falco + Elasticsearch + Kibana

**Alert Response**: < 1 minute for CRITICAL

### 2. Audit Logging

**Logged Events**:
- Container lifecycle (creation, start, stop, deletion)
- User actions (deployment, configuration changes)
- Security events (violations, detections)
- Access attempts (successful and failed)

**Log Format**: JSON with standardized fields

**Retention Policy**:
- Hot storage (7 days): Immediate access
- Warm storage (30 days): 1-second latency
- Cold storage (365 days): Archive
- Deletion: 7 years post-compliance need

### 3. Metrics Collection

**Key Metrics**:
```
Container Security:
  - falco_alerts_total{severity} (histogram)
  - falco_alert_latency_ms (histogram)
  - container_escape_attempts (counter)
  - privilege_escalation_attempts (counter)
  - vulnerability_scans_total (counter)
  - compliance_score (gauge)

System Performance:
  - container_cpu_usage_percent
  - container_memory_usage_mb
  - network_io_bytes
  - disk_io_bytes
```

**Dashboards**:
- Real-time Security (Kibana)
- Performance Metrics (Grafana)
- Compliance Scorecard (Grafana)
- Incident Trends (Grafana)

### 4. Regular Testing

**Quarterly Tests**:
- [ ] Falco alert generation
- [ ] Incident response procedure
- [ ] Backup and restore
- [ ] Policy enforcement

**Annual Tests**:
- [ ] Full disaster recovery
- [ ] Security assessment
- [ ] Compliance audit
- [ ] Penetration testing

---

## Policy Exceptions

### Exception Request Process

1. **Submission**: Complete Exception Request Form
2. **Justification**: Business case and risk assessment
3. **Review**: Security team + business owner
4. **Approval**: CTO or CSO signature required
5. **Monitoring**: Enhanced monitoring during exception
6. **Sunset**: Automatic expiration date (max 1 year)

### Current Exceptions

| Service | Policy | Reason | Expires | Owner |
|---------|--------|--------|---------|-------|
| legacy-api | Root user | Legacy application | 2025-12-31 | Legacy Team |
| monitoring | CAP_SYS_PTRACE | Performance monitoring | 2026-01-31 | Platform Team |

---

## Enforcement & Penalties

### Non-Compliance Actions

| Violation | First Offense | Second Offense | Severe/Repeat |
|-----------|---------------|----------------|----------------|
| Policy violation | Written warning | Suspension review | Termination |
| Container escape | Incident investigation | Loss of deploy rights | Termination |
| Secret exposure | Training required | Role change | Termination |

### Monitoring & Audit Trail

All policy enforcement actions are logged and auditable:
```bash
curl -X GET http://kibana:5601/api/saved_objects/dashboard/policy-violations
```

---

## Contact & Support

**Questions about this policy**:
- **Security Team**: security@company.com
- **Compliance Team**: compliance@company.com
- **DevOps Support**: devops@company.com

**Report Security Issues**:
- **Email**: security-incidents@company.com
- **Phone**: +1-XXX-XXX-XXXX (on-call)
- **Slack**: #security-incidents (internal only)

---

## Appendix A: Falco Rule Categories

### Security Rules
- Container Escape Prevention (8 rules)
- Privilege Escalation Detection (12 rules)
- Malware Detection (25 rules)
- Network Anomaly (15 rules)
- Sensitive File Access (18 rules)

### Compliance Rules
- PCI-DSS Monitoring (173 rules)
- HIPAA Monitoring (89 rules)
- SOC 2 Monitoring (156 rules)
- CIS Benchmarks (200 rules)

### Operational Rules
- System Configuration Changes (22 rules)
- Unauthorized Access Attempts (18 rules)
- Performance Monitoring (15 rules)

---

## Appendix B: Approved Technologies

### Approved Container Registries
- Docker Hub (verified publishers only)
- AWS ECR (company account)
- Google GCR (company account)
- Private registry (internal-only)

### Approved Runtime Environments
- Docker 20.10+
- Kubernetes 1.24+
- Podman 4.0+ (alternative)

### Approved Monitoring Stack
- Falco 0.35+
- Elasticsearch 8.0+
- Kibana 8.0+
- Prometheus 2.35+
- Grafana 8.0+

---

**Approval Signatures**:

| Role | Name | Date | Signature |
|------|------|------|-----------|
| CISO | [Name] | 2025-01-01 | __________ |
| CTO | [Name] | 2025-01-01 | __________ |
| Compliance Officer | [Name] | 2025-01-01 | __________ |

---

**Document History**:

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-01-01 | Security Team | Initial release |
| 1.1.0 | 2025-11-19 | Security Team | Updated compliance frameworks |

