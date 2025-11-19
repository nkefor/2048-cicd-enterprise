# Container Runtime Security - Incident Response Guide

## Document Information

**Version**: 1.0.0
**Last Updated**: November 19, 2025
**Maintained By**: Enterprise Security Team
**Classification**: Internal Use

---

## Table of Contents

1. [Response Overview](#response-overview)
2. [Severity Classification](#severity-classification)
3. [Detection to Response Workflow](#detection-to-response-workflow)
4. [Incident Types & Procedures](#incident-types--procedures)
5. [Containment Procedures](#containment-procedures)
6. [Investigation & Forensics](#investigation--forensics)
7. [Remediation](#remediation)
8. [Communication & Escalation](#communication--escalation)
9. [Post-Incident Review](#post-incident-review)
10. [Contact Directory](#contact-directory)

---

## Response Overview

### Objectives

1. **Detect**: Identify threats in < 2 seconds (CRITICAL) to < 5 minutes (LOW)
2. **Contain**: Isolate affected systems within 15 minutes
3. **Investigate**: Determine root cause within 4 hours
4. **Eradicate**: Remove threat and close vulnerabilities
5. **Recover**: Restore systems to secure state
6. **Learn**: Implement controls to prevent recurrence

### Roles & Responsibilities

| Role | Responsibilities | Available |
|------|------------------|-----------|
| **Incident Commander** | Coordinate response, decision making, communication | 24/7 on-call |
| **Security Analyst** | Alert triage, initial investigation, evidence collection | 24/7 on-call |
| **Forensics Expert** | Deep investigation, timeline reconstruction, reporting | Business hours + on-call |
| **System Administrator** | System access, containment actions, remediation | 24/7 on-call |
| **DevOps Engineer** | Image rebuild, deployment rollback, infrastructure changes | 24/7 on-call |
| **Communications** | Stakeholder updates, regulatory notification | Business hours |
| **Legal/Compliance** | Regulatory requirements, breach notification, liability | Business hours |

---

## Severity Classification

### CRITICAL (P1) - Immediate Response

**Characteristics**:
- Active container escape in progress
- Credential compromise
- Malware/ransomware detected
- Data exfiltration confirmed
- System unavailability

**Response SLA**: Detection < 2s, Mitigation < 15 min
**Escalation**: Immediate to CTO, CISO, COO

**Example Alerts**:
```
- "Container Escape - ptrace Syscall"
- "Privilege Escalation - Unauthorized sudo"
- "Malware Detection - Webshell Detected"
- "Data Exfiltration - Large Outbound Transfer"
- "Container Escape - Privileged Capability Abuse"
```

### HIGH (P2) - Urgent Response

**Characteristics**:
- Suspicious process execution (potential RCE)
- Unauthorized file modification
- Privilege escalation attempt
- Port scanning activity
- Anomalous network behavior

**Response SLA**: Detection < 30s, Investigation < 1 hour, Mitigation < 4 hours
**Escalation**: To CTO, Security Lead

**Example Alerts**:
```
- "Suspicious Process - Shell from Webserver"
- "Unauthorized System Modification - /etc/passwd Write"
- "SSH Key Injection Detected"
- "Port Scanning Tool Executed"
- "Suspicious Network - Unexpected Outbound"
```

### MEDIUM (P3) - Standard Response

**Characteristics**:
- Multiple failed authentication attempts
- Suspicious command patterns
- Compliance policy violations
- Configuration changes
- Unusual resource consumption

**Response SLA**: Investigation < 4 hours, Mitigation < 24 hours
**Escalation**: To Security Lead

**Example Alerts**:
```
- "Suspicious Command - Base64 Encoded Script"
- "Compliance - Privilege Escalation via Package Manager"
- "Compliance - Unauthorized User Access"
- "High Vulnerability Count Detected"
```

### LOW (P4) - Routine Response

**Characteristics**:
- Informational alerts
- Configuration drift
- Minor security events
- Routine maintenance activities

**Response SLA**: Investigation within 1 week
**Escalation**: Logged for trend analysis

---

## Detection to Response Workflow

### Automated Detection Pipeline

```
Falco Rule Match
    ↓
(Alert in < 2 seconds)
    ↓
Prometheus Alert Engine
    ↓
(Severity Assessment)
    ↓
Alert Routing
├─ CRITICAL → Immediate Slack + PagerDuty + Email
├─ HIGH → Slack + Email (within 5 min)
├─ MEDIUM → Email + Dashboard
└─ LOW → Dashboard only
    ↓
Elasticsearch Indexing
    ↓
(Searchable within 10 seconds)
    ↓
Kibana Visualization
    ↓
(Human Review & Triage)
```

### Initial Triage Checklist

Upon alert receipt, Security Analyst performs:

```
☐ 1. Verify Alert Authenticity
    - Check Falco logs: docker exec falco tail -f /var/log/falco/alerts.json
    - Verify source IP and process
    - Confirm false positive likelihood

☐ 2. Gather Initial Context
    - Container ID and name
    - Container image and version
    - Process and user information
    - Related network connections
    - Timing and frequency

☐ 3. Severity Confirmation
    - Confirm severity classification
    - Assess business impact
    - Identify affected services

☐ 4. Initial Notification
    - Notify on-call Incident Commander (if P1/P2)
    - Create incident ticket (Jira: SEC-xxxx)
    - Begin time tracking

☐ 5. Begin Investigation
    - Preserve forensic evidence
    - Check for related alerts in time window
    - Review recent container activities
```

---

## Incident Types & Procedures

### Type 1: Container Escape Attempt

**Detection**: Falco rule "Container Escape - ptrace Syscall" triggers

**Immediate Actions** (First 5 minutes):

```bash
# 1. Identify affected container
ALERT_DATA=$(curl -s "http://kibana:5601/api/saved_objects/alert/\$ALERT_ID")
CONTAINER_ID=$(echo $ALERT_DATA | jq -r '.attributes.container_id')

# 2. Isolate container network
docker network disconnect ${NETWORK_NAME} ${CONTAINER_ID}

# 3. Preserve forensic evidence
docker commit ${CONTAINER_ID} forensics/escape-${TIMESTAMP}:latest
docker save forensics/escape-${TIMESTAMP} > /secure/forensics/container-${TIMESTAMP}.tar

# 4. Kill container
docker kill ${CONTAINER_ID}

# 5. Notify team
# [Slack message] Critical: Container escape attempt detected in $(docker inspect ${CONTAINER_ID} --format='{{.Name}}')

# 6. Document in incident ticket
# SEC-xxxx: Privilege Escalation Attempt
```

**Investigation** (Next 30 minutes):

```bash
# 1. Analyze container image
trivy image --severity CRITICAL ${IMAGE}:${TAG}

# 2. Review process execution history
docker inspect ${CONTAINER_ID} | jq '.Config.Cmd'

# 3. Check system calls leading to ptrace
# Search Elasticsearch:
# message: "ptrace" AND container_id: ${CONTAINER_ID}

# 4. Identify if escape succeeded
# Check host system for rootkit/backdoor indicators
find / -name "*ptrace*" -type f 2>/dev/null
netstat -antp | grep -E ":(31337|666|1337)"  # Common backdoor ports

# 5. Review network egress
# SEC-xxxx: Check suspicious outbound connections during incident window

# 6. Correlate with other alerts
# Search for related events +/- 5 minutes
```

**Remediation**:

```bash
# 1. Quarantine affected image
docker tag ${IMAGE}:${TAG} ${IMAGE}:${TAG}-quarantined
docker rmi ${IMAGE}:${TAG}

# 2. Re-scan base image
./scripts/scan.sh ${BASE_IMAGE} CRITICAL

# 3. Rebuild without vulnerability
docker build --no-cache -t ${IMAGE}:${TAG} .

# 4. Deploy fixed image
docker-compose restart ${SERVICE}

# 5. Verification
./scripts/test-security.sh --detection

# 6. Update runbook
# SEC-xxxx: Document vulnerability and prevention for future
```

### Type 2: Malware/Webshell Detection

**Detection**: Falco rule "Suspicious Process - Shell Spawning from Webserver" triggers

**Immediate Actions**:

```bash
# 1. Identify source
CONTAINER=$(curl -s "http://kibana:5601/..." | jq -r '.container_id')
PARENT=$(jq -r '.parent_process' event.json)

# 2. CRITICAL: Block external access
docker network disconnect bridge ${CONTAINER}

# 3. Preserve evidence
docker cp ${CONTAINER}:/var/www /forensics/webroot-${TIMESTAMP}/
docker logs ${CONTAINER} > /forensics/container-logs-${TIMESTAMP}.txt

# 4. Kill container
docker kill ${CONTAINER}

# 5. Escalate
# Notify: CTO, CISO, Legal (potential breach)
```

**Investigation**:

```bash
# 1. Analyze webshell code
strings /forensics/webroot-${TIMESTAMP}/*.php | grep -i "exec\|passthru\|shell_exec"

# 2. Determine infection vector
# - Vulnerable component?
# - Supply chain compromise?
# - Misconfiguration?

# 3. Check data access
# What databases accessed?
# What files read/written?
# Network connections established?

# 4. Determine if data exfiltrated
# Size of outbound transfers?
# Encryption strength?
# Destination analysis?

# 5. Timeline reconstruction
grep "${CONTAINER_ID}" /elasticsearch/indices/falco-*/queries.log | sort -t: -k1
```

**Containment & Remediation**:

```bash
# 1. Determine scope
# Is vulnerability in:
# ☐ Base image? (rebuild all images)
# ☐ Application code? (patch source, rebuild)
# ☐ Configuration? (update security settings)

# 2. For each affected instance:
docker-compose restart  # Fresh containers

# 3. Post-incident
☐ Security audit of codebase
☐ Vulnerability assessment
☐ Malware signature update
☐ Firewall rule changes
☐ WAF rule updates (if applicable)
```

### Type 3: Data Exfiltration Attempt

**Detection**: Falco rule "Data Exfiltration - Large Outbound Transfer" triggers

**Immediate Actions** (Must be < 1 minute):

```bash
# 1. Block egress immediately
docker network disconnect ${NETWORK} ${CONTAINER}

# 2. Identify transfer destination
curl -s "http://kibana:5601/api/search/falco-*" | \
  jq '.hits.hits[] | select(.rule=="Data Exfiltration") | .destination_ip'

# 3. Notify network team to block destination
# Manual: Firewall block ${DESTINATION_IP}
# Automated: /scripts/block-ip.sh ${DESTINATION_IP}

# 4. Verify transfer stopped
# Check: Has destination received data after block?
# Monitor: No new connections from container

# 5. Preserve evidence
docker save ${CONTAINER_IMAGE} | gzip > forensics/container-image-${TIMESTAMP}.tar.gz
```

**Investigation**:

```bash
# 1. Determine exfiltration method
curl -s "http://kibana:5601/..." | jq '.process, .network_protocol'

# 2. What data was sent?
# - Database dumps?
# - Application secrets?
# - Customer PII?
# - Financial records?

# 3. Determine sensitivity
☐ Update incident classification (may become breach notification)
☐ Notify Legal and Compliance
☐ Prepare regulatory notification if required

# 4. Timeline reconstruction
Elasticsearch search:
{
  "query": {
    "bool": {
      "must": [
        {"match": {"container_id": "${CONTAINER_ID}"}},
        {"range": {"timestamp": {"gte": "now-1h"}}}
      ]
    }
  }
}

# 5. Connection analysis
tcpdump -r /forensics/network-capture.pcap -X | grep -A 20 "POST|GET"
```

**Remediation & Notification**:

```bash
# 1. Determine if customer data compromised
☐ Review data transfer contents
☐ Identify number of records exposed
☐ Assess sensitivity level

# 2. Regulatory notification requirements
PCI-DSS:
  - Card data: Notify processor/acquirer immediately
  - Timeline: Within 30 days to customers

HIPAA:
  - PHI: Notify affected individuals
  - Timeline: No later than 60 calendar days

GDPR (if applicable):
  - Personal data: Notify DPA within 72 hours
  - Notify individuals without undue delay

# 3. Breach notification process
☐ Legal review of required notifications
☐ Prepare notification templates
☐ Send notifications
☐ Document all notification activities

# 4. Remediation
☐ Identify compromised credentials → rotate them
☐ Change database passwords
☐ Reset API keys
☐ Check for lateral movement
☐ Implement IDS/IPS rules for similar patterns
```

### Type 4: Privilege Escalation

**Detection**: Falco rule "Privilege Escalation - Unauthorized sudo" triggers

**Procedure**:

```bash
# Similar flow:
# 1. Identify user and target privilege level
# 2. Determine if escalation succeeded
# 3. Check what was executed with elevated privileges
# 4. Investigate business justification
# 5. If legitimate: update whitelist + rules
# 6. If unauthorized:
#    ☐ Suspend user account
#    ☐ Force password reset
#    ☐ Review user actions before/after escalation
#    ☐ Audit other systems for unauthorized access
```

---

## Containment Procedures

### Automatic Containment (CRITICAL Alerts)

When CRITICAL alert triggered:

```yaml
# Automatically executed by response automation:
actions:
  - isolate_network:
      disconnect_all_networks: true
      preserve_access_for_forensics: true

  - preserve_evidence:
      container_snapshot: /forensics/container-${ID}.tar.gz
      process_list: /forensics/processes-${ID}.txt
      network_connections: /forensics/netstat-${ID}.txt
      open_files: /forensics/lsof-${ID}.txt

  - kill_process:
      graceful_timeout: 5s
      force_kill_timeout: 10s

  - alert_team:
      channels: [slack, pagerduty, email]
      escalation: cto, ciso

  - create_incident:
      severity: CRITICAL
      auto_assign: security_lead
```

### Manual Containment (HIGH Alerts)

Security team approval required:

```bash
# Step 1: Decision Point
echo "Alert: $ALERT_NAME"
echo "Affected: $CONTAINER_ID ($IMAGE)"
echo "Evidence: Contained in $EVIDENCE_PATH"
read -p "Approve containment? (yes/no): " APPROVAL

if [ "$APPROVAL" = "yes" ]; then
  # Step 2: Isolate
  docker network disconnect bridge ${CONTAINER_ID}
  docker pause ${CONTAINER_ID}  # Preserve for forensics

  # Step 3: Verify isolation
  docker exec ${CONTAINER_ID} ping 8.8.8.8  # Should fail
  docker logs ${CONTAINER_ID} | tail  # Capture final state

  # Step 4: Preserve and kill
  docker commit ${CONTAINER_ID} forensics/${CONTAINER_ID}:preserved
  docker kill ${CONTAINER_ID}
fi
```

---

## Investigation & Forensics

### Evidence Collection Checklist

```
Container Forensics (within 5 minutes of incident):

System Information:
☐ Container ID and full name
☐ Image name and SHA256
☐ Container creation time
☐ Container start time
☐ Resource limits (CPU, memory)

Process Information:
☐ Triggered process name and arguments
☐ Parent process details
☐ User/UID that executed process
☐ Exit code and termination signal
☐ Process execution timeline

File System:
☐ Container filesystem snapshot
☐ Modified files since creation
☐ Sensitive file access history
☐ File hashes (SHA256) for comparison

Network:
☐ Established connections at incident time
☐ Listening ports
☐ Network interface stats
☐ DNS query history (if available)

Logs:
☐ Container STDOUT/STDERR logs
☐ Falco alerts (past 1 hour)
☐ System logs (syslog entries)
☐ Application logs
```

### Elasticsearch Forensic Queries

```bash
# Query 1: All events for container in time window
curl -X POST "http://localhost:9200/falco-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d'{
    "query": {
      "bool": {
        "must": [
          {"match": {"container_id": "'${CONTAINER_ID}'"}},
          {"range": {"timestamp": {"gte": "'${START_TIME}'", "lte": "'${END_TIME}'"}}}
        ]
      }
    },
    "size": 10000,
    "sort": [{"timestamp": {"order": "asc"}}]
  }' | jq '.hits.hits[] | {timestamp: ._source.timestamp, rule: ._source.rule, user: ._source.user}'

# Query 2: Privilege escalation attempts
curl -X POST "http://localhost:9200/falco-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d'{
    "query": {
      "match": {"rule": "Privilege Escalation"}
    },
    "aggs": {
      "by_container": {
        "terms": {"field": "container_id", "size": 100}
      }
    }
  }'

# Query 3: Network exfiltration patterns
curl -X POST "http://localhost:9200/falco-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d'{
    "query": {
      "range": {
        "bytes_transmitted": {"gte": 100000000}
      }
    },
    "aggs": {
      "top_destinations": {
        "terms": {"field": "destination_ip", "size": 10}
      }
    }
  }'
```

---

## Remediation

### Post-Incident Recovery Steps

```
Phase 1: Immediate (0-1 hour)
☐ Incident contained and verified
☐ Evidence preserved and locked down
☐ Affected systems isolated
☐ Root cause identified (initial assessment)
☐ Decision: Continue investigation or proceed to recovery?

Phase 2: Investigation (1-24 hours)
☐ Full forensic analysis completed
☐ Scope of compromise determined
☐ Affected data identified
☐ Method of initial compromise understood
☐ Lateral movement assessed
☐ Regulatory/breach determination made

Phase 3: Recovery (1-7 days)
☐ Vulnerable components patched/rebuilt
☐ Affected images removed from registry
☐ New images scanned and approved
☐ Systems redeployed with fixes
☐ Data restored from backups (if affected)
☐ Verification testing completed

Phase 4: Hardening (1-30 days)
☐ New detection rules deployed
☐ Configuration hardening implemented
☐ Access controls strengthened
☐ Monitoring enhanced
☐ Security awareness training provided
```

---

## Communication & Escalation

### Escalation Matrix

```
Time Elapsed | Action | Who to Notify
─────────────┼─────────┼──────────────────────
5 min        | Initial triage complete | Incident Commander
15 min       | Investigation status | CTO (if P1), Security Lead (if P2+)
30 min       | Severity confirmed | Legal & Compliance (if breach risk)
1 hour       | Root cause identified | Business unit leads
4 hours      | Remediation plan | Executive steering committee (if P1)
24 hours     | Full remediation plan | Board (if material breach)
```

### Notification Templates

```
# SLACK MESSAGE - CRITICAL ALERT

🚨 CRITICAL SECURITY INCIDENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alert: Container Escape Attempt
Container: production-api-01 (image: api:v2.3.1)
Time: 2025-11-19 14:32:15 UTC
Status: CONTAINED

Actions Taken:
✓ Container isolated
✓ Evidence preserved
✓ Incident ticket: SEC-2025-0847

Response Team:
- Incident Commander: John Security
- Investigation Lead: Sarah Forensics

Next Update: 15:00 UTC (28 minutes)

<Join War Room: https://meet.company.com/ir-2025-0847>
<View Details: http://kibana:5601/d/incident-2025-0847>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Post-Incident Review

### Incident Report Contents

```
1. Executive Summary
   - What happened
   - When and where
   - Business impact
   - Incident classification

2. Timeline
   - Initial detection
   - Containment actions
   - Investigation progress
   - Resolution

3. Root Cause Analysis
   - What allowed the incident
   - Why current controls failed
   - Contributing factors

4. Impact Assessment
   - Data compromised
   - Systems affected
   - Customer impact
   - Regulatory implications

5. Remediation Actions
   - What was fixed
   - Verification testing
   - Timeline for full resolution

6. Preventive Measures
   - New detection rules
   - Control improvements
   - Policy changes
   - Training implemented

7. Lessons Learned
   - What went well
   - What could improve
   - Process improvements
   - Investment recommendations
```

### Post-Incident Meeting (Hold within 24 hours)

```
Attendees:
- Incident Commander
- All response team members
- Security leadership
- Affected business units

Agenda (60 minutes):
1. Incident overview (10 min)
2. Timeline review (15 min)
3. Root cause discussion (15 min)
4. Process improvement (15 min)
5. Action items and owners (5 min)

Outputs:
- Incident report (SEC-YYYY-XXXX)
- Action items tracked in Jira
- Training/awareness updates
- Control improvements scheduled
```

---

## Contact Directory

### On-Call Schedule

```
Security Team (24/7):
- Incident Commander (rotation)
- Primary: +1-XXX-XXX-XXXX
- Backup: +1-XXX-XXX-XXXX
- Slack: @security-oncall

Escalation:
- CTO: cto@company.com
- CISO: ciso@company.com
- Legal: legal@company.com
- Communications: comms@company.com
```

### External Contacts

```
Law Enforcement:
- FBI Cyber Division: tips.fbi.gov
- Local law enforcement: 911 (emergency)

Breach Notification:
- State AG offices: Check jurisdiction
- Credit bureaus: Equifax, Experian, TransUnion

Professional Services:
- Forensics firm: [Contract info]
- Legal counsel: [Law firm info]
- Insurance broker: [Broker info]
```

---

## Appendix: Quick Reference

### Critical Command Cheat Sheet

```bash
# View recent Falco alerts
docker exec falco tail -100f /var/log/falco/alerts.json

# Search incident in Elasticsearch
curl -s "http://elasticsearch:9200/falco-*/_search?q=container_id:${ID}" | jq

# Isolate container
docker network disconnect bridge ${CONTAINER_ID}

# Preserve evidence
docker commit ${CONTAINER_ID} forensics/container-${TIMESTAMP}:latest

# Incident ticket
# SEC-YYYY-XXXX (auto-created)

# War room
# https://meet.company.com/incident (auto-created for P1)

# Status page update
# incidents.company.com/create
```

### Key Metrics During Incident

- **Detection Latency**: < 2 seconds (CRITICAL)
- **Containment Time**: < 15 minutes from alert
- **Investigation Completion**: < 4 hours
- **Evidence Preservation Rate**: 100%
- **False Positive Rate**: Target < 8%

---

**Last Updated**: November 19, 2025
**Next Review**: November 19, 2026
**Owner**: Enterprise Security Team

