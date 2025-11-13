#!/bin/bash
set -euo pipefail

# Only run in Claude Code remote environments (web)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "🚀 Setting up 2048 CI/CD Enterprise development environment..."

# Update package lists (continue even if it fails)
echo "📦 Updating package lists..."
apt-get update -qq 2>/dev/null || echo "⚠️  Could not update all repositories, continuing..."

# Install Docker
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker..."
  apt-get install -y -qq docker.io docker-compose 2>/dev/null || {
    echo "⚠️  Failed to install via apt, trying alternative method..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh > /dev/null 2>&1
    rm /tmp/get-docker.sh
  }
  # Start Docker service if not running
  service docker start 2>/dev/null || true
else
  echo "✅ Docker already installed"
fi

# Install Terraform
if ! command -v terraform &> /dev/null; then
  echo "🏗️  Installing Terraform..."
  # Download and install Terraform binary directly
  TERRAFORM_VERSION="1.9.8"
  wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -O /tmp/terraform.zip
  unzip -q /tmp/terraform.zip -d /tmp
  mv /tmp/terraform /usr/local/bin/
  chmod +x /usr/local/bin/terraform
  rm /tmp/terraform.zip
else
  echo "✅ Terraform already installed"
fi

# Install AWS CLI v2
if ! command -v aws &> /dev/null; then
  echo "☁️  Installing AWS CLI..."
  # Try downloading AWS CLI installer
  if curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && [ -f "/tmp/awscliv2.zip" ]; then
    if unzip -q /tmp/awscliv2.zip -d /tmp 2>/dev/null; then
      /tmp/aws/install > /dev/null 2>&1 || echo "⚠️  AWS CLI installation completed with warnings"
      rm -rf /tmp/aws /tmp/awscliv2.zip
    else
      echo "⚠️  Failed to extract AWS CLI, trying apt..."
      rm -f /tmp/awscliv2.zip
      apt-get install -y -qq awscli 2>/dev/null || echo "⚠️  Could not install AWS CLI"
    fi
  else
    echo "⚠️  Failed to download AWS CLI, trying apt..."
    apt-get install -y -qq awscli 2>/dev/null || echo "⚠️  Could not install AWS CLI"
  fi
else
  echo "✅ AWS CLI already installed"
fi

# Verify installations
echo ""
echo "✅ Development environment ready!"
echo ""
echo "Installed versions:"
docker --version 2>/dev/null || echo "  Docker: Not available"
terraform --version | head -1 2>/dev/null || echo "  Terraform: Not available"
aws --version 2>/dev/null || echo "  AWS CLI: Not available"
echo ""
echo "🎮 Ready to build and deploy the 2048 game platform!"
