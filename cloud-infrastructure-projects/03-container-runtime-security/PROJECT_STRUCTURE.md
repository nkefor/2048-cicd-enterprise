# Container Runtime Security - Project Structure

## Project Overview

**Project Name**: Container Runtime Security with Falco & Aqua
**Version**: 1.0.0
**Status**: Production Ready
**Maintenance**: Enterprise Security Team

---

## Complete Directory Structure

```
03-container-runtime-security/
│
├── README.md                          # Main documentation (5 use cases, ROI, architecture)
├── LICENSE                            # Apache 2.0 license
├── PROJECT_STRUCTURE.md               # This file - detailed project layout
├── .env.example                       # Environment configuration template
├── .gitignore                         # Git ignore rules
│
├── docker-compose.yml                 # Complete stack orchestration
│                                      # Includes:
│                                      # - Falco (runtime security)
│                                      # - Elasticsearch (log storage)
│                                      # - Kibana (log visualization)
│                                      # - Prometheus (metrics collection)
│                                      # - Grafana (metrics visualization)
│                                      # - Filebeat (log forwarding)
│                                      # - AlertManager (alert routing)
│                                      # - cAdvisor (container metrics)
│                                      # - Node Exporter (host metrics)
│                                      # - Trivy (vulnerability scanning)
│                                      # - Sample app (demo application)
│
├── falco/
│   ├── falco.yaml                     # Falco main configuration
│   │                                  # - Runtime security settings
│   │                                  # - Output configuration
│   │                                  # - Performance tuning
│   │                                  # - Container detection
│   │
│   └── rules/
│       └── custom-rules.yaml          # Custom security detection rules
│                                      # - Container escape detection (5 rules)
│                                      # - Privilege escalation (8 rules)
│                                      # - Data exfiltration (6 rules)
│                                      # - System modification (8 rules)
│                                      # - Malware detection (8 rules)
│                                      # - Network security (6 rules)
│                                      # - Compliance rules (12 rules)
│                                      # Total: 53 custom rules
│
├── prometheus/
│   ├── prometheus.yml                 # Prometheus scrape configuration
│   │                                  # - Job definitions for all services
│   │                                  # - Falco metrics
│   │                                  # - Node metrics
│   │                                  # - Container metrics
│   │
│   └── alerts.yml                     # Alert rules for Prometheus
│                                      # - CRITICAL alerts (5 rules)
│                                      # - HIGH alerts (5 rules)
│                                      # - MEDIUM alerts (4 rules)
│                                      # - WARNING alerts (4 rules)
│                                      # - Availability monitoring (2 rules)
│                                      # - Compliance alerts (3 rules)
│                                      # - Security metrics (2 rules)
│                                      # Total: 25 alert rules
│
├── alertmanager/
│   └── config.yml                     # AlertManager routing and notifications
│                                      # - Slack integration
│                                      # - Email notifications
│                                      # - PagerDuty integration
│                                      # - Alert grouping strategies
│                                      # - Escalation policies
│
├── filebeat/
│   └── filebeat.yml                   # Filebeat log collection config
│                                      # - Falco alert ingestion
│                                      # - Docker log collection
│                                      # - System log collection
│                                      # - Elasticsearch output
│                                      # - Log enrichment
│
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml         # Grafana datasource config
│       │                              # - Prometheus connection
│       │                              # - Elasticsearch connection
│       │
│       └── dashboards/                # Grafana dashboard templates
│                                      # (Can be extended with JSON dashboards)
│
├── sample-app/
│   ├── Dockerfile                     # Multi-stage production Dockerfile
│   │                                  # - Non-root user
│   │                                  # - Minimal image
│   │                                  # - Health checks
│   │                                  # - Security best practices
│   │
│   ├── app.py                         # Flask web application
│   │                                  # - Health check endpoints
│   │                                  # - API endpoints
│   │                                  # - Security testing endpoints
│   │                                  # - Structured logging
│   │                                  # - Request tracking
│   │                                  # - Error handling
│   │
│   └── requirements.txt               # Python dependencies
│                                      # - Flask 2.3.2
│                                      # - Werkzeug 2.3.6
│                                      # - Security libraries
│                                      # - Monitoring libraries
│
├── scripts/
│   ├── deploy.sh                      # Deployment automation script
│   │                                  # Usage: ./deploy.sh [command]
│   │                                  # Commands:
│   │                                  # - start: Start all services
│   │                                  # - stop: Stop all services
│   │                                  # - restart: Restart services
│   │                                  # - status: Show service status
│   │                                  # - logs: View service logs
│   │                                  # - clean: Remove containers
│   │                                  # - reset: Full system reset
│   │                                  # - verify: Health check
│   │
│   ├── scan.sh                        # Vulnerability scanning script
│   │                                  # Usage: ./scan.sh [image] [severity]
│   │                                  # Performs:
│   │                                  # - Container image scanning
│   │                                  # - Vulnerability assessment
│   │                                  # - SBoM generation
│   │                                  # - Dependency analysis
│   │                                  # - Baseline comparison
│   │
│   └── test-security.sh               # Security testing script
│                                      # Usage: ./test-security.sh [test-name]
│                                      # Tests:
│                                      # - Falco connectivity
│                                      # - Elasticsearch connectivity
│                                      # - Alert latency
│                                      # - Detection capability
│                                      # - False positive rate
│                                      # - Performance metrics
│                                      # - Compliance rules
│
├── docs/
│   ├── security-policies.md           # Comprehensive security policies
│   │                                  # - Access control
│   │                                  # - Container hardening
│   │                                  # - Network security
│   │                                  # - Compliance requirements
│   │                                  # - Policy enforcement
│   │                                  # - Exception process
│   │
│   └── incident-response.md           # Incident response procedures
│                                      # - Severity classification
│                                      # - Detection to response workflow
│                                      # - Incident types (4 major types)
│                                      # - Containment procedures
│                                      # - Investigation checklist
│                                      # - Forensics queries
│                                      # - Recovery procedures
│                                      # - Communication templates
│
└── .github/
    └── workflows/                     # GitHub Actions workflows
                                       # (Can be extended with CI/CD)

```

---

## File Descriptions and Purpose

### Core Configuration Files

#### docker-compose.yml (450 lines)
**Purpose**: Orchestrates complete security stack
**Components**: 11 services
**Key Features**:
- Falco runtime security with eBPF
- Elasticsearch 8.10 with 512MB heap
- Kibana for log visualization
- Prometheus for metrics collection
- Grafana for dashboards
- Filebeat for log forwarding
- AlertManager for alert routing
- cAdvisor and Node Exporter for monitoring
- Trivy for vulnerability scanning
- Flask sample application
- Network and volume management

**Update Frequency**: As needed for new services/versions

#### docker-compose.yml Network Setup
```yaml
- Network: security_network (172.20.0.0/16)
- Internal communication only (no public exposure)
- Service discovery via DNS
```

---

### Falco Configuration

#### falco/falco.yaml (180 lines)
**Purpose**: Runtime security engine configuration
**Key Sections**:
- Rules loading and paths
- Output configuration (JSON, syslog, HTTP, gRPC)
- Performance tuning
- Container detection
- Syscall capture settings
- Alert rate limiting

**Critical Settings**:
```yaml
json_output: true
file_output.enabled: true
syslog_output.enabled: false
grpc_output.enabled: true
performance.rule_matching.max_ev_rate: 100
```

#### falco/rules/custom-rules.yaml (500 lines)
**Purpose**: Custom security detection rules
**Rule Categories**:

1. **Container Escape** (5 rules)
   - ptrace syscall detection
   - Privileged capability abuse
   - Host filesystem mounting
   - cgroup breakout attempts

2. **Privilege Escalation** (8 rules)
   - Unauthorized sudo
   - setuid binary execution
   - Capability misuse

3. **Data Exfiltration** (6 rules)
   - Large outbound transfers
   - Archive file creation
   - DNS tunneling

4. **System Modification** (8 rules)
   - /etc/passwd tampering
   - Cron job injection
   - SSH key injection
   - Binary modification

5. **Malware & Webshells** (8 rules)
   - Shell spawning from web processes
   - Reverse shell detection
   - Cryptocurrency miners
   - Process injection

6. **Network Security** (6 rules)
   - Unexpected connections
   - Port scanning
   - Suspicious DNS activity
   - Data exfiltration patterns

7. **Compliance** (12 rules)
   - Privilege escalation via package managers
   - Unauthorized user access
   - Sensitive file access
   - Credential exposure

**Total Rules**: 53 custom rules + 173 PCI-DSS + 89 HIPAA + 156 SOC2 built-in

---

### Prometheus Configuration

#### prometheus/prometheus.yml (120 lines)
**Purpose**: Metrics collection configuration
**Scrape Targets**: 10 services
- Self (5s interval)
- Alertmanager (15s)
- Node Exporter (15s)
- cAdvisor (30s)
- Docker (30s)
- Elasticsearch (30s)
- Kibana (30s)
- Falco (15s)
- Grafana (30s)

#### prometheus/alerts.yml (350 lines)
**Purpose**: Alert rules and thresholds
**Alert Groups**: 5 groups
- Container Security (8 rules)
- Availability Monitoring (2 rules)
- Compliance Monitoring (3 rules)
- Security Metrics (2 rules)
- Performance Monitoring (10 rules)

---

### Alerting Configuration

#### alertmanager/config.yml (250 lines)
**Purpose**: Alert routing and notifications
**Receivers**: 6 notification channels
- critical-alerts (Slack + Email + PagerDuty)
- high-alerts (Slack + Email)
- medium-alerts (Slack)
- low-alerts (Email)
- compliance-team (Email + Slack)
- platform-team (Slack)

**Grouping Strategy**: By alert name, severity, service
**Deduplication**: Prevents duplicate alerts

---

### Log Collection

#### filebeat/filebeat.yml (150 lines)
**Purpose**: Collect and forward security logs
**Inputs**: 3 sources
- Falco JSON alerts
- Docker container logs
- System logs (syslog)

**Processing**:
- JSON parsing
- Field extraction
- Docker metadata enrichment
- Kubernetes metadata (if applicable)
- Timestamp parsing

**Output**: Elasticsearch with bulk API

---

### Sample Application

#### sample-app/Dockerfile (50 lines)
**Purpose**: Production-ready containerized app
**Features**:
- Multi-stage build
- Non-root user (uid 1000)
- Minimal base image
- Health checks
- Security headers
- Read-only filesystem support

#### sample-app/app.py (450 lines)
**Purpose**: Flask web application for demonstration
**Endpoints**:
- `/health` - Health check
- `/status` - Detailed status
- `/api/echo` - Echo endpoint
- `/api/data` - Sample data
- `/api/metrics` - Application metrics
- `/api/info` - App information
- `/api/security/test` - Security testing (demo)

**Features**:
- Structured JSON logging
- Request/response tracking
- Error handling
- Security headers
- CORS support
- Graceful shutdown

#### sample-app/requirements.txt (20 lines)
**Purpose**: Python dependencies
**Dependencies**:
- Flask 2.3.2
- Werkzeug 2.3.6
- requests 2.31.0
- cryptography 41.0.1
- prometheus-client 0.17.1
- gunicorn 21.2.0

---

### Deployment Scripts

#### scripts/deploy.sh (520 lines)
**Purpose**: Automate complete deployment
**Commands**:
- `start` - Start all services with health checks
- `stop` - Stop all services gracefully
- `restart` - Restart services with zero downtime
- `status` - Show service status and endpoints
- `logs` - View service logs in follow mode
- `clean` - Stop and remove containers
- `reset` - Full system reset (removes volumes)
- `verify` - Health check and verification

**Safety Features**:
- Prerequisite checks
- Environment file validation
- Service health checks
- Automatic index pattern creation in Kibana
- Graceful error handling

#### scripts/scan.sh (420 lines)
**Purpose**: Vulnerability scanning automation
**Capabilities**:
- Container image scanning with Trivy
- Vulnerability severity filtering
- JSON, HTML, SARIF report generation
- SBoM (Software Bill of Materials) creation
- Dependency analysis
- Baseline comparison
- Registry scanning

**Output**: Multi-format reports in trivy/reports/

#### scripts/test-security.sh (480 lines)
**Purpose**: Security testing and validation
**Tests**: 7 major test categories
1. Falco connectivity
2. Elasticsearch connectivity
3. Falco rules coverage
4. Alert latency measurement
5. False positive baseline
6. Performance metrics
7. Compliance rules

**Output**: Test summary report with recommendations

---

### Documentation

#### docs/security-policies.md (600 lines)
**Purpose**: Comprehensive security policy document
**Sections**:
1. Access Control (5 policies)
2. Container Hardening (4 requirements)
3. Network Security (4 policies)
4. Compliance Requirements (4 frameworks)
5. Incident Response (3 procedures)
6. Audit & Monitoring (4 components)
7. Policy Exceptions (process + current list)

**Coverage**:
- PCI-DSS v3.2.1
- HIPAA §164
- SOC 2 Type II
- CIS Docker Benchmarks
- NIST Cybersecurity Framework

#### docs/incident-response.md (800 lines)
**Purpose**: Incident response procedures and playbooks
**Sections**:
1. Response Overview (roles, responsibilities)
2. Severity Classification (CRITICAL to LOW)
3. Detection-to-Response Workflow
4. Incident Types & Procedures (4 major types):
   - Container Escape
   - Malware/Webshell
   - Data Exfiltration
   - Privilege Escalation
5. Containment Procedures
6. Investigation & Forensics
7. Remediation Steps
8. Communication & Escalation
9. Post-Incident Review

**Features**:
- Bash command examples
- Elasticsearch query templates
- Timeline reconstruction guide
- Evidence preservation checklist
- Regulatory notification requirements
- Contact directory

---

## Compliance Coverage

### PCI-DSS Monitoring
- 173 Falco rules specific to PCI-DSS
- All 12 major requirements covered
- Real-time compliance score tracking
- Audit log retention (6+ years)

### HIPAA Monitoring
- 89 Falco rules for HIPAA compliance
- PHI access tracking
- Encryption enforcement
- Access control monitoring
- Audit trail generation

### SOC 2 Type II
- 156 Falco rules for SOC 2
- Logical access controls
- Processing completeness
- System availability monitoring
- Evidence collection automation

### CIS Docker Benchmarks
- 200+ configuration checks
- Host configuration monitoring
- Docker daemon hardening
- Runtime security rules
- Automated compliance scoring

---

## Key Metrics & KPIs

### Security Metrics
```
falco_alerts_total
- By severity (CRITICAL, HIGH, MEDIUM, LOW)
- By rule name
- By container

falco_alert_latency_ms
- 50th percentile: < 50ms
- 95th percentile: < 100ms
- 99th percentile: < 200ms

container_escape_attempts_total
- Threshold: Alert if > 0

privilege_escalation_attempts_total
- Threshold: Alert if > 0 per hour

vulnerability_scans_total
- By severity (CRITICAL, HIGH, MEDIUM, LOW)
- By image name
```

### Operational Metrics
```
container_memory_usage_bytes
- Alert if > 85% of limit

container_cpu_usage_percent
- Alert if > 80% sustained

elasticsearch_indices_docs_total
- Track ingestion rate

elasticsearch_disk_free_percent
- Alert if < 20% remaining
```

### Compliance Metrics
```
compliance_score (0-100%)
- Target: > 95%
- Trend: Should improve over time

audit_log_retention_days
- Target: > 365 days (7 years for archives)

false_positive_rate_percent
- Target: < 8%
- Should decrease over time
```

---

## Deployment Checklist

### Pre-Deployment
- [ ] Review all configuration files
- [ ] Update .env with production values
- [ ] Verify Docker daemon is running
- [ ] Check available disk space (> 50GB recommended)
- [ ] Review security policies with team
- [ ] Prepare incident response team

### Deployment
- [ ] Run: `./scripts/deploy.sh start`
- [ ] Monitor: `docker-compose logs -f`
- [ ] Wait for all services healthy (< 3 minutes)
- [ ] Verify: `./scripts/deploy.sh verify`
- [ ] Configure Kibana index patterns

### Post-Deployment
- [ ] Run: `./scripts/test-security.sh`
- [ ] Run: `./scripts/scan.sh sample-app:latest`
- [ ] Review Falco alerts (Kibana dashboard)
- [ ] Configure alerting channels (Slack, PagerDuty)
- [ ] Train team on dashboards
- [ ] Document customizations

### Production Hardening
- [ ] Enable TLS for all components
- [ ] Configure RBAC for users
- [ ] Set up backup procedures
- [ ] Configure log retention
- [ ] Set up external syslog
- [ ] Schedule security rule updates

---

## Maintenance & Updates

### Monthly Tasks
- [ ] Review security alert trends
- [ ] Update Falco rules
- [ ] Check for CVEs in images
- [ ] Review false positive patterns
- [ ] Backup Elasticsearch data

### Quarterly Tasks
- [ ] Compliance audit
- [ ] Penetration testing
- [ ] Disaster recovery test
- [ ] Security policy review
- [ ] Team training update

### Annual Tasks
- [ ] Full security assessment
- [ ] Framework compliance review (PCI, HIPAA, SOC2)
- [ ] Third-party audit
- [ ] Technology refresh evaluation
- [ ] ROI analysis

---

## Support & Documentation

**Quick Start**: See README.md (section: Quick Start Guide)
**Security Policies**: See docs/security-policies.md
**Incident Response**: See docs/incident-response.md
**Troubleshooting**: See README.md (section: Troubleshooting)

**Official Resources**:
- Falco: https://falco.org
- Elasticsearch: https://www.elastic.co
- Prometheus: https://prometheus.io
- Grafana: https://grafana.com

---

## License

Apache License 2.0 - See LICENSE file

---

**Project Version**: 1.0.0
**Last Updated**: November 19, 2025
**Next Review**: June 19, 2026
