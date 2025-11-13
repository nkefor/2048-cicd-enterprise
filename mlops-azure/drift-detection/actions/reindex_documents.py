#!/usr/bin/env python3
"""
Document Re-indexer
Re-indexes documents when content drift is detected
"""

import psycopg2
import openai
import os
from typing import Dict, List
import logging

logger = logging.getLogger(__name__)


class DocumentReindexer:
    """Re-index documents and update embeddings"""

    def __init__(self, db_connection_string: str, openai_api_key: str = None):
        self.conn_string = db_connection_string
        if openai_api_key:
            openai.api_key = openai_api_key

    def reindex(self) -> Dict:
        """
        Re-index all documents:
        1. Fetch new/updated documents
        2. Generate embeddings
        3. Update vector database
        """
        logger.info("Starting document re-indexing...")

        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        # Get documents that need reindexing
        cur.execute("""
            SELECT id, content
            FROM documents
            WHERE last_indexed IS NULL
            OR last_indexed < updated_at
            LIMIT 1000
        """)

        documents = cur.fetchall()
        processed = 0

        for doc_id, content in documents:
            try:
                # Generate embedding
                response = openai.Embedding.create(
                    input=content,
                    model="text-embedding-ada-002"
                )
                embedding = response['data'][0]['embedding']

                # Update database
                cur.execute("""
                    UPDATE documents
                    SET embedding = %s, last_indexed = NOW()
                    WHERE id = %s
                """, (embedding, doc_id))

                processed += 1

            except Exception as e:
                logger.error(f"Failed to index document {doc_id}: {e}")

        conn.commit()
        cur.close()
        conn.close()

        logger.info(f"Reindexed {processed} documents")
        return {
            'status': 'success',
            'documents_processed': processed
        }
