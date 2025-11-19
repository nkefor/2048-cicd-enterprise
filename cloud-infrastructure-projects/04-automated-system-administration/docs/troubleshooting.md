# Troubleshooting Guide

**Last Updated**: 2025-11-19
**Version**: 1.0.0

## Quick Diagnostic Checklist

- [ ] Test SSH connectivity: `ssh -v ubuntu@<host-ip>`
- [ ] Verify Ansible installation: `ansible --version`
- [ ] Validate inventory: `ansible-inventory -i inventory/hosts.yml --list`
- [ ] Check connectivity: `ansible all -i inventory/hosts.yml -m ping`
- [ ] Review logs: `tail -f /var/log/ansible/ansible.log`
- [ ] Run syntax check: `ansible-playbook playbooks/<playbook>.yml --syntax-check`

---

## Connection Issues

### Issue: "Permission denied (publickey)"

**Symptoms**:
```
fatal: [hostname]: UNREACHABLE! => {
    "msg": "Failed to connect to the host via ssh: Permission denied (publickey).",
    "unreachable": true
}
```

**Solutions**:

1. **Verify SSH key exists**
```bash
ls -la ~/.ssh/id_rsa*
# Should show both id_rsa and id_rsa.pub
```

2. **Check key permissions**
```bash
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 700 ~/.ssh
```

3. **Verify key on target host**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<host-ip> "cat ~/.ssh/authorized_keys"
# Should contain your public key
```

4. **Add public key to target**
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@<host-ip>
```

5. **Test SSH with verbose output**
```bash
ssh -vvv ubuntu@<host-ip>
# Look for key authentication attempts
```

---

### Issue: "Connection timed out"

**Symptoms**:
```
fatal: [hostname]: UNREACHABLE! => {
    "msg": "timed out",
    "unreachable": true
}
```

**Solutions**:

1. **Verify network connectivity**
```bash
ping <host-ip>
# Should receive ICMP replies
```

2. **Check SSH port accessibility**
```bash
nc -zv <host-ip> 22
# Should show: Connection to <host-ip> port 22 [tcp/ssh] succeeded!
```

3. **Verify SSH is running on target**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<host-ip> "sudo systemctl status ssh"
```

4. **Check firewall rules**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<host-ip> "sudo ufw status"
# Should allow port 22
```

5. **Verify DNS resolution**
```bash
nslookup <hostname>
# Should resolve to correct IP
```

6. **Increase SSH timeout**
```bash
# In ansible.cfg
timeout = 60
```

---

### Issue: "Host key verification failed"

**Symptoms**:
```
fatal: [hostname]: UNREACHABLE! => {
    "msg": "Host key verification failed.",
    "unreachable": true
}
```

**Solutions**:

1. **Accept host key manually**
```bash
ssh -o StrictHostKeyChecking=accept-new ubuntu@<host-ip> "echo 'OK'"
```

2. **Disable host key checking (testing only)**
```bash
# In ansible.cfg
[defaults]
host_key_checking = False
```

3. **Update known_hosts**
```bash
ssh-keyscan -H <host-ip> >> ~/.ssh/known_hosts
```

---

## Playbook Execution Issues

### Issue: "Syntax error"

**Symptoms**:
```
ERROR! Parse error at line X, column Y of playbook: ...
```

**Solutions**:

1. **Check YAML syntax**
```bash
ansible-playbook playbooks/<playbook>.yml --syntax-check
```

2. **Validate with yamllint**
```bash
yamllint playbooks/<playbook>.yml
```

3. **Check indentation**
```bash
# YAML is whitespace-sensitive
# Use 2 spaces, not tabs
cat -A playbooks/<playbook>.yml | head
# ^I = tab (bad), spaces = good
```

4. **Common syntax issues**
```yaml
# Wrong - no space after :
- name:Task name
# Right
- name: Task name

# Wrong - invalid variable reference
variable value: {{ variable }}
# Right
variable_value: "{{ variable }}"
```

---

### Issue: "Undefined variable"

**Symptoms**:
```
fatal: [hostname]: FAILED! => {
    "msg": "The task includes an option with an undefined variable: 'variable_name'."
}
```

**Solutions**:

1. **Check variable definition**
```bash
# In playbook
ansible <hostname> -i inventory/hosts.yml \
  -m debug \
  -a "var=variable_name"
```

2. **Verify variable sources**
```
# Priority order:
1. Command-line: -e "var=value"
2. Play vars:
   vars:
     var: value
3. Host vars: host_vars/hostname.yml
4. Group vars: group_vars/groupname.yml
5. Role defaults: roles/role/defaults/main.yml
```

3. **Check typos**
```bash
# Search for variable usage
grep -r "variable_name" playbooks/
grep -r "variable_name" group_vars/
grep -r "variable_name" roles/
```

4. **Set default value**
```yaml
# In task
variable_name: "{{ some_var | default('default_value') }}"
```

---

### Issue: "No handlers defined"

**Symptoms**:
```
TASK [handlers] FAILED! => {
    "msg": "Handler 'Handler name' not found"
}
```

**Solutions**:

1. **Verify handler is defined**
```bash
grep -n "name: Handler name" playbooks/*.yml roles/*/handlers/*.yml
```

2. **Check handler name matches**
```yaml
# Handler definition
- name: Restart service
  systemd:
    name: nginx
    state: restarted

# Trigger notification
- name: Update config
  copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
  notify: Restart service  # Must match exactly
```

3. **Verify handler location**
```
# Handler should be in:
playbooks/handlers/main.yml
OR
roles/<role-name>/handlers/main.yml
```

---

### Issue: "Task failed with rc=127"

**Symptoms**:
```
FAILED - RETRYING: [hostname]: task (Retry #3/3) => {
    "rc": 127,
    "stderr": "command not found"
}
```

**Solutions**:

1. **Verify command exists on target**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "which <command>"
```

2. **Install missing package**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m apt \
  -a "name=<package> state=present"
```

3. **Use absolute path**
```yaml
# Instead of:
- name: Run script
  shell: script.sh

# Use:
- name: Run script
  shell: /usr/local/bin/script.sh
```

4. **Set PATH environment variable**
```yaml
- name: Run script
  shell: script.sh
  environment:
    PATH: "/usr/local/bin:/usr/bin:/bin"
```

---

## Privilege Escalation Issues

### Issue: "sudo: no password was provided"

**Symptoms**:
```
FAILED! => {
    "msg": "sudo: a password is required",
    "stderr": "sudo: a password is required"
}
```

**Solutions**:

1. **Use --ask-become-pass**
```bash
./scripts/deploy.sh -p <playbook> --ask-become-pass
# Or:
ansible-playbook playbooks/<playbook>.yml --ask-become-pass
```

2. **Configure passwordless sudo**
```bash
# On target host
sudo visudo
# Add line:
ubuntu ALL=(ALL) NOPASSWD: ALL
```

3. **Verify ansible_become_pass**
```yaml
# In group_vars or host_vars
ansible_become: yes
ansible_become_user: root
# ansible_become_password: "password"  # Avoid in version control!
```

---

### Issue: "permission denied"

**Symptoms**:
```
Permission denied (OS error 13)
```

**Solutions**:

1. **Check file permissions**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m stat \
  -a "path=/etc/sudoers.d/ansible"
# Should be mode=0440
```

2. **Verify user sudo privileges**
```bash
ssh ubuntu@<hostname> "sudo -l"
```

3. **Check file ownership**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m stat \
  -a "path=/etc/nginx/nginx.conf"
# Should be owned by root
```

---

## Module-Specific Issues

### Issue: "apt: command not found"

**Symptoms**:
```
fatal: [hostname]: FAILED! => {
    "msg": "The following modules failed to load: apt"
}
```

**Solutions**:

1. **Install required Python modules**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m apt \
  -a "name=python3-apt state=present"
```

2. **Use raw module as fallback**
```yaml
- name: Install packages
  raw: apt-get update && apt-get install -y package-name
```

3. **Set Python interpreter**
```yaml
# In group_vars
ansible_python_interpreter: /usr/bin/python3
```

---

### Issue: "mysql module not found"

**Symptoms**:
```
FAILED! => {
    "msg": "Failed to import the required Python library (pymysql)"
}
```

**Solutions**:

1. **Install PyMySQL**
```bash
ansible databases -i inventory/hosts.yml \
  -m pip \
  -a "name=PyMySQL state=present"
```

2. **Use raw SQL instead**
```yaml
- name: Execute SQL
  shell: mysql -u root -p"{{ mysql_password }}" < query.sql
```

---

## Package Management Issues

### Issue: "Unable to locate package"

**Symptoms**:
```
FAILED! => {
    "msg": "Unable to locate package nginx"
}
```

**Solutions**:

1. **Update package cache**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m apt \
  -a "update_cache=yes"
```

2. **Check package exists**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "apt-cache search nginx | head"
```

3. **Verify repository is enabled**
```bash
ssh ubuntu@<hostname> "cat /etc/apt/sources.list"
```

4. **Add PPA if needed**
```yaml
- name: Add repository
  apt_repository:
    repo: 'ppa:nginx/stable'
    state: present
```

---

## Service Management Issues

### Issue: "service is not running"

**Symptoms**:
```
Service health check failed
HTTP 503 or connection refused
```

**Solutions**:

1. **Check service status**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m systemd \
  -a "name=nginx enabled=yes"
```

2. **View service logs**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "journalctl -u nginx -n 50 -e"
```

3. **Restart service**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m systemd \
  -a "name=nginx state=restarted"
```

4. **Verify configuration**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "nginx -t"
# Should output "configuration OK"
```

---

## Backup and Recovery Issues

### Issue: "No backup files found"

**Solutions**:

1. **Check backup directory**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "ls -lah /var/backups/"
```

2. **Verify backup jobs**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "crontab -l | grep backup"
```

3. **Check disk space**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "df -h /var/backups"
```

4. **Manually run backup**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "bash /usr/local/bin/mysql-backup.sh"
```

---

### Issue: "Backup restore fails"

**Solutions**:

1. **Verify backup file integrity**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "tar -tzf /var/backups/backup.tar.gz | head"
```

2. **Check available disk space**
```bash
ansible databases -i inventory/hosts.yml \
  -m shell \
  -a "df -h /"
```

3. **Restore with verbose output**
```bash
# Test restore to temporary location
tar -xzf /var/backups/backup.tar.gz -C /tmp/ --verbose | head -20
```

---

## Performance Issues

### Issue: "Playbook running slowly"

**Solutions**:

1. **Enable fact caching**
```ini
# In ansible.cfg
[defaults]
fact_caching = redis
fact_caching_timeout = 86400
```

2. **Reduce serial execution**
```bash
./scripts/deploy.sh -p <playbook> -e "serial_deployment=5"
```

3. **Disable unnecessary fact gathering**
```yaml
- hosts: all
  gather_facts: no  # Only if not needed
```

4. **Increase parallelism**
```ini
# In ansible.cfg
[defaults]
forks = 50
```

5. **Check system resources**
```bash
ansible all -i inventory/hosts.yml \
  -m shell \
  -a "top -bn1 | head -5"
```

---

## Monitoring Issues

### Issue: "Node Exporter not responding"

**Solutions**:

1. **Verify service is running**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m systemd \
  -a "name=node_exporter enabled=yes"
```

2. **Check port is listening**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m shell \
  -a "netstat -tlnp | grep 9100"
```

3. **Test metrics endpoint**
```bash
ansible <hostname> -i inventory/hosts.yml \
  -m uri \
  -a "url=http://localhost:9100/metrics status_code=200"
```

---

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `FAILED - retrying` | Transient failure | Playbook retries automatically |
| `unreachable` | Cannot connect to host | Verify SSH connectivity |
| `fatal:` | Task failed and stopped | Check task output for details |
| `warning:` | Non-critical issue | Review but may be safe to ignore |
| `skipped:` | Task condition not met | Check `when` condition |
| `ignored:` | Error ignored in task | Expected behavior |
| `changed:` | Configuration modified | System state updated |
| `ok:` | Task completed successfully | No further action needed |

---

## Getting Detailed Diagnostics

### Run playbook with verbose output
```bash
# -v: Show task results
# -vv: Also show task arguments
# -vvv: Also show task execution and variable values
# -vvvv: Also show SSH connection details

ansible-playbook playbooks/<playbook>.yml -vvvv
```

### Enable Ansible debug logging
```bash
export ANSIBLE_DEBUG=True
ansible-playbook playbooks/<playbook>.yml
```

### Check Ansible configuration
```bash
ansible --version
ansible-config dump
```

### List inventory hosts and groups
```bash
ansible-inventory -i inventory/hosts.yml --list
ansible-inventory -i inventory/hosts.yml --graph
ansible all -i inventory/hosts.yml --list-hosts
```

---

## Support Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Community](https://www.ansible.com/community)
- [Stack Overflow - Ansible](https://stackoverflow.com/questions/tagged/ansible)
- [GitHub Issues](https://github.com/ansible/ansible/issues)
