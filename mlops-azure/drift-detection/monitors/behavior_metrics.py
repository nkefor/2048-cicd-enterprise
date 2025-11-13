#!/usr/bin/env python3
"""
Behavior Metrics Monitor
Tracks refusal rates and toxicity flags to detect behavioral drift
"""

import psycopg2
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging
import openai
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BehaviorMetricsMonitor:
    """
    Monitors behavior metrics that indicate model drift:
    - Refusal rate (model refusing to answer)
    - Toxicity rate (harmful content detection)
    - Response length anomalies
    - Error rates
    """

    def __init__(
        self,
        db_connection_string: str,
        refusal_rate_threshold: float = 0.10,  # 10%
        toxicity_rate_threshold: float = 0.05,  # 5%
        openai_api_key: Optional[str] = None
    ):
        """
        Initialize behavior monitor

        Args:
            db_connection_string: PostgreSQL connection string
            refusal_rate_threshold: Max acceptable refusal rate (0-1)
            toxicity_rate_threshold: Max acceptable toxicity rate (0-1)
            openai_api_key: OpenAI API key for moderation API
        """
        self.conn_string = db_connection_string
        self.refusal_threshold = refusal_rate_threshold
        self.toxicity_threshold = toxicity_rate_threshold

        if openai_api_key:
            openai.api_key = openai_api_key

    def detect_refusal(self, response: str) -> bool:
        """
        Detect if a response is a refusal

        Common refusal patterns:
        - "I cannot", "I'm unable to"
        - "I don't have information"
        - "I apologize, but I cannot"
        """
        refusal_patterns = [
            "i cannot",
            "i can't",
            "i'm unable to",
            "i am unable to",
            "i don't have",
            "i do not have",
            "i apologize, but i cannot",
            "i'm sorry, but i cannot",
            "i'm not able to",
            "i am not able to",
            "as an ai",
            "i don't feel comfortable",
            "that's not something i can"
        ]

        response_lower = response.lower()
        return any(pattern in response_lower for pattern in refusal_patterns)

    def check_toxicity_openai(self, text: str) -> Dict:
        """
        Check toxicity using OpenAI's moderation API

        Returns:
            Dictionary with toxicity flags and scores
        """
        try:
            response = openai.Moderation.create(input=text)
            result = response["results"][0]

            return {
                'flagged': result['flagged'],
                'categories': result['categories'],
                'category_scores': result['category_scores']
            }
        except Exception as e:
            logger.error(f"Error checking toxicity: {e}")
            return {'flagged': False, 'error': str(e)}

    def get_interaction_metrics(
        self,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Fetch interaction metrics from database

        Returns:
            Dictionary with counts and rates
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        # Get total interactions
        cur.execute("""
            SELECT COUNT(*)
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
        """, (start_date, end_date))
        total_interactions = cur.fetchone()[0]

        # Get refusal count
        cur.execute("""
            SELECT COUNT(*)
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
            AND refusal_flag = true
        """, (start_date, end_date))
        refusal_count = cur.fetchone()[0]

        # Get toxicity count
        cur.execute("""
            SELECT COUNT(*)
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
            AND toxicity_flag = true
        """, (start_date, end_date))
        toxicity_count = cur.fetchone()[0]

        # Get error count (if tracked)
        cur.execute("""
            SELECT COUNT(*)
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
            AND error_flag = true
        """, (start_date, end_date))
        error_count = cur.fetchone()[0]

        # Get average response length
        cur.execute("""
            SELECT AVG(LENGTH(model_response))
            FROM interaction_log
            WHERE timestamp >= %s AND timestamp < %s
            AND model_response IS NOT NULL
        """, (start_date, end_date))
        avg_response_length = cur.fetchone()[0] or 0

        cur.close()
        conn.close()

        if total_interactions == 0:
            return {
                'total_interactions': 0,
                'refusal_rate': 0,
                'toxicity_rate': 0,
                'error_rate': 0,
                'avg_response_length': 0
            }

        return {
            'total_interactions': total_interactions,
            'refusal_count': refusal_count,
            'refusal_rate': refusal_count / total_interactions,
            'toxicity_count': toxicity_count,
            'toxicity_rate': toxicity_count / total_interactions,
            'error_count': error_count,
            'error_rate': error_count / total_interactions,
            'avg_response_length': float(avg_response_length)
        }

    def detect_behavior_drift(
        self,
        baseline_days: int = 30,
        current_days: int = 7
    ) -> Dict:
        """
        Detect behavioral drift by comparing recent metrics to baseline

        Args:
            baseline_days: Number of days for baseline period
            current_days: Number of days for current period

        Returns:
            Drift detection report
        """
        logger.info("Starting behavior drift detection")

        now = datetime.now()
        current_end = now
        current_start = now - timedelta(days=current_days)
        baseline_end = current_start
        baseline_start = baseline_end - timedelta(days=baseline_days)

        # Get metrics for both periods
        baseline_metrics = self.get_interaction_metrics(baseline_start, baseline_end)
        current_metrics = self.get_interaction_metrics(current_start, current_end)

        if baseline_metrics['total_interactions'] == 0 or current_metrics['total_interactions'] == 0:
            return {
                'timestamp': now.isoformat(),
                'error': 'Insufficient data for behavior drift detection',
                'baseline_interactions': baseline_metrics['total_interactions'],
                'current_interactions': current_metrics['total_interactions']
            }

        # Calculate changes
        refusal_change = current_metrics['refusal_rate'] - baseline_metrics['refusal_rate']
        toxicity_change = current_metrics['toxicity_rate'] - baseline_metrics['toxicity_rate']
        error_change = current_metrics['error_rate'] - baseline_metrics['error_rate']

        # Detect drift
        refusal_drift = current_metrics['refusal_rate'] > self.refusal_threshold
        toxicity_drift = current_metrics['toxicity_rate'] > self.toxicity_threshold
        error_drift = current_metrics['error_rate'] > 0.10  # 10% error rate threshold

        # Response length anomaly (> 50% change)
        length_change_pct = 0
        if baseline_metrics['avg_response_length'] > 0:
            length_change_pct = abs(
                current_metrics['avg_response_length'] - baseline_metrics['avg_response_length']
            ) / baseline_metrics['avg_response_length']

        length_anomaly = length_change_pct > 0.5

        drift_detected = refusal_drift or toxicity_drift or error_drift or length_anomaly

        # Calculate drift score
        drift_score = max(
            current_metrics['refusal_rate'] / self.refusal_threshold if self.refusal_threshold > 0 else 0,
            current_metrics['toxicity_rate'] / self.toxicity_threshold if self.toxicity_threshold > 0 else 0,
            current_metrics['error_rate'] / 0.10,
            length_change_pct / 0.5
        )

        report = {
            'timestamp': now.isoformat(),
            'drift_detected': drift_detected,
            'drift_score': min(float(drift_score), 1.0),
            'baseline_period': {
                'start': baseline_start.isoformat(),
                'end': baseline_end.isoformat(),
                'metrics': baseline_metrics
            },
            'current_period': {
                'start': current_start.isoformat(),
                'end': current_end.isoformat(),
                'metrics': current_metrics
            },
            'changes': {
                'refusal_rate_change': float(refusal_change),
                'refusal_drift_detected': refusal_drift,
                'toxicity_rate_change': float(toxicity_change),
                'toxicity_drift_detected': toxicity_drift,
                'error_rate_change': float(error_change),
                'error_drift_detected': error_drift,
                'response_length_change_pct': float(length_change_pct * 100),
                'length_anomaly_detected': length_anomaly
            },
            'thresholds': {
                'refusal_rate': self.refusal_threshold,
                'toxicity_rate': self.toxicity_threshold,
                'error_rate': 0.10
            }
        }

        logger.info(f"Behavior drift detection complete: {'DRIFT DETECTED' if drift_detected else 'NO DRIFT'}")

        if refusal_drift:
            logger.warning(f"Refusal rate {current_metrics['refusal_rate']:.2%} exceeds threshold {self.refusal_threshold:.2%}")
        if toxicity_drift:
            logger.warning(f"Toxicity rate {current_metrics['toxicity_rate']:.2%} exceeds threshold {self.toxicity_threshold:.2%}")
        if error_drift:
            logger.warning(f"Error rate {current_metrics['error_rate']:.2%} exceeds 10% threshold")

        return report

    def analyze_refusal_patterns(
        self,
        days: int = 7,
        limit: int = 20
    ) -> List[Dict]:
        """
        Analyze recent refusals to identify patterns

        Returns:
            List of recent refusal examples with patterns
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        start_date = datetime.now() - timedelta(days=days)

        cur.execute("""
            SELECT user_query, model_response, timestamp
            FROM interaction_log
            WHERE timestamp >= %s
            AND refusal_flag = true
            ORDER BY timestamp DESC
            LIMIT %s
        """, (start_date, limit))

        refusals = []
        for row in cur.fetchall():
            refusals.append({
                'query': row[0],
                'response': row[1],
                'timestamp': row[2].isoformat()
            })

        cur.close()
        conn.close()

        return refusals


if __name__ == '__main__':
    # Example usage
    DB_CONNECTION = os.getenv(
        'SUPABASE_DB_URL',
        'postgresql://user:password@localhost:5432/mlops'
    )
    OPENAI_KEY = os.getenv('OPENAI_API_KEY')

    monitor = BehaviorMetricsMonitor(
        db_connection_string=DB_CONNECTION,
        refusal_rate_threshold=0.10,
        toxicity_rate_threshold=0.05,
        openai_api_key=OPENAI_KEY
    )

    # Detect behavior drift
    report = monitor.detect_behavior_drift(
        baseline_days=30,
        current_days=7
    )

    print("\n" + "="*70)
    print("BEHAVIOR METRICS DRIFT DETECTION REPORT")
    print("="*70)
    print(f"Timestamp: {report['timestamp']}")
    print(f"Drift Detected: {report['drift_detected']}")
    print(f"Drift Score: {report['drift_score']:.3f}")
    print("\nBaseline Metrics:")
    for key, value in report['baseline_period']['metrics'].items():
        if isinstance(value, float):
            print(f"  {key}: {value:.4f}")
        else:
            print(f"  {key}: {value}")
    print("\nCurrent Metrics:")
    for key, value in report['current_period']['metrics'].items():
        if isinstance(value, float):
            print(f"  {key}: {value:.4f}")
        else:
            print(f"  {key}: {value}")
    print("\nChanges Detected:")
    for key, value in report['changes'].items():
        if isinstance(value, bool):
            print(f"  {key}: {'YES' if value else 'NO'}")
        else:
            print(f"  {key}: {value:.4f}")
    print("="*70)
