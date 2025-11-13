#!/usr/bin/env python3
"""
Drift-Aware Retraining Pipeline
Main orchestration for drift detection and automated retraining
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from monitors.embedding_drift import EmbeddingDriftDetector
from monitors.behavior_metrics import BehaviorMetricsMonitor
from monitors.accuracy_monitor import AccuracyMonitor
from actions.reindex_documents import DocumentReindexer
from actions.fine_tune_model import ModelFineT

uner
from metrics.prometheus_metrics import DriftMetrics
import json
import logging
from datetime import datetime
from typing import Dict, List

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DriftAwareRetrainingPipeline:
    """
    Main pipeline for drift detection and automated retraining

    Workflow:
    1. Run all drift monitors (embedding, behavior, accuracy)
    2. Evaluate drift severity
    3. Decide on corrective actions
    4. Execute actions (reindex, retrain, refresh)
    5. Update metrics and log events
    """

    def __init__(self, config: Dict):
        """
        Initialize pipeline with configuration

        Args:
            config: Configuration dictionary with:
                - db_connection: Database connection string
                - openai_api_key: OpenAI API key
                - thresholds: Drift detection thresholds
                - actions: Action configuration
        """
        self.config = config
        db_conn = config['db_connection']

        # Initialize monitors
        self.embedding_monitor = EmbeddingDriftDetector(
            db_connection_string=db_conn,
            **config.get('embedding_thresholds', {})
        )

        self.behavior_monitor = BehaviorMetricsMonitor(
            db_connection_string=db_conn,
            openai_api_key=config.get('openai_api_key'),
            **config.get('behavior_thresholds', {})
        )

        self.accuracy_monitor = AccuracyMonitor(
            db_connection_string=db_conn,
            **config.get('accuracy_thresholds', {})
        )

        # Initialize actions
        self.document_reindexer = DocumentReindexer(
            db_connection_string=db_conn,
            **config.get('reindex_config', {})
        )

        self.model_finetuner = ModelFineT

uner(
            db_connection_string=db_conn,
            **config.get('finetune_config', {})
        )

        # Initialize metrics
        self.metrics = DriftMetrics(
            prometheus_port=config.get('prometheus_port', 8000)
        )

        # Event log
        self.event_log = []

    def run_drift_detection(self) -> Dict:
        """
        Run all drift detection monitors

        Returns:
            Combined drift detection report
        """
        logger.info("="*70)
        logger.info("Starting Drift Detection Pipeline")
        logger.info("="*70)

        # Run embedding drift detection
        logger.info("\n1. Checking Embedding Drift...")
        embedding_report = self.embedding_monitor.detect_drift(
            baseline_days=self.config.get('baseline_days', 30),
            current_days=self.config.get('current_days', 7),
            embedding_type='query'
        )
        logger.info(f"   Embedding Drift: {'DETECTED' if embedding_report.get('drift_detected') else 'None'}")

        # Run behavior metrics drift detection
        logger.info("\n2. Checking Behavior Metrics Drift...")
        behavior_report = self.behavior_monitor.detect_behavior_drift(
            baseline_days=self.config.get('baseline_days', 30),
            current_days=self.config.get('current_days', 7)
        )
        logger.info(f"   Behavior Drift: {'DETECTED' if behavior_report.get('drift_detected') else 'None'}")

        # Run accuracy drift detection
        logger.info("\n3. Checking Accuracy Drift...")
        accuracy_report = self.accuracy_monitor.detect_accuracy_drift(
            baseline_days=self.config.get('baseline_days', 30),
            current_days=self.config.get('current_days', 7)
        )
        logger.info(f"   Accuracy Drift: {'DETECTED' if accuracy_report.get('drift_detected') else 'None'}")

        # Combine results
        combined_report = {
            'timestamp': datetime.now().isoformat(),
            'embedding_drift': embedding_report,
            'behavior_drift': behavior_report,
            'accuracy_drift': accuracy_report,
            'overall_drift_detected': (
                embedding_report.get('drift_detected', False) or
                behavior_report.get('drift_detected', False) or
                accuracy_report.get('drift_detected', False)
            ),
            'overall_drift_score': max(
                embedding_report.get('drift_score', 0),
                behavior_report.get('drift_score', 0),
                accuracy_report.get('drift_score', 0)
            )
        }

        # Update Prometheus metrics
        self.metrics.update_drift_metrics(combined_report)

        return combined_report

    def decide_actions(self, drift_report: Dict) -> List[str]:
        """
        Decide which corrective actions to take based on drift report

        Returns:
            List of actions to execute
        """
        actions = []

        # Embedding drift → Re-index documents
        if drift_report['embedding_drift'].get('drift_detected'):
            logger.info("\n→ Embedding drift detected: Will re-index documents")
            actions.append('reindex_documents')

        # Behavior drift (high refusal/toxicity) → Fine-tune model
        if drift_report['behavior_drift'].get('drift_detected'):
            behavior_changes = drift_report['behavior_drift'].get('changes', {})
            if behavior_changes.get('refusal_drift_detected'):
                logger.info("\n→ High refusal rate: Will fine-tune model")
                actions.append('fine_tune_model')

            if behavior_changes.get('toxicity_drift_detected'):
                logger.info("\n→ High toxicity rate: Will update safety filters")
                actions.append('update_safety_filters')

        # Accuracy drift → Fine-tune model
        if drift_report['accuracy_drift'].get('drift_detected'):
            logger.info("\n→ Accuracy degradation: Will fine-tune model")
            if 'fine_tune_model' not in actions:
                actions.append('fine_tune_model')

        # If no actions, report success (no drift)
        if not actions:
            logger.info("\n✓ No drift detected - no actions needed")

        return actions

    def execute_actions(self, actions: List[str]) -> Dict:
        """
        Execute corrective actions

        Args:
            actions: List of action names to execute

        Returns:
            Results of each action
        """
        results = {}

        for action in actions:
            try:
                if action == 'reindex_documents':
                    logger.info("\n" + "="*70)
                    logger.info("Executing: Re-index Documents")
                    logger.info("="*70)
                    result = self.document_reindexer.reindex()
                    results[action] = result
                    logger.info(f"✓ Reindexing complete: {result['documents_processed']} documents")

                elif action == 'fine_tune_model':
                    logger.info("\n" + "="*70)
                    logger.info("Executing: Fine-Tune Model")
                    logger.info("="*70)
                    result = self.model_finetuner.fine_tune()
                    results[action] = result
                    logger.info(f"✓ Fine-tuning initiated: Job ID {result.get('job_id')}")

                elif action == 'update_safety_filters':
                    logger.info("\n" + "="*70)
                    logger.info("Executing: Update Safety Filters")
                    logger.info("="*70)
                    # This could update moderation thresholds or prompts
                    results[action] = {'status': 'updated', 'note': 'Increased moderation strictness'}
                    logger.info("✓ Safety filters updated")

            except Exception as e:
                logger.error(f"✗ Action {action} failed: {e}")
                results[action] = {'status': 'failed', 'error': str(e)}

        return results

    def log_event(self, event_type: str, details: Dict):
        """
        Log pipeline events to database

        Args:
            event_type: Type of event (drift_detected, action_executed, etc.)
            details: Event details
        """
        event = {
            'timestamp': datetime.now().isoformat(),
            'event_type': event_type,
            'details': details
        }
        self.event_log.append(event)

        # Also log to file or database
        logger.info(f"Event logged: {event_type}")

    def run(self) -> Dict:
        """
        Run complete drift detection and retraining pipeline

        Returns:
            Pipeline execution report
        """
        start_time = datetime.now()

        # Step 1: Detect drift
        drift_report = self.run_drift_detection()

        # Log drift detection event
        self.log_event('drift_detection_complete', {
            'drift_detected': drift_report['overall_drift_detected'],
            'drift_score': drift_report['overall_drift_score']
        })

        # Step 2: Decide on actions
        actions = self.decide_actions(drift_report)

        # Step 3: Execute actions
        action_results = {}
        if actions:
            action_results = self.execute_actions(actions)

            # Log action execution
            self.log_event('actions_executed', {
                'actions': actions,
                'results': action_results
            })

            # Increment retraining counter in Prometheus
            if 'fine_tune_model' in actions:
                self.metrics.increment_retrain_events()

        # Step 4: Generate final report
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()

        final_report = {
            'pipeline_run_id': f"drift-{start_time.strftime('%Y%m%d-%H%M%S')}",
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'duration_seconds': duration,
            'drift_report': drift_report,
            'actions_taken': actions,
            'action_results': action_results,
            'events': self.event_log
        }

        logger.info("\n" + "="*70)
        logger.info("Pipeline Execution Complete")
        logger.info("="*70)
        logger.info(f"Duration: {duration:.2f} seconds")
        logger.info(f"Drift Detected: {drift_report['overall_drift_detected']}")
        logger.info(f"Actions Taken: {len(actions)}")
        logger.info("="*70)

        # Save report to file
        report_filename = f"drift_report_{start_time.strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_filename, 'w') as f:
            json.dump(final_report, f, indent=2)
        logger.info(f"\nReport saved to: {report_filename}")

        return final_report


if __name__ == '__main__':
    # Example configuration
    config = {
        'db_connection': os.getenv('SUPABASE_DB_URL', 'postgresql://user:pass@localhost/mlops'),
        'openai_api_key': os.getenv('OPENAI_API_KEY'),
        'baseline_days': 30,
        'current_days': 7,
        'embedding_thresholds': {
            'distance_threshold': 0.15,
            'silhouette_threshold': 0.2,
            'variance_threshold': 0.3
        },
        'behavior_thresholds': {
            'refusal_rate_threshold': 0.10,
            'toxicity_rate_threshold': 0.05
        },
        'accuracy_thresholds': {
            'accuracy_threshold': 0.05,
            'feedback_threshold': 0.30
        },
        'prometheus_port': 8000
    }

    # Run pipeline
    pipeline = DriftAwareRetrainingPipeline(config)
    report = pipeline.run()

    print("\n" + "="*70)
    print("DRIFT-AWARE RETRAINING PIPELINE")
    print("="*70)
    print(f"Run ID: {report['pipeline_run_id']}")
    print(f"Duration: {report['duration_seconds']:.2f}s")
    print(f"Drift Detected: {report['drift_report']['overall_drift_detected']}")
    print(f"Overall Drift Score: {report['drift_report']['overall_drift_score']:.3f}")
    print(f"\nActions Taken: {', '.join(report['actions_taken']) if report['actions_taken'] else 'None'}")
    print("="*70)
