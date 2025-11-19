# Quick Deployment Guide - Container Runtime Security Platform

## Overview

This guide provides quick steps to deploy the complete container runtime security platform with Falco, Elasticsearch, Kibana, and comprehensive monitoring.

**Deployment Time**: 5-10 minutes
**System Requirements**: 8GB RAM, 50GB disk, Docker 20.10+

---

## Step 1: Verify Prerequisites

```bash
# Check Docker
docker --version      # Should be 20.10.0 or higher
docker-compose --version  # Should be 2.0 or higher

# Verify Docker daemon running
docker ps            # Should not error

# Check system resources
free -h              # Need at least 8GB RAM
df -h                # Need at least 50GB free space
```

---

## Step 2: Clone/Prepare Project

```bash
cd /home/user/2048-cicd-enterprise/cloud-infrastructure-projects/03-container-runtime-security

# Verify all files exist
ls -la              # Should show README.md, docker-compose.yml, etc.
ls scripts/         # Should show deploy.sh, scan.sh, test-security.sh
```

---

## Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your settings (optional)
nano .env

# Key variables to customize:
# - ELASTICSEARCH_PASSWORD=changeme
# - SLACK_WEBHOOK_URL=https://hooks.slack.com/...
# - SMTP_HOST=smtp.company.com
# - SMTP_PASSWORD=your_password
```

---

## Step 4: Start Services

```bash
# Start all services (automated)
./scripts/deploy.sh start

# This will:
# ✓ Check prerequisites
# ✓ Validate configuration
# ✓ Build custom images
# ✓ Start all 11 services
# ✓ Wait for health checks
# ✓ Verify deployment
# ✓ Setup Kibana index patterns

# Watch logs (optional, in another terminal)
docker-compose logs -f
```

---

## Step 5: Access Dashboards

Once deployment completes, access platforms at:

```
Kibana (Log Analysis):
  URL: http://localhost:5601
  Username: elastic
  Password: changeme
  → Check: Security > Real-Time Alerts dashboard

Grafana (Metrics & Dashboards):
  URL: http://localhost:3000
  Username: admin
  Password: admin
  → Check: Dashboards > Container Security

Prometheus (Metrics):
  URL: http://localhost:9090
  → Check: Graph > Alerts

Sample Application:
  URL: http://localhost:8080
  Endpoints: /health, /api/data, /api/metrics
```

---

## Step 6: Verify Deployment

```bash
# Run automated tests
./scripts/test-security.sh

# Expected output:
# ✓ Falco Connectivity Check
# ✓ Elasticsearch Connectivity Check
# ✓ Falco Rules Coverage Check
# ✓ Alert Detection Latency Test
# ✓ False Positive Baseline Test
# ✓ Performance Metrics Test
# ✓ Compliance Rules Coverage

# Success: All tests passed! (or check warnings)
```

---

## Step 7: Run Security Scan

```bash
# Scan sample application image
./scripts/scan.sh sample-app:latest HIGH,CRITICAL

# Results:
# - Vulnerability count by severity
# - Critical issues listed
# - SBoM generated
# - Dependency analysis

# Check scan results:
ls -lh trivy/reports/
```

---

## Step 8: Generate Test Alerts (Optional)

```bash
# Trigger security test in sample app
curl -X POST http://localhost:8080/api/security/test \
  -H "Content-Type: application/json" \
  -d '{"test": "suspicious_read"}'

# Wait 10 seconds, then check Kibana
# Dashboard: Security > Real-Time Alerts
# You should see: "Suspicious File Access" alert
```

---

## Common Commands

```bash
# View service status
./scripts/deploy.sh status

# View service logs
./scripts/deploy.sh logs              # All services
./scripts/deploy.sh logs falco        # Falco only
./scripts/deploy.sh logs kibana       # Kibana only

# Restart services
./scripts/deploy.sh restart

# Stop services
./scripts/deploy.sh stop

# Complete reset (removes volumes)
./scripts/deploy.sh reset

# Health check
./scripts/deploy.sh verify
```

---

## Troubleshooting

### Services won't start

```bash
# Check prerequisites
docker ps              # Verify Docker running
docker-compose --version  # Verify Docker Compose installed

# Check logs
docker-compose logs    # View error messages

# Check resources
free -h               # Verify RAM available
df -h                 # Verify disk space
```

### Can't access Kibana/Grafana

```bash
# Check containers running
docker ps | grep -E "kibana|grafana"

# Check port mapping
docker-compose ps

# Test connection
curl -s http://localhost:5601/api/status

# View logs
docker-compose logs kibana
docker-compose logs grafana
```

### Falco not detecting alerts

```bash
# Check Falco running
docker ps | grep falco

# Verify rules loaded
docker exec falco falco -L | grep -c "Rule"

# Check Falco logs
docker logs falco | tail -20

# Trigger test
curl -X POST http://localhost:8080/api/security/test \
  -H "Content-Type: application/json" \
  -d '{"test": "suspicious_read"}'
```

### Elasticsearch disk full

```bash
# Check disk usage
curl -s http://localhost:9200/_cat/indices?v

# Enable index retention
./scripts/deploy.sh logs elasticsearch  # Check for warnings

# Delete old indices (be careful!)
curl -X DELETE http://localhost:9200/falco-2025.01.*
```

---

## Next Steps

After successful deployment:

1. **Review Policies**: Read `docs/security-policies.md`
2. **Prepare Response**: Review `docs/incident-response.md`
3. **Customize Rules**: Edit `falco/rules/custom-rules.yaml`
4. **Configure Alerts**: Update `alertmanager/config.yml` with your channels
5. **Create Dashboards**: Add custom Grafana dashboards
6. **Train Team**: Walk through dashboards and alert procedures
7. **Schedule Reviews**: Monthly alert reviews, quarterly compliance checks

---

## Production Deployment Checklist

Before moving to production:

- [ ] All tests pass (`./scripts/test-security.sh`)
- [ ] Security scan clean (`./scripts/scan.sh`)
- [ ] Policies reviewed with team
- [ ] Incident response plan approved
- [ ] Alerting channels configured (Slack, PagerDuty, Email)
- [ ] Backup procedures documented
- [ ] Log retention policies set (90+ days)
- [ ] RBAC configured for users
- [ ] TLS/SSL enabled (if exposing externally)
- [ ] Monitoring and alerting verified
- [ ] Team trained on dashboards
- [ ] Documentation updated

---

## Support & Documentation

- **README.md**: Comprehensive overview, use cases, ROI, architecture
- **PROJECT_STRUCTURE.md**: Detailed file descriptions and purposes
- **docs/security-policies.md**: Security policies and compliance
- **docs/incident-response.md**: Incident procedures and playbooks
- **Falco Docs**: https://falco.org/docs
- **Elasticsearch Docs**: https://www.elastic.co/guide

---

**Happy Deploying!** 🚀

For issues or questions, consult the README.md troubleshooting section or security team.
