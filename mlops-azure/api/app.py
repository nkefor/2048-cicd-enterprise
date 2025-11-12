"""
ML Model Serving API with A/B Testing Support
FastAPI application for serving ML models with monitoring and A/B testing
"""

import os
import json
import time
import hashlib
from typing import Dict, List, Optional
from datetime import datetime
import numpy as np
import joblib
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
from azure.cosmos import CosmosClient
from opencensus.ext.azure import metrics_exporter
from opencensus.stats import aggregation as aggregation_module
from opencensus.stats import measure as measure_module
from opencensus.stats import stats as stats_module
from opencensus.stats import view as view_module
from opencensus.tags import tag_map as tag_map_module
from applicationinsights import TelemetryClient
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="MLOps Model Serving API",
    description="Production-ready ML model serving with A/B testing",
    version="1.0.0"
)

# Configuration from environment
MODEL_VERSION = os.getenv("MODEL_VERSION", "A")
APP_INSIGHTS_CONN_STR = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
COSMOS_DB_ENDPOINT = os.getenv("COSMOS_DB_ENDPOINT")
COSMOS_DB_KEY = os.getenv("COSMOS_DB_KEY")
AB_TEST_TRAFFIC_SPLIT = float(os.getenv("AB_TEST_TRAFFIC_SPLIT", "0.5"))

# Initialize Application Insights
tc = TelemetryClient(APP_INSIGHTS_CONN_STR) if APP_INSIGHTS_CONN_STR else None

# Initialize Cosmos DB
cosmos_client = None
if COSMOS_DB_ENDPOINT and COSMOS_DB_KEY:
    try:
        cosmos_client = CosmosClient(COSMOS_DB_ENDPOINT, COSMOS_DB_KEY)
        database = cosmos_client.get_database_client("mlops")
        experiments_container = database.get_container_client("experiments")
        logger.info("Connected to Cosmos DB")
    except Exception as e:
        logger.error(f"Failed to connect to Cosmos DB: {e}")

# Model cache
model_cache = {}
scaler_cache = {}


class PredictionRequest(BaseModel):
    """Request model for predictions"""
    features: List[float] = Field(..., description="Input features for prediction")
    user_id: Optional[str] = Field(None, description="User ID for A/B testing assignment")
    request_id: Optional[str] = Field(None, description="Unique request ID")


class PredictionResponse(BaseModel):
    """Response model for predictions"""
    prediction: int
    probability: float
    model_version: str
    request_id: str
    timestamp: str
    latency_ms: float


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    model_version: str
    model_loaded: bool
    timestamp: str


class MetricsResponse(BaseModel):
    """Metrics response"""
    total_requests: int
    model_version: str
    avg_latency_ms: float
    error_rate: float


# Metrics tracking
metrics = {
    "total_requests": 0,
    "successful_requests": 0,
    "failed_requests": 0,
    "total_latency_ms": 0.0,
    "model_a_requests": 0,
    "model_b_requests": 0,
}


def load_model(model_path: str = "/models/model.pkl"):
    """Load the ML model"""
    try:
        if model_path not in model_cache:
            logger.info(f"Loading model from {model_path}")
            model_cache[model_path] = joblib.load(model_path)
            logger.info("Model loaded successfully")
        return model_cache[model_path]
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


def load_scaler(scaler_path: str = "/models/scaler.pkl"):
    """Load the feature scaler"""
    try:
        if scaler_path not in scaler_cache:
            logger.info(f"Loading scaler from {scaler_path}")
            scaler_cache[scaler_path] = joblib.load(scaler_path)
            logger.info("Scaler loaded successfully")
        return scaler_cache[scaler_path]
    except Exception as e:
        logger.error(f"Failed to load scaler: {e}")
        raise


def assign_ab_variant(user_id: str) -> str:
    """
    Assign A/B test variant based on user ID
    Uses consistent hashing for stable assignment
    """
    if not user_id:
        # Random assignment if no user_id
        return "A" if np.random.random() < AB_TEST_TRAFFIC_SPLIT else "B"

    # Consistent hashing based on user_id
    hash_value = int(hashlib.md5(user_id.encode()).hexdigest(), 16)
    return "A" if (hash_value % 100) / 100 < AB_TEST_TRAFFIC_SPLIT else "B"


def log_prediction_to_cosmos(
    request_id: str,
    user_id: str,
    features: List[float],
    prediction: int,
    probability: float,
    model_version: str,
    latency_ms: float
):
    """Log prediction to Cosmos DB for analysis"""
    if not cosmos_client:
        return

    try:
        experiment_data = {
            "id": request_id,
            "experiment_id": f"ab_test_{datetime.now().strftime('%Y%m%d')}",
            "user_id": user_id,
            "model_version": model_version,
            "prediction": prediction,
            "probability": probability,
            "features": features,
            "latency_ms": latency_ms,
            "timestamp": datetime.utcnow().isoformat(),
        }
        experiments_container.create_item(body=experiment_data)
    except Exception as e:
        logger.warning(f"Failed to log to Cosmos DB: {e}")


def track_custom_metric(metric_name: str, value: float, properties: Dict = None):
    """Track custom metric to Application Insights"""
    if tc:
        tc.track_metric(metric_name, value, properties=properties)
        tc.flush()


@app.get("/", response_model=Dict)
async def root():
    """Root endpoint"""
    return {
        "service": "MLOps Model Serving API",
        "version": "1.0.0",
        "model_version": MODEL_VERSION,
        "status": "running"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for Kubernetes"""
    try:
        # Try to load model to verify it's accessible
        model = load_model()
        model_loaded = model is not None

        return HealthResponse(
            status="healthy" if model_loaded else "unhealthy",
            model_version=MODEL_VERSION,
            model_loaded=model_loaded,
            timestamp=datetime.utcnow().isoformat()
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint for Kubernetes"""
    try:
        # Check if model is loaded
        model = load_model()
        scaler = load_scaler()

        if model and scaler:
            return {"status": "ready"}
        else:
            raise HTTPException(status_code=503, detail="Service not ready")
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        raise HTTPException(status_code=503, detail="Service not ready")


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest, http_request: Request):
    """
    Make a prediction using the loaded model
    Supports A/B testing with automatic variant assignment
    """
    start_time = time.time()

    # Generate request ID if not provided
    request_id = request.request_id or f"{int(time.time() * 1000)}"

    # Update metrics
    metrics["total_requests"] += 1

    # Determine which model variant to use for A/B testing
    assigned_variant = assign_ab_variant(request.user_id or "")

    # Track which variant was used
    if assigned_variant == "A":
        metrics["model_a_requests"] += 1
    else:
        metrics["model_b_requests"] += 1

    try:
        # Load model and scaler
        model = load_model()
        scaler = load_scaler()

        # Prepare features
        features_array = np.array(request.features).reshape(1, -1)
        features_scaled = scaler.transform(features_array)

        # Make prediction
        prediction = int(model.predict(features_scaled)[0])
        probability = float(model.predict_proba(features_scaled)[0][1])

        # Calculate latency
        latency_ms = (time.time() - start_time) * 1000

        # Update metrics
        metrics["successful_requests"] += 1
        metrics["total_latency_ms"] += latency_ms

        # Log to Application Insights
        if tc:
            track_custom_metric(
                "prediction_latency",
                latency_ms,
                properties={
                    "model_version": MODEL_VERSION,
                    "assigned_variant": assigned_variant,
                    "prediction": prediction
                }
            )
            track_custom_metric(
                "prediction_confidence",
                probability,
                properties={"model_version": MODEL_VERSION}
            )

        # Log to Cosmos DB for A/B testing analysis
        log_prediction_to_cosmos(
            request_id=request_id,
            user_id=request.user_id or "anonymous",
            features=request.features,
            prediction=prediction,
            probability=probability,
            model_version=f"{MODEL_VERSION}_{assigned_variant}",
            latency_ms=latency_ms
        )

        return PredictionResponse(
            prediction=prediction,
            probability=probability,
            model_version=f"{MODEL_VERSION}_{assigned_variant}",
            request_id=request_id,
            timestamp=datetime.utcnow().isoformat(),
            latency_ms=latency_ms
        )

    except Exception as e:
        metrics["failed_requests"] += 1
        logger.error(f"Prediction failed: {e}")

        # Track error
        if tc:
            tc.track_exception()
            tc.flush()

        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.get("/metrics", response_model=MetricsResponse)
async def get_metrics():
    """Get service metrics"""
    avg_latency = (
        metrics["total_latency_ms"] / metrics["successful_requests"]
        if metrics["successful_requests"] > 0
        else 0
    )

    error_rate = (
        metrics["failed_requests"] / metrics["total_requests"]
        if metrics["total_requests"] > 0
        else 0
    )

    return MetricsResponse(
        total_requests=metrics["total_requests"],
        model_version=MODEL_VERSION,
        avg_latency_ms=avg_latency,
        error_rate=error_rate
    )


@app.get("/ab-test/stats")
async def get_ab_test_stats():
    """Get A/B testing statistics"""
    total_ab_requests = metrics["model_a_requests"] + metrics["model_b_requests"]

    return {
        "total_requests": total_ab_requests,
        "model_a_requests": metrics["model_a_requests"],
        "model_b_requests": metrics["model_b_requests"],
        "model_a_percentage": (
            (metrics["model_a_requests"] / total_ab_requests * 100)
            if total_ab_requests > 0
            else 0
        ),
        "model_b_percentage": (
            (metrics["model_b_requests"] / total_ab_requests * 100)
            if total_ab_requests > 0
            else 0
        ),
        "configured_split": AB_TEST_TRAFFIC_SPLIT
    }


if __name__ == "__main__":
    # Pre-load model at startup
    try:
        load_model()
        load_scaler()
        logger.info("Model and scaler pre-loaded successfully")
    except Exception as e:
        logger.warning(f"Could not pre-load model: {e}")

    # Start server
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info"
    )
