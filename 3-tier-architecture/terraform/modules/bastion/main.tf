# Bastion Host Instance
resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true

  iam_instance_profile = var.iam_instance_profile

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    hostname = "${var.project_name}-bastion-${var.environment}"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-bastion-${var.environment}"
    Role = "Bastion"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP for Bastion (optional but recommended)
resource "aws_eip" "bastion" {
  count = var.allocate_eip ? 1 : 0

  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-bastion-eip-${var.environment}"
  }

  depends_on = [aws_instance.bastion]
}

# CloudWatch Log Group for Bastion
resource "aws_cloudwatch_log_group" "bastion" {
  name              = "/aws/ec2/${var.project_name}-bastion-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-bastion-logs-${var.environment}"
  }
}

# CloudWatch Alarm for Bastion CPU
resource "aws_cloudwatch_metric_alarm" "bastion_cpu" {
  alarm_name          = "${var.project_name}-bastion-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors bastion CPU utilization"

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }
}

# CloudWatch Alarm for Bastion Status Check
resource "aws_cloudwatch_metric_alarm" "bastion_status_check" {
  alarm_name          = "${var.project_name}-bastion-status-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors bastion status checks"

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }
}
