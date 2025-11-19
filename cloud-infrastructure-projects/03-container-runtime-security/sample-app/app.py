#!/usr/bin/env python3
"""
Production-Ready Container Security Demonstration Application

This application demonstrates:
1. Security instrumentation and monitoring
2. Best practices for containerized applications
3. Integration with Falco runtime security
4. Health checks and graceful shutdown
5. Structured logging for observability
"""

import os
import sys
import json
import logging
import time
import socket
import hashlib
from datetime import datetime
from functools import wraps
from threading import Thread

from flask import Flask, request, jsonify
from werkzeug.exceptions import HTTPException

# ============================================================
# Configuration
# ============================================================

APP_VERSION = "1.0.0"
LOG_LEVEL = os.getenv('LOG_LEVEL', 'info').upper()
SECURITY_CONTEXT_ENABLED = os.getenv('SECURITY_CONTEXT_ENABLED', 'true').lower() == 'true'
INSTANCE_ID = socket.gethostname()

# ============================================================
# Logging Setup
# ============================================================

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""

    def format(self, record):
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'instance_id': INSTANCE_ID,
            'version': APP_VERSION,
        }

        # Add exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)

        # Add custom fields
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id
        if hasattr(record, 'duration_ms'):
            log_data['duration_ms'] = record.duration_ms

        return json.dumps(log_data)


def setup_logging():
    """Initialize structured JSON logging"""
    logger = logging.getLogger('app')
    logger.setLevel(LOG_LEVEL)

    # Console handler with JSON formatter
    handler = logging.StreamHandler(sys.stdout)
    formatter = JSONFormatter()
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    return logger


logger = setup_logging()

# ============================================================
# Flask Application Factory
# ============================================================

def create_app():
    """Create and configure Flask application"""

    app = Flask(__name__)
    app.config['JSON_SORT_KEYS'] = False

    # ============================================================
    # Request/Response Middleware
    # ============================================================

    @app.before_request
    def before_request():
        """Log incoming request"""
        request.start_time = time.time()
        request.request_id = hashlib.md5(
            f"{datetime.utcnow().isoformat()}{id(request)}".encode()
        ).hexdigest()[:12]

        logger.info(
            f"Incoming request",
            extra={
                'request_id': request.request_id,
                'method': request.method,
                'path': request.path,
                'remote_addr': request.remote_addr,
            }
        )

    @app.after_request
    def after_request(response):
        """Log response and timing"""
        duration = (time.time() - request.start_time) * 1000

        log_level = 'info' if response.status_code < 400 else 'warning'
        getattr(logger, log_level)(
            f"Request completed",
            extra={
                'request_id': getattr(request, 'request_id', 'unknown'),
                'status_code': response.status_code,
                'duration_ms': duration,
                'path': request.path,
            }
        )

        # Add security headers
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        response.headers['Strict-Transport-Security'] = 'max-age=31536000'
        response.headers['Content-Security-Policy'] = "default-src 'self'"

        return response

    @app.errorhandler(Exception)
    def handle_error(error):
        """Centralized error handling"""
        if isinstance(error, HTTPException):
            status_code = error.code
            description = error.description
        else:
            status_code = 500
            description = str(error)

        logger.error(
            f"Request error: {error}",
            extra={
                'request_id': getattr(request, 'request_id', 'unknown'),
                'status_code': status_code,
                'error_type': type(error).__name__,
            }
        )

        return jsonify({
            'error': description,
            'status': status_code,
            'request_id': getattr(request, 'request_id', 'unknown'),
            'timestamp': datetime.utcnow().isoformat(),
        }), status_code

    # ============================================================
    # Routes - Health & Status
    # ============================================================

    @app.route('/health', methods=['GET'])
    def health():
        """Health check endpoint for container orchestration"""
        return jsonify({
            'status': 'healthy',
            'instance_id': INSTANCE_ID,
            'version': APP_VERSION,
            'timestamp': datetime.utcnow().isoformat(),
        }), 200

    @app.route('/status', methods=['GET'])
    def status():
        """Detailed status endpoint"""
        uptime_seconds = time.time()  # Simplified for demo

        return jsonify({
            'status': 'running',
            'instance_id': INSTANCE_ID,
            'version': APP_VERSION,
            'uptime_seconds': uptime_seconds,
            'environment': os.getenv('FLASK_ENV', 'unknown'),
            'security_enabled': SECURITY_CONTEXT_ENABLED,
            'timestamp': datetime.utcnow().isoformat(),
        }), 200

    # ============================================================
    # Routes - API Endpoints
    # ============================================================

    @app.route('/api/echo', methods=['POST'])
    def echo():
        """Echo endpoint - demonstrates request handling"""
        data = request.get_json() or {}

        logger.info(
            f"Echo request received",
            extra={'request_id': getattr(request, 'request_id', 'unknown')}
        )

        return jsonify({
            'echo': data,
            'received_at': datetime.utcnow().isoformat(),
            'instance_id': INSTANCE_ID,
        }), 200

    @app.route('/api/data', methods=['GET'])
    def get_data():
        """Sample data endpoint"""
        data = {
            'items': [
                {'id': 1, 'name': 'Item 1', 'created': datetime.utcnow().isoformat()},
                {'id': 2, 'name': 'Item 2', 'created': datetime.utcnow().isoformat()},
            ],
            'total': 2,
        }

        return jsonify(data), 200

    @app.route('/api/metrics', methods=['GET'])
    def metrics():
        """Application metrics endpoint"""
        metrics = {
            'instance_id': INSTANCE_ID,
            'version': APP_VERSION,
            'requests_received': 0,  # Would be tracked in production
            'errors': 0,
            'avg_response_time_ms': 0,
            'timestamp': datetime.utcnow().isoformat(),
        }

        return jsonify(metrics), 200

    # ============================================================
    # Routes - Security Demonstration (DO NOT USE IN PRODUCTION)
    # ============================================================

    @app.route('/api/security/test', methods=['POST'])
    def security_test():
        """
        Security test endpoint - demonstrates Falco detection

        WARNING: This endpoint is for testing Falco detection only.
        Do NOT use in production environments.

        Supported tests:
        - suspicious_file_access: Attempts to read sensitive files
        - network_anomaly: Makes suspicious network connections
        - privilege_escalation: Simulates privilege escalation attempts
        """

        if not SECURITY_CONTEXT_ENABLED:
            return jsonify({'error': 'Security testing disabled'}), 403

        test_type = request.json.get('test', '') if request.is_json else ''

        logger.warning(f"Security test requested: {test_type}")

        if test_type == 'suspicious_read':
            # This will trigger Falco rule: "Suspicious File Access"
            try:
                with open('/etc/passwd', 'r') as f:
                    f.read(1024)
            except Exception as e:
                logger.error(f"Test read failed: {e}")

        elif test_type == 'suspicious_write':
            # This will trigger Falco rule: "Unauthorized System Modification"
            try:
                with open('/tmp/test_alert.txt', 'w') as f:
                    f.write('Falco alert test')
            except Exception as e:
                logger.error(f"Test write failed: {e}")

        elif test_type == 'process_spawn':
            # This will trigger Falco rule: "Suspicious Process"
            try:
                os.system('whoami')  # Simplified test
            except Exception as e:
                logger.error(f"Process spawn test failed: {e}")

        return jsonify({
            'test': test_type,
            'status': 'completed',
            'message': 'Check Falco dashboard for alert',
            'timestamp': datetime.utcnow().isoformat(),
        }), 200

    # ============================================================
    # Routes - Monitoring
    # ============================================================

    @app.route('/api/info', methods=['GET'])
    def info():
        """Application information endpoint"""
        return jsonify({
            'name': 'Container Runtime Security Demo',
            'version': APP_VERSION,
            'description': 'Demonstration app for Falco container security monitoring',
            'instance_id': INSTANCE_ID,
            'python_version': sys.version,
            'running_in_container': os.path.exists('/.dockerenv'),
            'security_context_enabled': SECURITY_CONTEXT_ENABLED,
        }), 200

    # ============================================================
    # Error Handlers
    # ============================================================

    @app.route('/', methods=['GET'])
    def index():
        """Index endpoint"""
        return jsonify({
            'message': 'Container Runtime Security Platform',
            'endpoints': {
                'health': 'GET /health',
                'status': 'GET /status',
                'info': 'GET /api/info',
                'data': 'GET /api/data',
                'echo': 'POST /api/echo',
                'metrics': 'GET /api/metrics',
                'security_test': 'POST /api/security/test',
            },
        }), 200

    return app


# ============================================================
# Application Entry Point
# ============================================================

if __name__ == '__main__':
    logger.info(f"Starting Container Runtime Security Demo Application v{APP_VERSION}")
    logger.info(f"Instance ID: {INSTANCE_ID}")
    logger.info(f"Log Level: {LOG_LEVEL}")
    logger.info(f"Security Context Enabled: {SECURITY_CONTEXT_ENABLED}")

    app = create_app()

    # Run Flask development server
    # In production, use a proper WSGI server like Gunicorn
    try:
        app.run(
            host='0.0.0.0',
            port=5000,
            debug=False,
            threaded=True,
            use_reloader=False,
        )
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Application error: {e}")
        sys.exit(1)
