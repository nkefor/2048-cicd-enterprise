# Multi-stage build for production-ready web application

# ============================================================
# Stage 1: Builder
# ============================================================
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ============================================================
# Stage 2: Runtime (Minimal image)
# ============================================================
FROM python:3.11-slim

# Security: Set non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .
COPY --chown=appuser:appuser . .

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /tmp && \
    chown -R appuser:appuser /app /tmp && \
    chmod 755 /app

# Set environment variables
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=info
ENV FLASK_ENV=production

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000/health')" || exit 1

# Security: Run as read-only filesystem
# Note: This is handled in docker-compose.yml with read_only_root_filesystem: true

# Expose port
EXPOSE 5000

# Run application
CMD ["python", "app.py"]
