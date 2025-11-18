package terraform.security

# Deny public S3 buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.after.acl == "public-read"
    msg := sprintf("S3 bucket %v cannot be public (CIS 2.3)", [resource.address])
}

# Require S3 encryption
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf("S3 bucket %v must have encryption enabled", [resource.address])
}

has_encryption(resource) {
    resource.change.after.server_side_encryption_configuration
}

# Deny unrestricted SSH access
deny[msg] {
    sg := input.resource_changes[_]
    sg.type == "aws_security_group"
    rule := sg.change.after.ingress[_]
    rule.from_port <= 22
    rule.to_port >= 22
    rule.cidr_blocks[_] == "0.0.0.0/0"
    msg := sprintf("Security group %v allows unrestricted SSH (CIS 4.1)", [sg.address])
}

# Deny unrestricted RDP access
deny[msg] {
    sg := input.resource_changes[_]
    sg.type == "aws_security_group"
    rule := sg.change.after.ingress[_]
    rule.from_port <= 3389
    rule.to_port >= 3389
    rule.cidr_blocks[_] == "0.0.0.0/0"
    msg := sprintf("Security group %v allows unrestricted RDP (CIS 4.2)", [sg.address])
}

# Require RDS encryption
deny[msg] {
    db := input.resource_changes[_]
    db.type == "aws_db_instance"
    not db.change.after.storage_encrypted
    msg := sprintf("RDS instance %v must be encrypted", [db.address])
}

# Require VPC Flow Logs
deny[msg] {
    vpc := input.resource_changes[_]
    vpc.type == "aws_vpc"
    not has_flow_logs(vpc)
    msg := sprintf("VPC %v must have flow logs enabled (CIS 2.9)", [vpc.address])
}

has_flow_logs(vpc) {
    flow_log := input.resource_changes[_]
    flow_log.type == "aws_flow_log"
    flow_log.change.after.vpc_id == vpc.change.after.id
}
