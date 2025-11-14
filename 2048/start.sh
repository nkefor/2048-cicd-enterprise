#!/bin/bash

# Secure 2048 Startup Script
# This script helps you start the application with proper configuration

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🔐 Secure 2048 Web Application                           ║"
echo "║  Startup Configuration                                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from template..."
    cp .env.example .env

    # Generate random session secret
    SESSION_SECRET=$(openssl rand -base64 48 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)

    # Update .env with generated secret
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/generate-a-long-random-secret-here-minimum-32-characters/$SESSION_SECRET/" .env
    else
        # Linux
        sed -i "s/generate-a-long-random-secret-here-minimum-32-characters/$SESSION_SECRET/" .env
    fi

    echo "✅ .env file created with random SESSION_SECRET"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file and set:"
    echo "   - ADMIN_PASSWORD (default: ChangeMe123!)"
    echo "   - DOMAIN (if using HTTPS)"
    echo "   - EMAIL (if using HTTPS)"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to exit and edit .env first..."
fi

# Ask user for deployment mode
echo "Select deployment mode:"
echo "1) Local Development (HTTP, localhost:3000)"
echo "2) Production with HTTPS (requires domain and public IP)"
echo "3) Docker (using docker-compose)"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo ""
        echo "🔧 Starting in DEVELOPMENT mode..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Update .env for development
        if grep -q "ENABLE_HTTPS=true" .env; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's/ENABLE_HTTPS=true/ENABLE_HTTPS=false/' .env
            else
                sed -i 's/ENABLE_HTTPS=true/ENABLE_HTTPS=false/' .env
            fi
        fi

        # Check if node_modules exists
        if [ ! -d "node_modules" ]; then
            echo "📦 Installing dependencies..."
            npm install
        fi

        echo ""
        echo "✅ Starting server..."
        npm start
        ;;

    2)
        echo ""
        echo "🚀 Starting in PRODUCTION mode with HTTPS..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Check if domain and email are set
        if ! grep -q "DOMAIN=yourdomain.com" .env && grep -q "EMAIL=your-email@example.com" .env; then
            echo "⚠️  DOMAIN and EMAIL must be configured in .env for HTTPS"
            echo ""
            read -p "Enter your domain (e.g., secure.example.com): " domain
            read -p "Enter your email: " email

            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/DOMAIN=yourdomain.com/DOMAIN=$domain/" .env
                sed -i '' "s/EMAIL=your-email@example.com/EMAIL=$email/" .env
                sed -i '' 's/ENABLE_HTTPS=false/ENABLE_HTTPS=true/' .env
            else
                sed -i "s/DOMAIN=yourdomain.com/DOMAIN=$domain/" .env
                sed -i "s/EMAIL=your-email@example.com/EMAIL=$email/" .env
                sed -i 's/ENABLE_HTTPS=false/ENABLE_HTTPS=true/' .env
            fi
        fi

        # Check if node_modules exists
        if [ ! -d "node_modules" ]; then
            echo "📦 Installing dependencies..."
            npm install
        fi

        echo ""
        echo "⚠️  IMPORTANT REQUIREMENTS:"
        echo "   - Your domain must point to this server's public IP"
        echo "   - Ports 80 and 443 must be open"
        echo "   - Server must be accessible from the internet"
        echo ""
        read -p "Are these requirements met? (y/N): " confirm

        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo ""
            echo "✅ Starting server with HTTPS..."
            echo "⏳ Let's Encrypt will issue certificate on first request..."
            node server-https.js
        else
            echo "❌ Aborting. Please meet requirements and try again."
            exit 1
        fi
        ;;

    3)
        echo ""
        echo "🐳 Starting with Docker Compose..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker is not installed. Please install Docker first."
            exit 1
        fi

        # Check if docker-compose is installed
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            echo "❌ Docker Compose is not installed. Please install Docker Compose first."
            exit 1
        fi

        echo "Building and starting containers..."
        docker-compose up --build
        ;;

    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac
