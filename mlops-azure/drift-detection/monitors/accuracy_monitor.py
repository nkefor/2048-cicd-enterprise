#!/usr/bin/env python3
"""
Accuracy Monitor
Tracks model performance metrics and detects accuracy degradation
"""

import psycopg2
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AccuracyMonitor:
    """
    Monitors model accuracy and performance metrics:
    - Accuracy on evaluation set
    - User feedback scores
    - Task success rates
    - Response quality metrics
    """

    def __init__(
        self,
        db_connection_string: str,
        accuracy_threshold: float = 0.05,  # 5% drop threshold
        feedback_threshold: float = 0.3    # 30% drop in ratings
    ):
        """
        Initialize accuracy monitor

        Args:
            db_connection_string: PostgreSQL connection string
            accuracy_threshold: Max acceptable accuracy drop (0-1)
            feedback_threshold: Max acceptable feedback score drop (0-1)
        """
        self.conn_string = db_connection_string
        self.accuracy_threshold = accuracy_threshold
        self.feedback_threshold = feedback_threshold

    def get_evaluation_metrics(
        self,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Get evaluation metrics from database

        Assumes you have an evaluation_log table with:
        - timestamp
        - evaluation_set_name
        - accuracy
        - precision
        - recall
        - f1_score
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        cur.execute("""
            SELECT
                AVG(accuracy) as avg_accuracy,
                AVG(precision) as avg_precision,
                AVG(recall) as avg_recall,
                AVG(f1_score) as avg_f1,
                COUNT(*) as evaluation_count
            FROM evaluation_log
            WHERE timestamp >= %s AND timestamp < %s
        """, (start_date, end_date))

        row = cur.fetchone()
        cur.close()
        conn.close()

        if row[4] == 0:  # No evaluations
            return {
                'avg_accuracy': None,
                'avg_precision': None,
                'avg_recall': None,
                'avg_f1': None,
                'evaluation_count': 0
            }

        return {
            'avg_accuracy': float(row[0]) if row[0] else None,
            'avg_precision': float(row[1]) if row[1] else None,
            'avg_recall': float(row[2]) if row[2] else None,
            'avg_f1': float(row[3]) if row[3] else None,
            'evaluation_count': row[4]
        }

    def get_user_feedback_metrics(
        self,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Get user feedback metrics

        Assumes interaction_log has user_feedback_score (0-5 or 0-1)
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        cur.execute("""
            SELECT
                AVG(user_feedback_score) as avg_rating,
                COUNT(*) as feedback_count,
                COUNT(CASE WHEN user_feedback_score >= 4 THEN 1 END) as positive_count,
                COUNT(CASE WHEN user_feedback_score <= 2 THEN 1 END) as negative_count
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
            AND user_feedback_score IS NOT NULL
        """, (start_date, end_date))

        row = cur.fetchone()
        cur.close()
        conn.close()

        if row[1] == 0:
            return {
                'avg_rating': None,
                'feedback_count': 0,
                'positive_rate': 0,
                'negative_rate': 0
            }

        return {
            'avg_rating': float(row[0]) if row[0] else None,
            'feedback_count': row[1],
            'positive_count': row[2],
            'negative_count': row[3],
            'positive_rate': row[2] / row[1] if row[1] > 0 else 0,
            'negative_rate': row[3] / row[1] if row[1] > 0 else 0
        }

    def get_task_success_metrics(
        self,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Get task success rate metrics

        Assumes task_log table with success_flag
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        try:
            cur.execute("""
                SELECT
                    COUNT(*) as total_tasks,
                    COUNT(CASE WHEN success_flag = true THEN 1 END) as successful_tasks
                FROM task_log
                WHERE timestamp >= %s AND timestamp < %s
            """, (start_date, end_date))

            row = cur.fetchone()

            if row[0] == 0:
                return {
                    'total_tasks': 0,
                    'success_rate': None
                }

            return {
                'total_tasks': row[0],
                'successful_tasks': row[1],
                'success_rate': row[1] / row[0] if row[0] > 0 else 0
            }
        except psycopg2.errors.UndefinedTable:
            logger.info("task_log table not found - skipping task metrics")
            return {'total_tasks': 0, 'success_rate': None}
        finally:
            cur.close()
            conn.close()

    def detect_accuracy_drift(
        self,
        baseline_days: int = 30,
        current_days: int = 7
    ) -> Dict:
        """
        Detect accuracy drift by comparing recent performance to baseline

        Args:
            baseline_days: Number of days for baseline period
            current_days: Number of days for current period

        Returns:
            Accuracy drift detection report
        """
        logger.info("Starting accuracy drift detection")

        now = datetime.now()
        current_end = now
        current_start = now - timedelta(days=current_days)
        baseline_end = current_start
        baseline_start = baseline_end - timedelta(days=baseline_days)

        # Get metrics for both periods
        baseline_eval = self.get_evaluation_metrics(baseline_start, baseline_end)
        current_eval = self.get_evaluation_metrics(current_start, current_end)

        baseline_feedback = self.get_user_feedback_metrics(baseline_start, baseline_end)
        current_feedback = self.get_user_feedback_metrics(current_start, current_end)

        baseline_tasks = self.get_task_success_metrics(baseline_start, baseline_end)
        current_tasks = self.get_task_success_metrics(current_start, current_end)

        # Calculate accuracy drop
        accuracy_drop = None
        accuracy_drift = False
        if baseline_eval['avg_accuracy'] and current_eval['avg_accuracy']:
            accuracy_drop = baseline_eval['avg_accuracy'] - current_eval['avg_accuracy']
            accuracy_drift = accuracy_drop > self.accuracy_threshold

        # Calculate feedback drop
        feedback_drop = None
        feedback_drift = False
        if baseline_feedback['avg_rating'] and current_feedback['avg_rating']:
            feedback_drop = (
                (baseline_feedback['avg_rating'] - current_feedback['avg_rating']) /
                baseline_feedback['avg_rating']
            )
            feedback_drift = feedback_drop > self.feedback_threshold

        # Calculate task success drop
        task_success_drop = None
        task_drift = False
        if baseline_tasks['success_rate'] and current_tasks['success_rate']:
            task_success_drop = baseline_tasks['success_rate'] - current_tasks['success_rate']
            task_drift = task_success_drop > self.accuracy_threshold

        # Overall drift detection
        drift_detected = accuracy_drift or feedback_drift or task_drift

        # Calculate drift score
        drift_components = []
        if accuracy_drop is not None:
            drift_components.append(accuracy_drop / self.accuracy_threshold)
        if feedback_drop is not None:
            drift_components.append(feedback_drop / self.feedback_threshold)
        if task_success_drop is not None:
            drift_components.append(task_success_drop / self.accuracy_threshold)

        drift_score = max(drift_components) if drift_components else 0

        report = {
            'timestamp': now.isoformat(),
            'drift_detected': drift_detected,
            'drift_score': min(float(drift_score), 1.0),
            'baseline_period': {
                'start': baseline_start.isoformat(),
                'end': baseline_end.isoformat(),
                'evaluation_metrics': baseline_eval,
                'feedback_metrics': baseline_feedback,
                'task_metrics': baseline_tasks
            },
            'current_period': {
                'start': current_start.isoformat(),
                'end': current_end.isoformat(),
                'evaluation_metrics': current_eval,
                'feedback_metrics': current_feedback,
                'task_metrics': current_tasks
            },
            'changes': {
                'accuracy_drop': float(accuracy_drop) if accuracy_drop else None,
                'accuracy_drift_detected': accuracy_drift,
                'feedback_drop_pct': float(feedback_drop * 100) if feedback_drop else None,
                'feedback_drift_detected': feedback_drift,
                'task_success_drop': float(task_success_drop) if task_success_drop else None,
                'task_drift_detected': task_drift
            },
            'thresholds': {
                'accuracy_threshold': self.accuracy_threshold,
                'feedback_threshold': self.feedback_threshold
            }
        }

        logger.info(f"Accuracy drift detection complete: {'DRIFT DETECTED' if drift_detected else 'NO DRIFT'}")

        if accuracy_drift:
            logger.warning(f"Accuracy dropped by {accuracy_drop:.2%}")
        if feedback_drift:
            logger.warning(f"User feedback dropped by {feedback_drop:.2%}")
        if task_drift:
            logger.warning(f"Task success rate dropped by {task_success_drop:.2%}")

        return report


if __name__ == '__main__':
    import os

    DB_CONNECTION = os.getenv(
        'SUPABASE_DB_URL',
        'postgresql://user:password@localhost:5432/mlops'
    )

    monitor = AccuracyMonitor(
        db_connection_string=DB_CONNECTION,
        accuracy_threshold=0.05,
        feedback_threshold=0.30
    )

    # Detect accuracy drift
    report = monitor.detect_accuracy_drift(
        baseline_days=30,
        current_days=7
    )

    print("\n" + "="*70)
    print("ACCURACY DRIFT DETECTION REPORT")
    print("="*70)
    print(f"Timestamp: {report['timestamp']}")
    print(f"Drift Detected: {report['drift_detected']}")
    print(f"Drift Score: {report['drift_score']:.3f}")
    print("\nBaseline Period:")
    print(f"  Accuracy: {report['baseline_period']['evaluation_metrics'].get('avg_accuracy', 'N/A')}")
    print(f"  Avg Rating: {report['baseline_period']['feedback_metrics'].get('avg_rating', 'N/A')}")
    print("\nCurrent Period:")
    print(f"  Accuracy: {report['current_period']['evaluation_metrics'].get('avg_accuracy', 'N/A')}")
    print(f"  Avg Rating: {report['current_period']['feedback_metrics'].get('avg_rating', 'N/A')}")
    print("\nChanges:")
    for key, value in report['changes'].items():
        if value is not None:
            if isinstance(value, bool):
                print(f"  {key}: {'YES' if value else 'NO'}")
            else:
                print(f"  {key}: {value:.4f}")
    print("="*70)
