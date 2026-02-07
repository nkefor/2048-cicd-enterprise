# Project 4: Serverless Application & API Gateway - Architecture

## High-Level Architecture

```
    CLIENTS
    ═══════
    Browser / Mobile / CLI
         │
         v
    ╔═══════════════════════════════════════════════════════════════╗
    ║                    API GATEWAY (REST)                          ║
    ║                                                               ║
    ║  Routes:                                                      ║
    ║  ├── GET  /scores           → Lambda: get-scores             ║
    ║  ├── POST /scores           → Lambda: submit-score           ║
    ║  ├── GET  /scores/top       → Lambda: get-leaderboard        ║
    ║  ├── GET  /health           → Lambda: health-check           ║
    ║  └── POST /events           → Lambda: game-events            ║
    ║                                                               ║
    ║  Features:                                                    ║
    ║  ├── API Key authentication                                  ║
    ║  ├── Usage plans + throttling (100 req/s burst, 50 steady)   ║
    ║  ├── Request validation (JSON schema)                        ║
    ║  ├── CORS enabled                                            ║
    ║  └── CloudWatch access logging                               ║
    ╚═══════════════════╤═══════════════════════════════════════════╝
                        │
           ┌────────────┼────────────────┐
           │            │                │
           v            v                v
    ┌────────────┐ ┌──────────┐  ┌────────────┐
    │ API Lambda │ │ Process  │  │ Notifier   │
    │ Functions  │ │ Lambda   │  │ Lambda     │
    │            │ │          │  │            │
    │ get-scores │ │ Triggered│  │ Triggered  │
    │ submit     │ │ by DDB   │  │ by SNS     │
    │ leaderboard│ │ Streams  │  │            │
    │ health     │ │          │  │ Send email │
    │ events     │ │ Aggregate│  │ or webhook │
    └─────┬──────┘ └────┬─────┘  └────────────┘
          │              │
          v              v
    ┌──────────────────────────┐
    │      DynamoDB             │
    │                          │
    │  Table: game-2048-scores │
    │  PK: playerId            │
    │  SK: timestamp           │
    │  GSI: score-index        │
    │      (for leaderboard)   │
    │                          │
    │  Streams: enabled        │
    │  (triggers processor)    │
    └──────────────────────────┘
```

## Event-Driven Processing Flow

```
    Player submits score
           │
           v
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │ API Gateway  │────>│ submit-score │────>│  DynamoDB    │
    │ POST /scores │     │   Lambda     │     │  PutItem     │
    └──────────────┘     └──────────────┘     └──────┬───────┘
                                                     │ Stream
                                                     v
                                              ┌──────────────┐
                                              │  processor   │
                                              │  Lambda      │
                                              │              │
                                              │  - Update    │
                                              │    leaderboard
                                              │  - Check high│
                                              │    score     │
                                              └──────┬───────┘
                                                     │ If new
                                                     │ high score
                                                     v
                                              ┌──────────────┐
                                              │     SNS      │
                                              │  Topic       │
                                              └──────┬───────┘
                                                     │
                                                     v
                                              ┌──────────────┐
                                              │  notifier    │
                                              │  Lambda      │
                                              │              │
                                              │  Send alert  │
                                              └──────────────┘
```

---

*Last Updated: 2026-02-03*
