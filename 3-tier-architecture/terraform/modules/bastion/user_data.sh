#!/bin/bash
set -e

# Update system
yum update -y

# Set hostname
hostnamectl set-hostname ${hostname}

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm -f ./amazon-cloudwatch-agent.rpm

# Install SSM agent (usually pre-installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install useful tools
yum install -y htop vim git tmux

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/${hostname}",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/${hostname}",
            "log_stream_name": "{instance_id}/secure"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MemoryUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DiskUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Configure SSH banner
cat > /etc/ssh/banner << 'EOF'
################################################################################
#                                                                              #
#                           BASTION HOST                                       #
#                                                                              #
#  WARNING: Unauthorized access to this system is forbidden and will be       #
#  prosecuted by law. By accessing this system, you agree that your actions   #
#  may be monitored if unauthorized usage is suspected.                       #
#                                                                              #
################################################################################
EOF

echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
systemctl restart sshd

# Create motd
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                         BASTION HOST                             ║
║                                                                  ║
║  This is a jump server for secure access to private instances   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF

echo "Bastion host configuration complete"
