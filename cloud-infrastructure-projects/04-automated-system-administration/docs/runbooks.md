# Operational Runbooks

**Last Updated**: 2025-11-19
**Version**: 1.0.0

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Infrastructure Provisioning](#infrastructure-provisioning)
3. [Application Deployment](#application-deployment)
4. [Security Operations](#security-operations)
5. [Backup & Recovery](#backup--recovery)
6. [Monitoring Setup](#monitoring-setup)
7. [Troubleshooting](#troubleshooting)

---

## Initial Setup

### Prerequisites
```bash
# System requirements
- Python 3.8+
- SSH access to target hosts
- Ansible 2.12+
- Git (optional, for version control)
```

### Bootstrap Environment

```bash
# 1. Clone repository (if applicable)
git clone <repo-url> ansible-automation
cd ansible-automation

# 2. Run bootstrap script
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh

# 3. Activate virtual environment
source venv/bin/activate

# 4. Install dependencies
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml

# 5. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
# Edit inventory/hosts.yml with your servers

# 6. Test connectivity
ansible all -i inventory/hosts.yml -m ping
```

### Validate Setup

```bash
# Run validation script
chmod +x scripts/validate.sh
./scripts/validate.sh

# Expected output:
# ✓ All validation checks passed!
```

---

## Infrastructure Provisioning

### Full Infrastructure Setup

**Use Case**: New servers or complete infrastructure rebuild

```bash
# 1. Prepare servers
#    - Install OS (Ubuntu 20.04 LTS recommended)
#    - Configure network
#    - Configure SSH access

# 2. Update inventory
vim inventory/hosts.yml
# Add your servers to appropriate groups

# 3. Configure variables
vim group_vars/all.yml
vim group_vars/webservers.yml  # if applicable
vim group_vars/databases.yml   # if applicable

# 4. Run setup playbook (dry-run first)
./scripts/deploy.sh -p infrastructure-setup --check

# 5. Review the dry-run output
# If satisfied, run without --check:
./scripts/deploy.sh -p infrastructure-setup

# 6. Verify setup
ansible all -i inventory/hosts.yml -m setup -a "filter=ansible_distribution*"
```

### Incremental Updates

**Use Case**: Update specific systems without touching others

```bash
# Update only web servers
./scripts/deploy.sh -p infrastructure-setup -l webservers

# Update with specific tags
./scripts/deploy.sh -p infrastructure-setup -t packages -l webservers

# Skip specific tasks
./scripts/deploy.sh -p infrastructure-setup --skip-tags=ssh
```

### Configuration Management

**Regular configuration updates**

```bash
# Apply configuration to specific group
./scripts/deploy.sh -p infrastructure-setup -l production --check

# Apply security hardening only
./scripts/deploy.sh -p security-hardening -t cis-ssh

# Roll back configuration
# (Requires manual intervention or restore from backup)
```

---

## Application Deployment

### Prepare for Deployment

```bash
# 1. Build application artifact
# Example: PHP application
cd /path/to/application
composer install --no-dev --optimize-autoloader
tar -czf /tmp/application-v1.0.0.tar.gz .

# 2. Copy to artifact location
mkdir -p /var/artifacts
cp /tmp/application-v1.0.0.tar.gz /var/artifacts/

# 3. Verify artifact
tar -tzf /var/artifacts/application-v1.0.0.tar.gz | head
```

### Deployment Process

```bash
# 1. Update deployment variables
export APP_VERSION="1.0.0"
export APP_NAME="myapp"
export ENVIRONMENT="production"

# 2. Dry-run deployment
./scripts/deploy.sh -p application-deployment \
  -l webservers \
  -e "app_version=1.0.0,app_name=myapp" \
  --check

# 3. Execute deployment
./scripts/deploy.sh -p application-deployment \
  -l webservers \
  -e "app_version=1.0.0,app_name=myapp"

# 4. Verify deployment
curl http://<server-ip>:8080/health
# Expected: HTTP 200 OK
```

### Zero-Downtime Deployment

**Process for high-availability deployments**

```bash
# 1. Health check
ansible webservers -i inventory/hosts.yml \
  -m uri -a "url=http://localhost:8080/health status_code=200"

# 2. Serial deployment (one server at a time)
./scripts/deploy.sh -p application-deployment \
  -l webservers \
  -e "serial_deployment=1"

# 3. Verify each deployment
curl http://web1:8080/health
curl http://web2:8080/health
curl http://web3:8080/health
```

### Rollback Procedure

```bash
# 1. Identify previous version
ls -la /opt/applications/myapp/releases/

# 2. Create rollback playbook (manual)
cat > rollback.yml << 'EOF'
---
- hosts: webservers
  tasks:
    - name: Rollback to previous version
      file:
        src: /opt/applications/myapp/releases/1.0.0
        dest: /opt/applications/myapp/current
        state: link
        force: yes

    - name: Restart application
      systemd:
        name: myapp
        state: restarted
EOF

# 3. Execute rollback
ansible-playbook rollback.yml

# 4. Verify rollback
curl http://<server-ip>:8080/health
```

---

## Security Operations

### Security Hardening

```bash
# 1. Full CIS benchmark hardening
./scripts/deploy.sh -p security-hardening

# 2. SSH hardening only
./scripts/deploy.sh -p security-hardening -t cis-ssh

# 3. Network hardening only
./scripts/deploy.sh -p security-hardening -t cis-network

# 4. Specific hosts
./scripts/deploy.sh -p security-hardening -l production
```

### SSH Key Management

```bash
# 1. Generate new SSH key (on control node)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# 2. Distribute public key
ansible all -i inventory/hosts.yml \
  -m authorized_key \
  -a "user=ubuntu key='{{ lookup('file', '~/.ssh/id_ed25519.pub') }}'"

# 3. Test connectivity with new key
ssh -i ~/.ssh/id_ed25519 ubuntu@<server-ip>

# 4. Revoke old key
ansible all -i inventory/hosts.yml \
  -m authorized_key \
  -a "user=ubuntu key='<old-key>' state=absent"
```

### Firewall Rules

```bash
# Add firewall rule
ansible webservers -i inventory/hosts.yml \
  -m ufw \
  -a "rule=allow port=443 proto=tcp"

# Remove firewall rule
ansible webservers -i inventory/hosts.yml \
  -m ufw \
  -a "rule=allow port=8080 proto=tcp state=absent"

# List firewall rules
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "ufw status numbered"
```

### Vulnerability Patching

```bash
# 1. Check available updates
ansible all -i inventory/hosts.yml \
  -m apt \
  -a "update_cache=yes upgrade=dist dry-run=yes"

# 2. Apply patches
./scripts/deploy.sh -p infrastructure-setup -t packages

# 3. Verify patches
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "apt list --upgradable"
```

---

## Backup & Recovery

### Automated Backups

```bash
# 1. Enable backups
./scripts/deploy.sh -p backup-restore \
  -e "enable_mysql_backup=true,enable_postgresql_backup=false"

# 2. Verify backup files
ansible databases -i inventory/hosts.yml \
  -m find \
  -a "path=/var/backups file_type=file age=1d"

# 3. Check backup size
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "du -sh /var/backups/*"
```

### Manual Backup Creation

```bash
# 1. Backup database
ansible db-prod-01 -i inventory/hosts.yml \
  -m shell \
  -a "mysqldump -u root -p$(cat /root/.mysql_password) --all-databases | gzip > /var/backups/manual-$(date +%Y%m%d).sql.gz"

# 2. Backup application
ansible web-prod-01 -i inventory/hosts.yml \
  -m archive \
  -a "path=/opt/applications/myapp dest=/var/backups/app-backup-$(date +%Y%m%d).tar.gz format=gz"

# 3. Verify backups
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "ls -lh /var/backups/ | grep $(date +%Y%m%d)"
```

### Database Recovery

```bash
# 1. List available backups
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "ls -la /var/backups/database/mysql/"

# 2. Stop application
ansible webservers -i inventory/hosts.yml \
  -m systemd \
  -a "name=myapp state=stopped"

# 3. Restore database
ansible db-prod-01 -i inventory/hosts.yml \
  -m shell \
  -a "gunzip < /var/backups/database/mysql/backup-*.sql.gz | mysql -u root -p$(cat /root/.mysql_password)"

# 4. Verify restore
ansible db-prod-01 -i inventory/hosts.yml \
  -m mysql_query \
  -a "login_db=myapp query='SELECT COUNT(*) FROM information_schema.tables;'"

# 5. Restart application
ansible webservers -i inventory/hosts.yml \
  -m systemd \
  -a "name=myapp state=started"
```

### Backup Retention Policy

```bash
# Cleanup old backups (older than 30 days)
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "find /var/backups -type f -mtime +30 -delete"

# Archive to S3 (if configured)
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "s3cmd sync /var/backups/ s3://my-bucket/backups/$(hostname)/"
```

---

## Monitoring Setup

### Initial Monitoring Setup

```bash
# 1. Install Node Exporter on all hosts
./scripts/deploy.sh -p monitoring-setup

# 2. Verify Node Exporter
ansible all -i inventory/hosts.yml \
  -m uri \
  -a "url=http://localhost:9100/metrics status_code=200"

# 3. Install Prometheus (on monitoring host)
./scripts/deploy.sh -p monitoring-setup -l monitoring

# 4. Install Grafana
ansible monitoring -i inventory/hosts.yml \
  -m apt \
  -a "name=grafana-server state=present"

# 5. Access Grafana
# http://<monitoring-host>:3000
# Default: admin/admin
```

### Add Monitoring Target

```bash
# 1. Add host to Prometheus scrape config
vim group_vars/monitoring.yml
# Add host to targets

# 2. Reload Prometheus
ansible monitoring -i inventory/hosts.yml \
  -m systemd \
  -a "name=prometheus state=reloaded"

# 3. Verify target
curl http://<prometheus-host>:9090/api/v1/targets
```

### Dashboard Management

```bash
# 1. Login to Grafana
# http://<grafana-host>:3000

# 2. Add Prometheus datasource
# Configuration → Data Sources → Add → Prometheus
# URL: http://prometheus:9090

# 3. Import dashboard
# Dashboards → New → Import
# ID: 1860 (Node Exporter for Prometheus)

# 4. Create custom dashboard
# Click + icon → Dashboard → New
# Configure panels as needed
```

### Alert Configuration

```bash
# 1. Define alert rules
vim group_vars/monitoring.yml
# Define alert thresholds

# 2. Update AlertManager configuration
vim playbooks/monitoring-setup.yml

# 3. Apply changes
./scripts/deploy.sh -p monitoring-setup -t alertmanager

# 4. Test alert firing
ansible monitoring -i inventory/hosts.yml \
  -m shell \
  -a "curl -X POST --data-urlencode 'query=up{job=\"node\"}==0' http://localhost:9090/api/v1/query"
```

---

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to host

```bash
# 1. Verify SSH connectivity
ssh -v ubuntu@<host-ip>

# 2. Check SSH key
ls -la ~/.ssh/id_rsa

# 3. Verify host in inventory
ansible all -i inventory/hosts.yml --list-hosts | grep <hostname>

# 4. Test Ansible connectivity
ansible <hostname> -i inventory/hosts.yml -m ping -vvv

# 5. Check firewall rules
ssh ubuntu@<host-ip> "sudo ufw status"

# 6. Verify SSH daemon
ssh ubuntu@<host-ip> "sudo systemctl status ssh"
```

### Playbook Failures

**Problem**: Playbook fails during execution

```bash
# 1. Run with verbose output
./scripts/deploy.sh -p <playbook> -v

# 2. Check logs
tail -f /var/log/ansible/ansible.log

# 3. Run specific task
ansible-playbook playbooks/<playbook>.yml -t <tag> -vvv

# 4. Check variable values
ansible <hostname> -i inventory/hosts.yml -m debug -a "var=<variable>"

# 5. Syntax check
ansible-playbook playbooks/<playbook>.yml --syntax-check
```

### Service Issues

**Problem**: Service not running after deployment

```bash
# 1. Check service status
ansible <hostname> -i inventory/hosts.yml \
  -m systemd \
  -a "name=<service> enabled=yes"

# 2. View service logs
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "journalctl -u <service> -n 50"

# 3. Restart service
ansible <hostname> -i inventory/hosts.yml \
  -m systemd \
  -a "name=<service> state=restarted"

# 4. Verify service health
ansible <hostname> -i inventory/hosts.yml \
  -m uri \
  -a "url=http://localhost:<port>/health"
```

### Backup Issues

**Problem**: Backup files not being created

```bash
# 1. Check backup directory
ansible databases -i inventory/hosts.yml \
  -m stat \
  -a "path=/var/backups"

# 2. Check cron jobs
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "crontab -l"

# 3. Check backup script
ansible databases -i inventory/hosts.yml \
  -m stat \
  -a "path=/usr/local/bin/mysql-backup.sh"

# 4. Manually run backup
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "bash /usr/local/bin/mysql-backup.sh"

# 5. Check disk space
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "df -h /var/backups"
```

### Performance Issues

**Problem**: Slow playbook execution

```bash
# 1. Check host connectivity
ansible all -i inventory/hosts.yml -m ping

# 2. Enable fact caching
# In ansible.cfg: fact_caching = redis

# 3. Reduce parallelism
./scripts/deploy.sh -p <playbook> -e "forks=3"

# 4. Profile playbook
ansible-playbook playbooks/<playbook>.yml \
  -e "var_files=/tmp/profile.txt" \
  --step

# 5. Check system resources
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "top -bn1 | head -20"
```

---

## Emergency Procedures

### System Recovery

**Complete system recovery from backup**

```bash
# 1. Boot from recovery media
# (Depends on infrastructure)

# 2. Restore filesystem from backup
# (Manual process)

# 3. Restore Ansible configuration
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "tar -xzf /var/backups/system/etc-backup-*.tar.gz -C /"

# 4. Reboot system
ansible <hostname> -i inventory/hosts.yml \
  -m reboot \
  -a "reboot_timeout=300"

# 5. Verify system
ansible <hostname> -i inventory/hosts.yml -m ping
```

### Mass Remediation

**Apply critical patch to all systems**

```bash
# 1. Create temporary playbook
cat > patches.yml << 'EOF'
---
- hosts: all
  tasks:
    - name: Apply critical patches
      apt:
        update_cache: yes
        upgrade: dist
        autoremove: yes
    - name: Reboot if needed
      reboot:
        reboot_timeout: 300
      when: install_result.changed
EOF

# 2. Execute with high parallelism
ansible-playbook patches.yml -f 50

# 3. Verify patching
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "apt list --upgradable"
```

---

## Getting Help

### Documentation
- `docs/architecture.md` - System architecture
- `docs/troubleshooting.md` - Common issues
- `README.md` - Project overview

### Logs
- `/var/log/ansible/` - Ansible execution logs
- `/var/log/syslog` - System logs
- `/var/log/auth.log` - Authentication logs

### Community
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
