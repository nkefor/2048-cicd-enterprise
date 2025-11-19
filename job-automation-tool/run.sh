#!/bin/bash
# Job Automation Tool - Quick Start Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Job Application Automation Tool${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check Python version
echo -e "${BLUE}Checking Python version...${NC}"
python_version=$(python3 --version 2>&1 | awk '{print $2}')
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo -e "${RED}Error: Python 3.8 or higher required (found $python_version)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python $python_version${NC}"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate virtual environment
echo -e "${BLUE}Activating virtual environment...${NC}"
source venv/bin/activate

# Install dependencies
if [ ! -f "venv/installed.flag" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pip install --upgrade pip
    pip install -r requirements.txt
    touch venv/installed.flag
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# Check if config.json exists
if [ ! -f "config.json" ]; then
    echo -e "${YELLOW}Configuration file not found!${NC}"
    echo -e "${YELLOW}Creating config.json from template...${NC}"
    cp config.example.json config.json
    echo -e "${GREEN}✓ config.json created${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Edit config.json with your information before running!${NC}"
    echo -e "${YELLOW}  nano config.json${NC}"
    echo ""
    read -p "Press Enter to continue after editing config.json..."
fi

# Create data directories
echo -e "${BLUE}Creating data directories...${NC}"
mkdir -p data/logs
mkdir -p data/screenshots
mkdir -p data/backups
echo -e "${GREEN}✓ Directories created${NC}"

# Parse command line arguments
MODE="run"
if [ "$1" = "dashboard" ]; then
    MODE="dashboard"
elif [ "$1" = "test" ]; then
    MODE="test"
fi

echo ""
echo -e "${BLUE}======================================${NC}"

if [ "$MODE" = "dashboard" ]; then
    echo -e "${GREEN}Starting Monitoring Dashboard...${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo -e "Dashboard will be available at: ${GREEN}http://localhost:5000${NC}"
    echo ""
    python3 dashboard/app.py
elif [ "$MODE" = "test" ]; then
    echo -e "${GREEN}Running Tests...${NC}"
    echo -e "${BLUE}======================================${NC}"
    pytest tests/ -v --cov=core --cov=platforms --cov=utils
else
    echo -e "${GREEN}Starting Job Automation Bot...${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    python3 main.py "$@"
fi

# Deactivate virtual environment
deactivate
