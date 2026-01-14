# Train Schedule Application

A modern, containerized Node.js application demonstrating enterprise CI/CD practices with Docker, GitHub Actions, and AWS ECS Fargate.

## Overview

This train schedule application displays real-time train departure information and serves as a demonstration of:
- **Containerized Node.js applications**
- **Multi-stage Docker builds**
- **Security best practices** (non-root user, minimal base image)
- **Health check endpoints**
- **Production-ready Express.js server**
- **Automated CI/CD deployment**

## Features

- 🚂 Real-time train schedule display
- 📊 RESTful API endpoint (`/api/trains`)
- ❤️ Health check endpoint (`/health`)
- 🎨 Responsive, modern UI
- 🔄 Auto-refresh functionality
- 🐳 Docker-optimized for production
- ✅ Security-hardened container

## Technology Stack

- **Runtime**: Node.js 18 (Alpine)
- **Framework**: Express.js
- **Template Engine**: EJS
- **Container**: Docker (multi-stage build)
- **Process Manager**: dumb-init (proper signal handling)

## Local Development

### Prerequisites

- Node.js 18+
- Docker (optional, for container testing)

### Running Locally

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Access at http://localhost:3000
```

### Running with Docker

```bash
# Build image
docker build -t train-schedule:latest .

# Run container
docker run -p 3000:3000 train-schedule:latest

# Access at http://localhost:3000
```

## API Endpoints

### GET /
Main train schedule web interface

### GET /api/trains
Returns JSON data of all trains
```json
{
  "trains": [
    {
      "trainNumber": "EXP-101",
      "destination": "New York",
      "departure": "08:00 AM",
      "arrival": "12:30 PM",
      "platform": "1A",
      "status": "On Time"
    }
  ],
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### GET /health
Health check endpoint for container orchestration
```json
{
  "status": "healthy",
  "uptime": 123.456,
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

## Docker Configuration

### Image Optimization
- **Multi-stage build**: Separates build and runtime stages
- **Alpine Linux**: Minimal base image (~50MB total)
- **Non-root user**: Runs as nodejs:nodejs (UID 1001)
- **Layer caching**: Optimized for fast rebuilds

### Security Features
- ✅ Non-root user execution
- ✅ Security updates applied
- ✅ Minimal attack surface (Alpine)
- ✅ Health checks configured
- ✅ Proper signal handling (dumb-init)
- ✅ No unnecessary packages

### Health Checks
- **Interval**: Every 30 seconds
- **Timeout**: 3 seconds
- **Start Period**: 10 seconds (grace period)
- **Retries**: 3 attempts before marking unhealthy

## CI/CD Integration

This application is designed to integrate with GitHub Actions and AWS ECS Fargate:

1. **Build**: Docker image built on code push
2. **Scan**: Security vulnerability scanning
3. **Push**: Image pushed to Amazon ECR
4. **Deploy**: ECS service updated automatically
5. **Health**: Health checks verify deployment

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| `NODE_ENV` | `production` | Node environment |

## Production Deployment

### ECS Fargate Configuration

**Recommended Task Size**:
- vCPU: 0.25 (minimum for Node.js)
- Memory: 0.5 GB

**Container Configuration**:
```json
{
  "portMappings": [
    {
      "containerPort": 3000,
      "protocol": "tcp"
    }
  ],
  "healthCheck": {
    "command": ["CMD-SHELL", "node -e \"require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))\""],
    "interval": 30,
    "timeout": 3,
    "retries": 3,
    "startPeriod": 10
  }
}
```

## Testing

```bash
# Run tests (when implemented)
npm test

# Test Docker build
docker build -t train-schedule:test .

# Test container locally
docker run -d -p 3000:3000 --name test-train train-schedule:test
curl http://localhost:3000/health
docker rm -f test-train
```

## Troubleshooting

### Container won't start
- Check logs: `docker logs <container-id>`
- Verify health endpoint: `curl http://localhost:3000/health`
- Ensure port 3000 is available

### Health checks failing
- Verify application is listening on port 3000
- Check if `/health` endpoint returns 200 status
- Review ECS task logs in CloudWatch

### High memory usage
- Monitor with: `docker stats <container-id>`
- Consider increasing task memory allocation
- Review application for memory leaks

## Performance

**Metrics**:
- Container startup time: ~5 seconds
- Memory usage: ~50-80 MB
- Image size: ~90 MB
- Response time: <50ms (health endpoint)

## Security

**Container Security**:
- Non-root user (nodejs:1001)
- Read-only compatible
- No privileged operations
- Minimal package footprint

**Application Security**:
- No sensitive data exposure
- Input validation on API endpoints
- Security headers (can be added)
- CORS configured (can be added)

## License

MIT License - See LICENSE file for details

## Contributing

This is a demo application. For production use, consider:
- Adding authentication
- Implementing rate limiting
- Adding comprehensive testing
- Configuring CORS policies
- Adding logging middleware
- Implementing monitoring
