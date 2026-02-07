# Project 4: Serverless Application & API Gateway - Build Guide

## What You Will Build

- **API Gateway** with 5 REST endpoints, API key auth, throttling, and CORS
- **5 Lambda functions**: health, get-scores, submit-score, leaderboard, processor, notifier
- **DynamoDB** table with GSI for leaderboard queries and Streams for event processing
- **SNS** topic for high-score notifications with email subscription
- **Event-driven pipeline**: score submitted -> DynamoDB Stream -> processor -> SNS -> notifier

## File Structure

```
serverless/
├── template.yaml                 # SAM/CloudFormation template
└── functions/
    ├── api/
    │   ├── health.js             # GET /health (no auth)
    │   └── scores.js             # GET/POST /scores, GET /scores/top
    ├── processor/
    │   └── index.js              # DynamoDB Stream consumer
    └── notifier/
        └── index.js              # SNS high-score notification
```

## Deploy

```bash
cd serverless

# Build
sam build

# Deploy (guided first time)
sam deploy --guided

# Subsequent deploys
sam deploy --parameter-overrides Environment=prod
```

## Test Locally

```bash
# Start local API
sam local start-api

# Health check
curl http://localhost:3000/health

# Submit a score
curl -X POST http://localhost:3000/scores \
  -H "Content-Type: application/json" \
  -d '{"playerId":"player1","playerName":"Alice","score":1024}'

# Get leaderboard
curl http://localhost:3000/scores/top?limit=10
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /health | None | Service health check |
| GET | /scores?playerId=X | API Key | Get player scores |
| POST | /scores | API Key | Submit a new score |
| GET | /scores/top?limit=N | API Key | Get leaderboard (max 100) |

## Event Flow

```
POST /scores → submit-score Lambda → DynamoDB PutItem
                                          │
                                    DynamoDB Stream
                                          │
                                    processor Lambda
                                    ├── Write GLOBAL leaderboard entry
                                    └── If score >= 2048 → SNS publish
                                                               │
                                                         notifier Lambda
                                                         └── Webhook / Log
```

## Cost (estimated idle)

| Resource | Monthly Cost |
|----------|-------------|
| API Gateway (100K requests) | ~$0.35 |
| Lambda (100K invocations) | ~$0.20 |
| DynamoDB (on-demand, light use) | ~$1.00 |
| SNS | ~$0.00 |
| CloudWatch Logs | ~$0.50 |
| **Total** | **~$2.05/month** |

---

*Last Updated: 2026-02-03*
