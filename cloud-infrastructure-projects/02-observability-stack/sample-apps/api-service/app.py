#!/usr/bin/env python3
"""
FastAPI Sample Application with OpenTelemetry Instrumentation and Prometheus Metrics
Includes distributed tracing, structured logging, and comprehensive monitoring
"""

import json
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Dict, Any

import psycopg2
import redis
import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pythonjsonlogger import jsonlogger
from prometheus_client import Counter, Histogram, Gauge, generate_latest

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

# ============================================================================
# Configuration
# ============================================================================

SERVICE_NAME_STR = os.getenv("SERVICE_NAME", "sample-api")
JAEGER_AGENT_HOST = os.getenv("JAEGER_AGENT_HOST", "localhost")
JAEGER_AGENT_PORT = int(os.getenv("JAEGER_AGENT_PORT", "6831"))
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/sampledb")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

# ============================================================================
# Logging Setup
# ============================================================================

def setup_logging():
    """Configure structured JSON logging"""
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # JSON formatter for structured logs
    json_handler = logging.StreamHandler()
    json_formatter = jsonlogger.JsonFormatter(
        fmt='%(timestamp)s %(level)s %(name)s %(message)s %(trace_id)s %(span_id)s',
        timestamp=True,
        rename_fields={'timestamp': '@timestamp'}
    )
    json_handler.setFormatter(json_formatter)
    logger.addHandler(json_handler)

    return logger

logger = setup_logging()

# ============================================================================
# OpenTelemetry Setup
# ============================================================================

def init_tracing():
    """Initialize Jaeger tracing"""
    jaeger_exporter = JaegerExporter(
        agent_host_name=JAEGER_AGENT_HOST,
        agent_port=JAEGER_AGENT_PORT,
    )

    resource = Resource.create({
        SERVICE_NAME: SERVICE_NAME_STR,
        "environment": ENVIRONMENT,
        "version": "1.0.0"
    })

    trace_provider = TracerProvider(resource=resource)
    trace_provider.add_span_processor(
        BatchSpanProcessor(jaeger_exporter)
    )
    trace.set_tracer_provider(trace_provider)

    return trace.get_tracer(__name__)

def init_metrics():
    """Initialize Prometheus metrics"""
    reader = PrometheusMetricReader()
    resource = Resource.create({
        SERVICE_NAME: SERVICE_NAME_STR,
        "environment": ENVIRONMENT,
    })

    meter_provider = MeterProvider(resource=resource, metric_readers=[reader])
    metrics.set_meter_provider(meter_provider)

    return metrics.get_meter(__name__), reader

tracer = init_tracing()
meter, prometheus_reader = init_metrics()

# ============================================================================
# Prometheus Metrics (Legacy style for compatibility)
# ============================================================================

# Request metrics
request_count = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

# Database metrics
db_query_duration = Histogram(
    'db_query_duration_seconds',
    'Database query duration in seconds',
    ['operation', 'table']
)

db_connection_pool = Gauge(
    'db_connection_pool_available',
    'Available database connections'
)

# Cache metrics
cache_hits = Counter(
    'cache_hits_total',
    'Total cache hits',
    ['cache']
)

cache_misses = Counter(
    'cache_misses_total',
    'Total cache misses',
    ['cache']
)

cache_latency = Histogram(
    'cache_operation_duration_seconds',
    'Cache operation duration',
    ['operation', 'cache']
)

# Business metrics
items_created = Counter(
    'items_created_total',
    'Total items created',
    ['type']
)

items_processed = Counter(
    'items_processed_total',
    'Total items processed',
    ['status']
)

# ============================================================================
# Database and Cache Connections
# ============================================================================

class DatabasePool:
    """Simple database connection pool"""
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.connection = None

    def connect(self):
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(self.dsn)
            db_connection_pool.set(1)
            logger.info("Database connected", extra={"database": "postgresql"})
        except Exception as e:
            db_connection_pool.set(0)
            logger.error(f"Database connection failed: {e}")
            raise

    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            db_connection_pool.set(0)
            logger.info("Database disconnected")

    def is_healthy(self) -> bool:
        """Check database health"""
        try:
            if self.connection:
                cursor = self.connection.cursor()
                cursor.execute("SELECT 1")
                cursor.close()
                return True
        except:
            pass
        return False

class RedisCache:
    """Redis cache wrapper"""
    def __init__(self, url: str):
        self.url = url
        self.client = None

    def connect(self):
        """Connect to Redis"""
        try:
            self.client = redis.from_url(self.url, decode_responses=True)
            self.client.ping()
            logger.info("Redis connected", extra={"cache": "redis"})
        except Exception as e:
            logger.error(f"Redis connection failed: {e}")
            self.client = None

    def disconnect(self):
        """Disconnect from Redis"""
        if self.client:
            self.client.close()
            logger.info("Redis disconnected")

    def get(self, key: str):
        """Get value from cache"""
        start = time.time()
        try:
            if not self.client:
                cache_misses.labels(cache='redis').inc()
                return None

            value = self.client.get(key)
            duration = time.time() - start
            cache_latency.labels(operation='get', cache='redis').observe(duration)

            if value:
                cache_hits.labels(cache='redis').inc()
            else:
                cache_misses.labels(cache='redis').inc()

            return value
        except Exception as e:
            logger.warning(f"Cache get failed: {e}")
            cache_misses.labels(cache='redis').inc()
            return None

    def set(self, key: str, value: str, ttl: int = 3600):
        """Set value in cache"""
        start = time.time()
        try:
            if self.client:
                self.client.setex(key, ttl, value)
                duration = time.time() - start
                cache_latency.labels(operation='set', cache='redis').observe(duration)
        except Exception as e:
            logger.warning(f"Cache set failed: {e}")

# Global connections
db_pool = DatabasePool(DATABASE_URL)
redis_cache = RedisCache(REDIS_URL)

# ============================================================================
# FastAPI Application
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management"""
    # Startup
    logger.info("Application starting", extra={"service": SERVICE_NAME_STR})
    db_pool.connect()
    redis_cache.connect()

    yield

    # Shutdown
    logger.info("Application shutting down", extra={"service": SERVICE_NAME_STR})
    db_pool.disconnect()
    redis_cache.disconnect()

app = FastAPI(
    title=SERVICE_NAME_STR,
    version="1.0.0",
    lifespan=lifespan
)

# Instrument FastAPI
FastAPIInstrumentor.instrument_app(app)
RequestsInstrumentor().instrument()
if redis_cache.client:
    RedisInstrumentor().instrument()

# ============================================================================
# Middleware
# ============================================================================

@app.middleware("http")
async def request_timing_middleware(request: Request, call_next):
    """Track request timing and metrics"""
    start_time = time.time()

    # Extract trace context
    trace_id = request.headers.get("x-trace-id", "unknown")
    span_id = request.headers.get("x-span-id", "unknown")

    try:
        response = await call_next(request)
        process_time = time.time() - start_time

        # Record metrics
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()

        request_duration.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(process_time)

        # Log request completion
        logger.info(
            "Request completed",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": process_time * 1000,
                "trace_id": trace_id,
                "span_id": span_id
            }
        )

        response.headers["x-trace-id"] = trace_id
        response.headers["x-span-id"] = span_id

        return response
    except Exception as e:
        process_time = time.time() - start_time
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500
        ).inc()

        logger.error(
            f"Request failed: {str(e)}",
            extra={
                "method": request.method,
                "path": request.url.path,
                "trace_id": trace_id,
                "span_id": span_id,
                "duration_ms": process_time * 1000
            }
        )
        raise

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    db_healthy = db_pool.is_healthy()
    redis_healthy = redis_cache.client is not None

    status = "healthy" if (db_healthy and redis_healthy) else "degraded"

    return {
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "service": SERVICE_NAME_STR,
        "database": "connected" if db_healthy else "disconnected",
        "cache": "connected" if redis_healthy else "disconnected"
    }

@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint"""
    return {
        "ready": True,
        "service": SERVICE_NAME_STR
    }

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.get("/items")
async def list_items(skip: int = 0, limit: int = 10):
    """List items from cache or database"""
    cache_key = f"items:{skip}:{limit}"

    # Try cache first
    cached_items = redis_cache.get(cache_key)
    if cached_items:
        items = json.loads(cached_items)
        logger.info("Items retrieved from cache", extra={"count": len(items)})
        return {"items": items, "source": "cache"}

    # Fallback to database
    try:
        items = [
            {"id": i, "name": f"Item {i}", "price": 99.99}
            for i in range(skip, skip + limit)
        ]

        redis_cache.set(cache_key, json.dumps(items), ttl=3600)

        logger.info("Items retrieved from database", extra={"count": len(items)})
        items_processed.labels(status="success").inc()

        return {"items": items, "source": "database"}
    except Exception as e:
        items_processed.labels(status="error").inc()
        logger.error(f"Failed to retrieve items: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/items")
async def create_item(item: Dict[str, Any]):
    """Create a new item"""
    try:
        with tracer.start_as_current_span("create_item"):
            item_id = int(time.time() * 1000)
            item_data = {
                "id": item_id,
                "name": item.get("name", ""),
                "price": item.get("price", 0),
                "created_at": datetime.utcnow().isoformat()
            }

            items_created.labels(type="item").inc()

            logger.info("Item created", extra={
                "item_id": item_id,
                "name": item_data["name"]
            })

            return {"success": True, "item": item_data}
    except Exception as e:
        logger.error(f"Failed to create item: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/slow")
async def slow_endpoint(duration: int = 2):
    """Slow endpoint for testing latency alerts"""
    start = time.time()
    time.sleep(min(duration, 10))  # Max 10 seconds
    elapsed = time.time() - start

    return {
        "message": "Slow endpoint completed",
        "requested_duration": duration,
        "actual_duration": elapsed
    }

@app.get("/error")
async def error_endpoint():
    """Error endpoint for testing error tracking"""
    items_processed.labels(status="error").inc()
    logger.error("Intentional error endpoint called")
    raise HTTPException(status_code=500, detail="Intentional error")

@app.get("/info")
async def info():
    """Application info endpoint"""
    return {
        "service": SERVICE_NAME_STR,
        "version": "1.0.0",
        "environment": ENVIRONMENT,
        "timestamp": datetime.utcnow().isoformat(),
        "jaeger": {
            "host": JAEGER_AGENT_HOST,
            "port": JAEGER_AGENT_PORT
        }
    }

# ============================================================================
# Error Handlers
# ============================================================================

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(
        f"Unhandled exception: {str(exc)}",
        extra={
            "path": request.url.path,
            "method": request.method
        }
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
