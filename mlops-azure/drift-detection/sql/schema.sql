-- Drift-Aware Retraining Pipeline - Database Schema
-- PostgreSQL with pgvector extension

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Embeddings log table
CREATE TABLE IF NOT EXISTS embeddings_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    type VARCHAR(20) NOT NULL,  -- 'query', 'doc', or 'response'
    embedding vector(1536),      -- OpenAI ada-002 dimension
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON embeddings_log (timestamp);
CREATE INDEX ON embeddings_log (type);
CREATE INDEX ON embeddings_log USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Interaction log table
CREATE TABLE IF NOT EXISTS interaction_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    user_query TEXT NOT NULL,
    model_response TEXT,
    refusal_flag BOOLEAN DEFAULT FALSE,
    toxicity_flag BOOLEAN DEFAULT FALSE,
    error_flag BOOLEAN DEFAULT FALSE,
    user_feedback_score FLOAT,  -- 0-5 or 0-1
    response_time_ms INTEGER,
    model_version VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON interaction_log (timestamp);
CREATE INDEX ON interaction_log (refusal_flag) WHERE refusal_flag = TRUE;
CREATE INDEX ON interaction_log (toxicity_flag) WHERE toxicity_flag = TRUE;

-- Evaluation log table
CREATE TABLE IF NOT EXISTS evaluation_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    evaluation_set_name VARCHAR(100),
    model_version VARCHAR(50),
    accuracy FLOAT,
    precision FLOAT,
    recall FLOAT,
    f1_score FLOAT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON evaluation_log (timestamp);
CREATE INDEX ON evaluation_log (model_version);

-- Task log table (optional)
CREATE TABLE IF NOT EXISTS task_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    task_type VARCHAR(50),
    success_flag BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON task_log (timestamp);

-- Documents table
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1536),
    last_indexed TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON documents (last_indexed);
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Drift events log
CREATE TABLE IF NOT EXISTS drift_events (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    event_type VARCHAR(50),  -- 'embedding_drift', 'behavior_drift', 'accuracy_drift'
    drift_score FLOAT,
    details JSONB,
    actions_taken TEXT[],
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON drift_events (timestamp);
CREATE INDEX ON drift_events (event_type);

-- Model versions table
CREATE TABLE IF NOT EXISTS model_versions (
    id SERIAL PRIMARY KEY,
    version_name VARCHAR(50) UNIQUE NOT NULL,
    deployed_at TIMESTAMP DEFAULT NOW(),
    training_date TIMESTAMP,
    accuracy FLOAT,
    metadata JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON model_versions (deployed_at);
CREATE INDEX ON model_versions (is_active) WHERE is_active = TRUE;

-- Helper functions

-- Function to compute embedding distance
CREATE OR REPLACE FUNCTION embedding_distance(
    vec1 vector(1536),
    vec2 vector(1536),
    distance_type TEXT DEFAULT 'cosine'
)
RETURNS FLOAT AS $$
BEGIN
    IF distance_type = 'cosine' THEN
        RETURN 1 - (vec1 <=> vec2);  -- cosine similarity
    ELSIF distance_type = 'euclidean' THEN
        RETURN vec1 <-> vec2;  -- L2 distance
    ELSE
        RETURN vec1 <#> vec2;  -- inner product
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Example queries

-- Get recent query embeddings
-- SELECT embedding FROM embeddings_log
-- WHERE type = 'query'
-- AND timestamp > NOW() - INTERVAL '7 days';

-- Get refusal rate for last 7 days
-- SELECT
--     COUNT(*) FILTER (WHERE refusal_flag = TRUE)::FLOAT / COUNT(*) as refusal_rate
-- FROM interaction_log
-- WHERE timestamp > NOW() - INTERVAL '7 days';

-- Find similar documents
-- SELECT id, content,
--     (embedding <=> '[...]'::vector) as distance
-- FROM documents
-- ORDER BY distance
-- LIMIT 10;
