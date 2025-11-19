"""
Autonomous Code Review Agent - Main Application
FastAPI backend for processing code review requests
"""
import os
import time
import hashlib
from typing import List, Dict, Optional
from fastapi import FastAPI, HTTPException, Request, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from datadog import statsd, initialize
from celery import Celery
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

from .analyzers.code_analyzer import CodeAnalyzer
from .analyzers.security_analyzer import SecurityAnalyzer
from .analyzers.performance_analyzer import PerformanceAnalyzer
from .rag.retrieval import RAGPipeline
from .db.database import get_db_session, VectorStore
from .integrations.github_client import GitHubClient
from .monitoring.datadog_logger import DatadogLogger
from .monitoring.splunk_logger import SplunkLogger
from .utils.rate_limiter import RateLimiter

# Initialize monitoring
initialize(
    statsd_host=os.getenv("DD_AGENT_HOST", "localhost"),
    statsd_port=int(os.getenv("DD_DOGSTATSD_PORT", 8125))
)

sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1,
    environment=os.getenv("ENVIRONMENT", "production")
)

# Initialize FastAPI app
app = FastAPI(
    title="Autonomous Code Review Agent",
    description="AI-powered code review system with multi-repository learning",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Celery for async tasks
celery_app = Celery(
    "code_review",
    broker=os.getenv("REDIS_URL", "redis://localhost:6379/0"),
    backend=os.getenv("REDIS_URL", "redis://localhost:6379/0")
)

# Initialize components
github_client = GitHubClient(token=os.getenv("GITHUB_TOKEN"))
code_analyzer = CodeAnalyzer()
security_analyzer = SecurityAnalyzer()
performance_analyzer = PerformanceAnalyzer()
rag_pipeline = RAGPipeline()
datadog_logger = DatadogLogger()
splunk_logger = SplunkLogger(
    hec_url=os.getenv("SPLUNK_HEC_URL"),
    hec_token=os.getenv("SPLUNK_HEC_TOKEN")
)
rate_limiter = RateLimiter(redis_url=os.getenv("REDIS_URL"))

# Pydantic models
class PullRequestWebhook(BaseModel):
    action: str
    number: int
    pull_request: Dict
    repository: Dict
    sender: Dict

class ReviewRequest(BaseModel):
    repo_owner: str
    repo_name: str
    pr_number: int
    focus_areas: Optional[List[str]] = Field(
        default=["security", "performance", "style", "best_practices"]
    )

class ReviewResponse(BaseModel):
    review_id: str
    status: str
    findings: List[Dict]
    summary: Dict
    confidence_score: float
    processing_time_ms: int


@app.on_event("startup")
async def startup_event():
    """Initialize resources on startup"""
    print("🚀 Starting Autonomous Code Review Agent...")

    # Warm up vector database connections
    vector_store = VectorStore()
    await vector_store.connect()

    # Load model cache
    await rag_pipeline.warm_cache()

    # Log startup
    datadog_logger.log_event("app.startup", {"environment": os.getenv("ENVIRONMENT")})
    splunk_logger.log("app_lifecycle", {"event": "startup", "version": "1.0.0"})

    print("✅ Code Review Agent ready!")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup resources on shutdown"""
    print("🛑 Shutting down Code Review Agent...")
    datadog_logger.log_event("app.shutdown", {"environment": os.getenv("ENVIRONMENT")})


@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": time.time()
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    # Return metrics in Prometheus format
    return {
        "reviews_completed": statsd.get_count("code_review.completed"),
        "reviews_in_progress": statsd.get_gauge("code_review.in_progress"),
        "average_latency_ms": statsd.get_histogram("code_review.latency").mean
    }


@app.post("/webhook/github")
async def github_webhook(
    request: Request,
    background_tasks: BackgroundTasks
):
    """
    Handle GitHub webhook events for pull requests
    """
    start_time = time.time()

    # Verify webhook signature
    signature = request.headers.get("X-Hub-Signature-256")
    if not verify_github_signature(await request.body(), signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    # Parse webhook payload
    event_type = request.headers.get("X-GitHub-Event")
    payload = await request.json()

    # Only process pull request events
    if event_type != "pull_request":
        return {"message": "Event ignored"}

    action = payload.get("action")
    if action not in ["opened", "synchronize", "reopened"]:
        return {"message": "Action ignored"}

    # Extract PR information
    pr_number = payload["number"]
    repo_full_name = payload["repository"]["full_name"]
    repo_owner, repo_name = repo_full_name.split("/")

    # Rate limiting check
    if not rate_limiter.allow_request(f"repo:{repo_full_name}"):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    # Queue async code review task
    task = celery_app.send_task(
        "tasks.review_pull_request",
        args=[repo_owner, repo_name, pr_number]
    )

    # Log to monitoring systems
    duration_ms = int((time.time() - start_time) * 1000)
    datadog_logger.increment("webhook.received", tags=[
        f"repo:{repo_full_name}",
        f"action:{action}"
    ])
    splunk_logger.log("webhook_received", {
        "repo": repo_full_name,
        "pr_number": pr_number,
        "action": action,
        "task_id": task.id,
        "duration_ms": duration_ms
    })

    return {
        "message": "Review queued",
        "task_id": task.id,
        "pr_number": pr_number
    }


@app.post("/review", response_model=ReviewResponse)
async def review_pull_request(
    review_request: ReviewRequest,
    background_tasks: BackgroundTasks,
    db_session=Depends(get_db_session)
):
    """
    Manual API endpoint to trigger code review
    """
    start_time = time.time()

    try:
        # Generate unique review ID
        review_id = hashlib.sha256(
            f"{review_request.repo_owner}/{review_request.repo_name}/{review_request.pr_number}".encode()
        ).hexdigest()[:16]

        # Log review start
        datadog_logger.increment("review.started", tags=[
            f"repo:{review_request.repo_owner}/{review_request.repo_name}"
        ])

        # Fetch PR data from GitHub
        pr_data = await github_client.get_pull_request(
            review_request.repo_owner,
            review_request.repo_name,
            review_request.pr_number
        )

        # Get diff/changed files
        changed_files = await github_client.get_pr_files(
            review_request.repo_owner,
            review_request.repo_name,
            review_request.pr_number
        )

        # Perform multi-layer analysis
        all_findings = []

        # Layer 1: Code quality analysis
        if "style" in review_request.focus_areas or "best_practices" in review_request.focus_areas:
            with statsd.timed("review.code_analysis"):
                code_findings = await code_analyzer.analyze(changed_files, pr_data)
                all_findings.extend(code_findings)

        # Layer 2: Security analysis
        if "security" in review_request.focus_areas:
            with statsd.timed("review.security_analysis"):
                security_findings = await security_analyzer.analyze(changed_files)
                all_findings.extend(security_findings)

        # Layer 3: Performance analysis
        if "performance" in review_request.focus_areas:
            with statsd.timed("review.performance_analysis"):
                perf_findings = await performance_analyzer.analyze(changed_files)
                all_findings.extend(perf_findings)

        # Layer 4: RAG-enhanced contextual analysis
        with statsd.timed("review.rag_analysis"):
            rag_findings = await rag_pipeline.get_contextual_suggestions(
                changed_files,
                repo=f"{review_request.repo_owner}/{review_request.repo_name}",
                historical_data=db_session
            )
            all_findings.extend(rag_findings)

        # Deduplicate and rank findings
        unique_findings = deduplicate_findings(all_findings)
        ranked_findings = rank_by_confidence(unique_findings)

        # Generate summary
        summary = generate_summary(ranked_findings)

        # Calculate confidence score
        confidence_score = calculate_overall_confidence(ranked_findings)

        # Post review to GitHub (async)
        if confidence_score > 0.7:
            background_tasks.add_task(
                post_review_to_github,
                review_request.repo_owner,
                review_request.repo_name,
                review_request.pr_number,
                ranked_findings
            )

        # Store review in database for learning
        background_tasks.add_task(
            store_review_for_learning,
            review_id,
            ranked_findings,
            pr_data,
            db_session
        )

        # Calculate processing time
        processing_time_ms = int((time.time() - start_time) * 1000)

        # Log metrics
        datadog_logger.histogram("review.latency", processing_time_ms, tags=[
            f"repo:{review_request.repo_owner}/{review_request.repo_name}",
            f"num_files:{len(changed_files)}"
        ])
        datadog_logger.increment("review.completed", tags=[
            f"confidence:{int(confidence_score * 100)}"
        ])

        splunk_logger.log("review_completed", {
            "review_id": review_id,
            "repo": f"{review_request.repo_owner}/{review_request.repo_name}",
            "pr_number": review_request.pr_number,
            "findings_count": len(ranked_findings),
            "confidence_score": confidence_score,
            "processing_time_ms": processing_time_ms,
            "focus_areas": review_request.focus_areas,
            "severity_breakdown": count_by_severity(ranked_findings)
        })

        return ReviewResponse(
            review_id=review_id,
            status="completed",
            findings=ranked_findings,
            summary=summary,
            confidence_score=confidence_score,
            processing_time_ms=processing_time_ms
        )

    except Exception as e:
        # Log error
        datadog_logger.increment("review.error", tags=[
            f"error_type:{type(e).__name__}"
        ])
        splunk_logger.log("review_error", {
            "error": str(e),
            "repo": f"{review_request.repo_owner}/{review_request.repo_name}",
            "pr_number": review_request.pr_number
        })
        sentry_sdk.capture_exception(e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/feedback")
async def submit_feedback(
    review_id: str,
    finding_id: str,
    feedback: str,  # "helpful" or "not_helpful"
    db_session=Depends(get_db_session)
):
    """
    Collect feedback on code review suggestions to improve future recommendations
    """
    # Store feedback in database
    await store_feedback(db_session, review_id, finding_id, feedback)

    # Update RAG pipeline with new training data
    if feedback == "helpful":
        await rag_pipeline.reinforce_pattern(finding_id, db_session)

    datadog_logger.increment("feedback.received", tags=[
        f"feedback:{feedback}"
    ])

    return {"message": "Feedback recorded"}


# Helper functions
def verify_github_signature(payload: bytes, signature: str) -> bool:
    """Verify GitHub webhook signature"""
    secret = os.getenv("GITHUB_WEBHOOK_SECRET", "").encode()
    expected_signature = "sha256=" + hashlib.sha256(secret + payload).hexdigest()
    return signature == expected_signature


def deduplicate_findings(findings: List[Dict]) -> List[Dict]:
    """Remove duplicate findings based on location and message"""
    seen = set()
    unique = []
    for finding in findings:
        key = (finding.get("file"), finding.get("line"), finding.get("message"))
        if key not in seen:
            seen.add(key)
            unique.append(finding)
    return unique


def rank_by_confidence(findings: List[Dict]) -> List[Dict]:
    """Sort findings by confidence score and severity"""
    severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}

    return sorted(
        findings,
        key=lambda x: (
            severity_order.get(x.get("severity", "info"), 4),
            -x.get("confidence", 0)
        )
    )


def generate_summary(findings: List[Dict]) -> Dict:
    """Generate summary statistics"""
    return {
        "total_findings": len(findings),
        "by_severity": count_by_severity(findings),
        "by_category": count_by_category(findings),
        "high_confidence_count": sum(1 for f in findings if f.get("confidence", 0) > 0.8)
    }


def count_by_severity(findings: List[Dict]) -> Dict[str, int]:
    """Count findings by severity level"""
    counts = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
    for finding in findings:
        severity = finding.get("severity", "info")
        counts[severity] = counts.get(severity, 0) + 1
    return counts


def count_by_category(findings: List[Dict]) -> Dict[str, int]:
    """Count findings by category"""
    counts = {}
    for finding in findings:
        category = finding.get("category", "other")
        counts[category] = counts.get(category, 0) + 1
    return counts


def calculate_overall_confidence(findings: List[Dict]) -> float:
    """Calculate weighted average confidence score"""
    if not findings:
        return 0.0

    weights = {"critical": 1.5, "high": 1.2, "medium": 1.0, "low": 0.8, "info": 0.5}
    total_weight = 0
    weighted_sum = 0

    for finding in findings:
        severity = finding.get("severity", "info")
        confidence = finding.get("confidence", 0)
        weight = weights.get(severity, 1.0)

        weighted_sum += confidence * weight
        total_weight += weight

    return weighted_sum / total_weight if total_weight > 0 else 0.0


async def post_review_to_github(
    repo_owner: str,
    repo_name: str,
    pr_number: int,
    findings: List[Dict]
):
    """Post code review comments to GitHub PR"""
    try:
        # Format findings as GitHub review comments
        comments = []
        for finding in findings[:20]:  # Limit to top 20 findings
            if finding.get("file") and finding.get("line"):
                comments.append({
                    "path": finding["file"],
                    "line": finding["line"],
                    "body": format_github_comment(finding)
                })

        # Post review
        await github_client.create_review(
            repo_owner,
            repo_name,
            pr_number,
            comments=comments,
            event="COMMENT"
        )

        datadog_logger.increment("github.review_posted")

    except Exception as e:
        datadog_logger.increment("github.review_error")
        sentry_sdk.capture_exception(e)


def format_github_comment(finding: Dict) -> str:
    """Format finding as GitHub comment with emoji and code suggestion"""
    emoji_map = {
        "critical": "🚨",
        "high": "⚠️",
        "medium": "⚡",
        "low": "💡",
        "info": "ℹ️"
    }

    emoji = emoji_map.get(finding.get("severity", "info"), "💬")
    message = f"{emoji} **{finding.get('title', 'Code Review Suggestion')}**\n\n"
    message += finding.get("message", "")

    if finding.get("suggestion"):
        message += f"\n\n**Suggested fix:**\n```{finding.get('language', '')}\n{finding['suggestion']}\n```"

    if finding.get("confidence"):
        confidence_pct = int(finding["confidence"] * 100)
        message += f"\n\n*Confidence: {confidence_pct}%*"

    return message


async def store_review_for_learning(
    review_id: str,
    findings: List[Dict],
    pr_data: Dict,
    db_session
):
    """Store review data for continuous learning"""
    # This will be used to improve future recommendations
    # by learning which suggestions were accepted vs rejected
    pass


async def store_feedback(db_session, review_id: str, finding_id: str, feedback: str):
    """Store user feedback in database"""
    # Implementation for storing feedback
    pass


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        workers=4
    )
