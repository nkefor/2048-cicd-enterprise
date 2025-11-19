#!/bin/bash
set -e

# Cloud Resume Challenge - Local Testing Script

echo "========================================"
echo "Running Local Tests"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test Lambda function
echo "Testing Lambda function..."
cd src/lambda

# Install dependencies
pip install -r requirements.txt -q

# Run tests
pytest tests/ -v --cov=visitor_counter --cov-report=term-missing

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Lambda tests passed${NC}"
else
    echo -e "${RED}❌ Lambda tests failed${NC}"
    exit 1
fi

# Run linting
echo ""
echo "Running linting..."
flake8 visitor_counter.py --max-line-length=120 --ignore=E203,W503

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Linting passed${NC}"
else
    echo -e "${RED}❌ Linting failed${NC}"
    exit 1
fi

# Run security scan
echo ""
echo "Running security scan..."
bandit -r visitor_counter.py

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Security scan passed${NC}"
else
    echo -e "${RED}⚠️  Security issues found${NC}"
fi

cd ../..

# Validate Terraform
echo ""
echo "Validating Terraform..."
cd terraform
terraform init -backend=false
terraform validate

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform validation passed${NC}"
else
    echo -e "${RED}❌ Terraform validation failed${NC}"
    exit 1
fi

cd ..

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All tests passed!${NC}"
echo -e "${GREEN}========================================${NC}"
