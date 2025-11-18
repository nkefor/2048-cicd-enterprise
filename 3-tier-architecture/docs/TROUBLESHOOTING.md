## Troubleshooting Guide - 3-Tier Architecture

Comprehensive guide for diagnosing and resolving common issues.

---

## Quick Diagnostics

### Run Health Check Script

```bash
./scripts/health-check.sh
```

This checks:
- VPC and networking
- Load balancer health
- Auto Scaling Group status
- Database availability
- Bastion accessibility
- CloudWatch alarms
- Security groups

---

## Common Issues

### 1. Terraform Issues

#### Issue: "Error locking state"

**Symptom**:
```
Error: Error locking state: Error acquiring the state lock
```

**Cause**: Previous Terraform operation didn't complete cleanly

**Solution**:
```bash
# View locks
aws dynamodb scan --table-name terraform-locks

# Force unlock (use lock ID from error message)
terraform force-unlock LOCK_ID

# Or delete stuck lock from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"3-tier-architecture/dev/terraform.tfstate"}}'
```

---

#### Issue: "No valid credential sources found"

**Symptom**:
```
Error: No valid credential sources found for AWS Provider
```

**Solution**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# If fails, reconfigure
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_REGION=us-east-1
```

---

#### Issue: Terraform apply fails with "already exists"

**Symptom**:
```
Error: Error creating VPC: VpcLimitExceeded
```

**Solution**:
```bash
# Import existing resource
terraform import aws_vpc.main vpc-xxxxx

# Or delete existing resource first
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=3tier-app-vpc-dev"
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

---

### 2. Application Load Balancer Issues

#### Issue: ALB returns 503 Service Unavailable

**Symptom**: HTTP 503 when accessing ALB DNS

**Diagnosis**:
```bash
cd terraform
ALB_ARN=$(terraform output -raw alb_arn)
TG_ARN=$(terraform output -raw target_group_arn)

# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

**Possible Causes & Solutions**:

1. **No healthy targets**
   ```bash
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn $TG_ARN

   # Common fixes:
   # - Wait for instances to pass health checks (2-3 minutes)
   # - Check security group allows traffic from ALB
   # - Verify application is running on instances
   # - Check health check path exists (/health)
   ```

2. **Health check failing**
   ```bash
   # SSH to instance via bastion
   BASTION_IP=$(terraform output -raw bastion_public_ip)
   ssh -i ~/.ssh/your-key.pem ec2-user@$BASTION_IP

   # From bastion, get app server IP
   PRIVATE_IP=$(aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=*app*" "Name=instance-state-name,Values=running" \
     --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

   # SSH to app server
   ssh ec2-user@$PRIVATE_IP

   # Check if httpd is running
   sudo systemctl status httpd

   # Check if health endpoint exists
   curl http://localhost/health

   # Check logs
   sudo tail -f /var/log/httpd/error_log
   ```

3. **Security group blocking traffic**
   ```bash
   # Check ALB security group
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=*alb*" \
     --query 'SecurityGroups[*].IpPermissions'

   # Check app security group allows traffic from ALB
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=*app*" \
     --query 'SecurityGroups[*].IpPermissions'
   ```

---

#### Issue: ALB timeout errors

**Symptom**: Request timeout or 504 Gateway Timeout

**Solution**:
```bash
# Check target group timeout settings
aws elbv2 describe-target-groups --target-group-arns $TG_ARN

# Increase timeout if needed (via Terraform)
# In modules/compute/main.tf, modify health_check.timeout

# Check application response time
curl -w "\nTime: %{time_total}s\n" http://$(terraform output -raw alb_dns_name)
```

---

### 3. Auto Scaling Group Issues

#### Issue: Instances keep terminating

**Diagnosis**:
```bash
ASG_NAME=$(terraform output -raw asg_name)

# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 20

# Check instance health
aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`'$ASG_NAME'`]'
```

**Common Causes**:
1. Health checks failing - see ALB issues above
2. Insufficient capacity - check AWS service limits
3. Incorrect user data - check /var/log/cloud-init-output.log
4. IAM role issues - verify EC2 can access required services

**Solutions**:
```bash
# Suspend health check temporarily
aws autoscaling suspend-processes \
  --auto-scaling-group-name $ASG_NAME \
  --scaling-processes HealthCheck

# Check instance logs
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
  "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Get system log
aws ec2 get-console-output --instance-id $INSTANCE_ID

# Resume health checks when fixed
aws autoscaling resume-processes \
  --auto-scaling-group-name $ASG_NAME \
  --scaling-processes HealthCheck
```

---

#### Issue: Auto Scaling not working

**Symptom**: Instances not scaling up/down despite alarms

**Diagnosis**:
```bash
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name $ASG_NAME

# Check if scaling is suspended
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query 'AutoScalingGroups[0].SuspendedProcesses'

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix "3tier-app-cpu"
```

**Solutions**:
```bash
# Resume all processes
aws autoscaling resume-processes \
  --auto-scaling-group-name $ASG_NAME

# Manually trigger scaling for testing
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 3
```

---

### 4. Database Issues

#### Issue: Can't connect to RDS from application

**Symptom**: Application shows database connection errors

**Diagnosis**:
```bash
cd terraform
DB_ENDPOINT=$(terraform output -raw db_endpoint)

# Test from bastion
ssh -i ~/.ssh/your-key.pem ec2-user@$BASTION_IP

# Install MySQL client if needed
sudo yum install -y mysql

# Test connection
mysql -h $DB_ENDPOINT -u admin -p
```

**Common Causes & Solutions**:

1. **Security group not allowing traffic**
   ```bash
   # Check database security group
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=*db*" \
     --query 'SecurityGroups[*].[GroupId,IpPermissions]'

   # Should allow port 3306 from app security group
   ```

2. **Wrong credentials**
   ```bash
   # Verify credentials match what's in Terraform
   # Check DB_PASSWORD environment variable
   echo $DB_PASSWORD

   # Reset password if needed (via AWS Console or CLI)
   aws rds modify-db-instance \
     --db-instance-identifier 3tier-app-dev \
     --master-user-password 'NewPassword123!' \
     --apply-immediately
   ```

3. **Database not available**
   ```bash
   # Check RDS status
   aws rds describe-db-instances \
     --db-instance-identifier 3tier-app-dev \
     --query 'DBInstances[0].DBInstanceStatus'

   # Wait for status to be 'available'
   ```

---

#### Issue: RDS running out of storage

**Symptom**: Database errors, slow performance

**Diagnosis**:
```bash
# Check storage metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=3tier-app-dev \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions**:
```bash
# Increase storage (modify Terraform variable)
cd terraform
terraform apply -var="db_allocated_storage=50"

# Enable auto-scaling (already configured in code)
# Check max_allocated_storage in database module
```

---

### 5. Networking Issues

#### Issue: Instances can't reach internet

**Symptom**: yum install fails, can't download packages

**Diagnosis**:
```bash
# Check NAT Gateway
VPC_ID=$(terraform output -raw vpc_id)
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].[NatGatewayId,State]'

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[*].[RouteTableId,Routes]'
```

**Solutions**:
```bash
# Verify NAT Gateway has Elastic IP
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].NatGatewayAddresses'

# Check private subnet route table points to NAT
# Should have route 0.0.0.0/0 -> nat-xxxxx
```

---

#### Issue: VPC Flow Logs not working

**Diagnosis**:
```bash
# Check Flow Logs
aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=$VPC_ID"

# Check CloudWatch Log Group
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/vpc"
```

**Solution**:
```bash
# Verify IAM role has correct permissions
# Check modules/vpc/main.tf for flow log configuration
```

---

### 6. Bastion Host Issues

#### Issue: Can't SSH to bastion

**Symptom**: Connection timeout or refused

**Diagnosis**:
```bash
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Test connectivity
ping -c 3 $BASTION_IP

# Check if SSH port is open
nc -zv $BASTION_IP 22

# Check security group
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*bastion*" \
  --query 'Reservations[0].Instances[0].SecurityGroups'
```

**Solutions**:

1. **Security group doesn't allow your IP**
   ```bash
   MY_IP=$(curl -s ifconfig.me)
   SG_ID=$(aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=*bastion*" \
     --query 'SecurityGroups[0].GroupId' --output text)

   aws ec2 authorize-security-group-ingress \
     --group-id $SG_ID \
     --protocol tcp \
     --port 22 \
     --cidr $MY_IP/32
   ```

2. **Wrong SSH key**
   ```bash
   # Verify key name matches
   terraform output | grep key_name

   # Use correct key
   ssh -i ~/.ssh/correct-key.pem ec2-user@$BASTION_IP
   ```

3. **Bastion instance stopped**
   ```bash
   # Check instance state
   INSTANCE_ID=$(terraform output -raw bastion_instance_id)
   aws ec2 describe-instances --instance-ids $INSTANCE_ID \
     --query 'Reservations[0].Instances[0].State'

   # Start if stopped
   aws ec2 start-instances --instance-ids $INSTANCE_ID
   ```

---

### 7. Ansible Issues

#### Issue: No hosts matched

**Symptom**:
```
ERROR! Specified hosts and/or --limit does not match any hosts
```

**Diagnosis**:
```bash
cd ansible

# Check inventory
ansible-inventory -i inventory/aws_ec2.yml --list

# Check AWS credentials
aws sts get-caller-identity
```

**Solutions**:
```bash
# Verify instances are tagged correctly
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=3-Tier-Architecture" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags]'

# Update inventory cache
rm -rf /tmp/ansible_*
ansible-inventory -i inventory/aws_ec2.yml --list > /dev/null

# Test connection
ansible all -i inventory/aws_ec2.yml -m ping
```

---

#### Issue: SSH connection failed

**Symptom**: "Failed to connect to the host via ssh"

**Solutions**:
```bash
# Use bastion as jump host
# Update ansible.cfg:
[ssh_connection]
ssh_args = -o ProxyCommand="ssh -W %h:%p -q ec2-user@BASTION_IP"

# Or use SSH config
cat >> ~/.ssh/config <<EOF
Host bastion
  HostName $BASTION_IP
  User ec2-user
  IdentityFile ~/.ssh/your-key.pem

Host 10.0.*.*
  ProxyJump bastion
  User ec2-user
  IdentityFile ~/.ssh/your-key.pem
EOF
```

---

### 8. Performance Issues

#### Issue: High latency

**Diagnosis**:
```bash
# Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/3tier-app-alb-dev/xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Check instance CPU
ASG_NAME=$(terraform output -raw asg_name)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

**Solutions**:
```bash
# Scale up instances
terraform apply -var="asg_desired_capacity=4"

# Use larger instance type
terraform apply -var="app_instance_type=t3.medium"

# Enable caching (application-level)
# Add CloudFront CDN
# Optimize database queries
```

---

### 9. Cost Issues

#### Issue: Unexpected high costs

**Diagnosis**:
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE

# Run cost calculator
./scripts/cost-calculator.sh dev
```

**Common Cost Drivers**:
1. NAT Gateway data processing (~$0.045/GB)
2. Running instances 24/7
3. Large EBS volumes
4. Data transfer out

**Solutions**:
```bash
# For dev environment only:

# 1. Use single NAT Gateway
terraform apply -var="enable_nat_gateway=true" -var="az_count=1"

# 2. Auto-shutdown non-prod after hours
# Add to Lambda or use AWS Instance Scheduler

# 3. Use Spot Instances (for non-prod)
# Modify launch template in compute module

# 4. Right-size instances
terraform apply -var="app_instance_type=t3.small"
```

---

## Disaster Recovery

### Restore from Backup

```bash
# List RDS snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier 3tier-app-dev \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]'

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier 3tier-app-dev-restored \
  --db-snapshot-identifier rds:3tier-app-dev-2024-01-01-00-00

# Point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier 3tier-app-dev \
  --target-db-instance-identifier 3tier-app-dev-restored \
  --restore-time 2024-01-01T00:00:00Z
```

---

## Getting Help

### Collect Diagnostic Information

```bash
# Run health check
./scripts/health-check.sh > health-check-output.txt

# Get Terraform state
cd terraform
terraform show > terraform-state.txt

# Get CloudWatch logs
aws logs tail /aws/ec2/dev/httpd --since 1h > application-logs.txt

# Get instance system logs
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*app*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ec2 get-console-output --instance-id $INSTANCE_ID > instance-console.txt
```

### Contact Support

Include:
- Output from health-check.sh
- Terraform state (redact sensitive info)
- CloudWatch logs
- Error messages
- What you've tried

---

## Prevention

### Best Practices

1. **Always use deployment script**
   ```bash
   ./scripts/deploy.sh check  # Before deploy
   ./scripts/health-check.sh   # After deploy
   ```

2. **Enable monitoring**
   - Check CloudWatch dashboards daily
   - Set up SNS notifications for alarms
   - Review cost reports weekly

3. **Regular maintenance**
   ```bash
   # Patch monthly
   ansible-playbook -i inventory/aws_ec2.yml playbooks/patch.yml

   # Backup verification quarterly
   # Test disaster recovery annually
   ```

4. **Document changes**
   - Always use Terraform for infrastructure changes
   - Commit and push Terraform changes to Git
   - Document manual changes in runbook

---

## Quick Reference

### Essential Commands

```bash
# Health check
./scripts/health-check.sh

# Deploy
./scripts/deploy.sh deploy

# Scale
terraform apply -var="asg_desired_capacity=X"

# Patch
ansible-playbook -i inventory/aws_ec2.yml playbooks/patch.yml

# Costs
./scripts/cost-calculator.sh dev

# Destroy
./scripts/deploy.sh destroy
```

### Important URLs

- CloudWatch: `https://console.aws.amazon.com/cloudwatch`
- EC2 Instances: `https://console.aws.amazon.com/ec2/v2/home#Instances`
- RDS: `https://console.aws.amazon.com/rds/home#databases`
- Cost Explorer: `https://console.aws.amazon.com/cost-management/home`

---

**Remember**: When in doubt, check CloudWatch logs first! Most issues show up there.
