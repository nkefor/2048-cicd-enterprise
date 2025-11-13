#!/usr/bin/env python3
"""
Model Fine-Tuner
Triggers model fine-tuning when performance drift is detected
"""

import openai
import psycopg2
from typing import Dict
import logging
import json

logger = logging.getLogger(__name__)


class ModelFineT

uner:
    """Fine-tune model on recent data"""

    def __init__(self, db_connection_string: str, openai_api_key: str = None):
        self.conn_string = db_connection_string
        if openai_api_key:
            openai.api_key = openai_api_key

    def prepare_training_data(self, limit: int = 1000) -> str:
        """
        Prepare training data from recent interactions
        Returns path to JSONL file
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        cur.execute("""
            SELECT user_query, model_response
            FROM interaction_log
            WHERE timestamp > NOW() - INTERVAL '30 days'
            AND user_feedback_score >= 4
            ORDER BY timestamp DESC
            LIMIT %s
        """, (limit,))

        training_data = []
        for query, response in cur.fetchall():
            training_data.append({
                "messages": [
                    {"role": "user", "content": query},
                    {"role": "assistant", "content": response}
                ]
            })

        cur.close()
        conn.close()

        # Save to JSONL
        filename = "training_data.jsonl"
        with open(filename, 'w') as f:
            for item in training_data:
                f.write(json.dumps(item) + '\n')

        logger.info(f"Prepared {len(training_data)} training examples")
        return filename

    def fine_tune(self) -> Dict:
        """
        Trigger fine-tuning:
        1. Prepare training data
        2. Upload to OpenAI
        3. Start fine-tuning job
        """
        logger.info("Starting model fine-tuning...")

        # Prepare data
        training_file = self.prepare_training_data()

        # Upload to OpenAI
        with open(training_file, 'rb') as f:
            upload_response = openai.File.create(
                file=f,
                purpose='fine-tune'
            )

        file_id = upload_response['id']
        logger.info(f"Uploaded training file: {file_id}")

        # Start fine-tuning
        finetune_response = openai.FineTuningJob.create(
            training_file=file_id,
            model="gpt-3.5-turbo-0613"
        )

        job_id = finetune_response['id']
        logger.info(f"Fine-tuning job started: {job_id}")

        return {
            'status': 'initiated',
            'job_id': job_id,
            'file_id': file_id
        }
