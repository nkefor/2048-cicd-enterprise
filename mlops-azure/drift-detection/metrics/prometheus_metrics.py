#!/usr/bin/env python3
"""
Prometheus Metrics for Drift Detection
Exposes metrics for Grafana visualization
"""

from prometheus_client import Gauge, Counter, start_http_server
import logging

logger = logging.getLogger(__name__)


class DriftMetrics:
    """Prometheus metrics for drift monitoring"""

    def __init__(self, prometheus_port: int = 8000):
        # Drift scores
        self.embedding_drift_score = Gauge(
            'drift_embedding_score',
            'Embedding drift score (0-1)'
        )
        self.behavior_drift_score = Gauge(
            'drift_behavior_score',
            'Behavior metrics drift score (0-1)'
        )
        self.accuracy_drift_score = Gauge(
            'drift_accuracy_score',
            'Accuracy drift score (0-1)'
        )
        self.overall_drift_score = Gauge(
            'drift_overall_score',
            'Overall drift score (0-1)'
        )

        # Model performance metrics
        self.model_accuracy = Gauge(
            'model_accuracy',
            'Current model accuracy'
        )
        self.refusal_rate = Gauge(
            'model_refusal_rate',
            'Model refusal rate'
        )
        self.toxicity_rate = Gauge(
            'model_toxicity_rate',
            'Model toxicity rate'
        )

        # Retraining events
        self.retrain_events_total = Counter(
            'retrain_events_total',
            'Total number of retraining events'
        )
        self.reindex_events_total = Counter(
            'reindex_events_total',
            'Total number of document reindexing events'
        )

        # Cost tracking
        self.api_cost_usd = Gauge(
            'api_cost_usd_total',
            'Total API cost in USD'
        )

        # Start Prometheus HTTP server
        try:
            start_http_server(prometheus_port)
            logger.info(f"Prometheus metrics server started on port {prometheus_port}")
        except OSError:
            logger.warning(f"Port {prometheus_port} already in use - metrics server not started")

    def update_drift_metrics(self, drift_report: dict):
        """Update all drift metrics from report"""
        self.embedding_drift_score.set(
            drift_report.get('embedding_drift', {}).get('drift_score', 0)
        )
        self.behavior_drift_score.set(
            drift_report.get('behavior_drift', {}).get('drift_score', 0)
        )
        self.accuracy_drift_score.set(
            drift_report.get('accuracy_drift', {}).get('drift_score', 0)
        )
        self.overall_drift_score.set(
            drift_report.get('overall_drift_score', 0)
        )

        # Update performance metrics if available
        behavior = drift_report.get('behavior_drift', {}).get('current_period', {}).get('metrics', {})
        if behavior:
            self.refusal_rate.set(behavior.get('refusal_rate', 0))
            self.toxicity_rate.set(behavior.get('toxicity_rate', 0))

        accuracy = drift_report.get('accuracy_drift', {}).get('current_period', {}).get('evaluation_metrics', {})
        if accuracy and accuracy.get('avg_accuracy'):
            self.model_accuracy.set(accuracy['avg_accuracy'])

    def increment_retrain_events(self):
        """Increment retraining counter"""
        self.retrain_events_total.inc()

    def increment_reindex_events(self):
        """Increment reindexing counter"""
        self.reindex_events_total.inc()

    def update_cost(self, cost: float):
        """Update total API cost"""
        self.api_cost_usd.set(cost)
