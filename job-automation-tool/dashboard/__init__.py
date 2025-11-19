"""
Dashboard package for job automation monitoring.

Provides Flask web application for real-time monitoring and metrics visualization.
"""

from dashboard.metrics_tracker import MetricsTracker
from dashboard.app import create_app

__all__ = [
    'MetricsTracker',
    'create_app',
]
