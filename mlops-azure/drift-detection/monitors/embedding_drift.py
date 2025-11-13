#!/usr/bin/env python3
"""
Embedding Drift Monitor
Detects distribution shifts in text embeddings using statistical methods
"""

import numpy as np
from typing import List, Dict, Tuple, Optional
from datetime import datetime, timedelta
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
import psycopg2
from scipy.spatial.distance import cosine, euclidean
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EmbeddingDriftDetector:
    """
    Detects drift in embedding distributions using multiple methods:
    - Centroid distance (Euclidean and Cosine)
    - Cluster analysis (KMeans + Silhouette)
    - Population Stability Index (PSI)
    - Variance changes
    """

    def __init__(
        self,
        db_connection_string: str,
        distance_threshold: float = 0.15,
        silhouette_threshold: float = 0.2,
        variance_threshold: float = 0.3
    ):
        """
        Initialize drift detector

        Args:
            db_connection_string: PostgreSQL connection string with pgvector
            distance_threshold: Max acceptable centroid distance
            silhouette_threshold: Min acceptable silhouette score change
            variance_threshold: Max acceptable variance increase
        """
        self.conn_string = db_connection_string
        self.distance_threshold = distance_threshold
        self.silhouette_threshold = silhouette_threshold
        self.variance_threshold = variance_threshold

    def get_embeddings(
        self,
        start_date: datetime,
        end_date: datetime,
        embedding_type: str = 'query'
    ) -> np.ndarray:
        """
        Fetch embeddings from database for a time period

        Args:
            start_date: Start of time window
            end_date: End of time window
            embedding_type: Type of embedding ('query', 'doc', 'all')

        Returns:
            Array of embeddings (n_samples, embedding_dim)
        """
        conn = psycopg2.connect(self.conn_string)
        cur = conn.cursor()

        query = """
            SELECT embedding
            FROM embeddings_log
            WHERE timestamp >= %s
            AND timestamp < %s
        """

        if embedding_type != 'all':
            query += " AND type = %s"
            cur.execute(query, (start_date, end_date, embedding_type))
        else:
            cur.execute(query, (start_date, end_date))

        rows = cur.fetchall()
        cur.close()
        conn.close()

        if not rows:
            logger.warning(f"No embeddings found for period {start_date} to {end_date}")
            return np.array([])

        # Convert to numpy array
        embeddings = np.array([row[0] for row in rows])
        logger.info(f"Retrieved {len(embeddings)} embeddings")

        return embeddings

    def compute_centroid_distance(
        self,
        baseline_embeddings: np.ndarray,
        current_embeddings: np.ndarray
    ) -> Dict[str, float]:
        """
        Compute distance between centroids of two embedding distributions

        Returns:
            Dictionary with euclidean and cosine distances
        """
        if len(baseline_embeddings) == 0 or len(current_embeddings) == 0:
            return {'euclidean': 0.0, 'cosine': 0.0, 'drift_detected': False}

        baseline_centroid = np.mean(baseline_embeddings, axis=0)
        current_centroid = np.mean(current_embeddings, axis=0)

        # Normalize for cosine
        baseline_norm = baseline_centroid / (np.linalg.norm(baseline_centroid) + 1e-10)
        current_norm = current_centroid / (np.linalg.norm(current_centroid) + 1e-10)

        euclidean_dist = euclidean(baseline_centroid, current_centroid)
        cosine_dist = cosine(baseline_norm, current_norm)

        drift_detected = (
            euclidean_dist > self.distance_threshold or
            cosine_dist > self.distance_threshold
        )

        return {
            'euclidean_distance': float(euclidean_dist),
            'cosine_distance': float(cosine_dist),
            'drift_detected': drift_detected,
            'threshold': self.distance_threshold
        }

    def compute_variance_change(
        self,
        baseline_embeddings: np.ndarray,
        current_embeddings: np.ndarray
    ) -> Dict[str, float]:
        """
        Compute change in variance (spread) of embeddings

        High variance increase = more diverse/scattered queries = potential drift
        """
        if len(baseline_embeddings) == 0 or len(current_embeddings) == 0:
            return {'variance_change': 0.0, 'drift_detected': False}

        baseline_var = np.var(baseline_embeddings)
        current_var = np.var(current_embeddings)

        variance_change = abs(current_var - baseline_var) / (baseline_var + 1e-10)
        drift_detected = variance_change > self.variance_threshold

        return {
            'baseline_variance': float(baseline_var),
            'current_variance': float(current_var),
            'variance_change_pct': float(variance_change * 100),
            'drift_detected': drift_detected,
            'threshold': self.variance_threshold
        }

    def compute_cluster_drift(
        self,
        baseline_embeddings: np.ndarray,
        current_embeddings: np.ndarray,
        n_clusters: int = 5,
        n_components: int = 50
    ) -> Dict[str, float]:
        """
        Detect drift using clustering analysis

        Method:
        1. Reduce dimensionality with PCA
        2. Cluster both distributions
        3. Compare silhouette scores and cluster centroids

        Returns:
            Drift metrics from clustering analysis
        """
        if len(baseline_embeddings) < n_clusters or len(current_embeddings) < n_clusters:
            logger.warning("Not enough samples for clustering")
            return {'drift_detected': False, 'reason': 'insufficient_samples'}

        # Reduce dimensionality
        n_components = min(n_components, baseline_embeddings.shape[1])
        pca = PCA(n_components=n_components)

        baseline_reduced = pca.fit_transform(baseline_embeddings)
        current_reduced = pca.transform(current_embeddings)

        # Cluster baseline
        kmeans_baseline = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        baseline_labels = kmeans_baseline.fit_predict(baseline_reduced)
        baseline_silhouette = silhouette_score(baseline_reduced, baseline_labels)

        # Cluster current
        kmeans_current = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        current_labels = kmeans_current.fit_predict(current_reduced)
        current_silhouette = silhouette_score(current_reduced, current_labels)

        silhouette_change = baseline_silhouette - current_silhouette

        # Compare cluster centroids
        baseline_centroids = kmeans_baseline.cluster_centers_
        current_centroids = kmeans_current.cluster_centers_

        # Average distance between matched centroids
        centroid_distances = []
        for i in range(n_clusters):
            dist = euclidean(baseline_centroids[i], current_centroids[i])
            centroid_distances.append(dist)

        avg_centroid_shift = np.mean(centroid_distances)

        drift_detected = (
            silhouette_change > self.silhouette_threshold or
            avg_centroid_shift > self.distance_threshold
        )

        return {
            'baseline_silhouette': float(baseline_silhouette),
            'current_silhouette': float(current_silhouette),
            'silhouette_change': float(silhouette_change),
            'avg_centroid_shift': float(avg_centroid_shift),
            'n_clusters': n_clusters,
            'drift_detected': drift_detected,
            'drift_reason': 'cluster_structure_changed' if drift_detected else None
        }

    def compute_population_stability_index(
        self,
        baseline_embeddings: np.ndarray,
        current_embeddings: np.ndarray,
        n_bins: int = 10
    ) -> Dict[str, float]:
        """
        Compute Population Stability Index (PSI) for drift detection

        PSI < 0.1: No significant drift
        PSI 0.1-0.2: Moderate drift
        PSI > 0.2: Significant drift
        """
        if len(baseline_embeddings) == 0 or len(current_embeddings) == 0:
            return {'psi': 0.0, 'drift_detected': False}

        # For high-dimensional embeddings, use first principal component for PSI
        pca = PCA(n_components=1)
        baseline_1d = pca.fit_transform(baseline_embeddings).flatten()
        current_1d = pca.transform(current_embeddings).flatten()

        # Create bins based on baseline
        bins = np.linspace(baseline_1d.min(), baseline_1d.max(), n_bins + 1)

        # Calculate percentages in each bin
        baseline_counts, _ = np.histogram(baseline_1d, bins=bins)
        current_counts, _ = np.histogram(current_1d, bins=bins)

        baseline_pct = (baseline_counts + 1) / (len(baseline_1d) + n_bins)  # Smoothing
        current_pct = (current_counts + 1) / (len(current_1d) + n_bins)

        # Calculate PSI
        psi = np.sum((current_pct - baseline_pct) * np.log(current_pct / baseline_pct))

        drift_detected = psi > 0.2

        return {
            'psi': float(psi),
            'drift_level': 'high' if psi > 0.2 else 'moderate' if psi > 0.1 else 'low',
            'drift_detected': drift_detected
        }

    def detect_drift(
        self,
        baseline_days: int = 30,
        current_days: int = 7,
        embedding_type: str = 'query'
    ) -> Dict:
        """
        Run comprehensive drift detection

        Args:
            baseline_days: Number of days to use as baseline (e.g., 30)
            current_days: Number of recent days to analyze (e.g., 7)
            embedding_type: Type of embeddings to analyze

        Returns:
            Complete drift report with all metrics
        """
        logger.info(f"Starting drift detection for {embedding_type} embeddings")

        now = datetime.now()
        current_end = now
        current_start = now - timedelta(days=current_days)
        baseline_end = current_start
        baseline_start = baseline_end - timedelta(days=baseline_days)

        # Fetch embeddings
        baseline_embeddings = self.get_embeddings(baseline_start, baseline_end, embedding_type)
        current_embeddings = self.get_embeddings(current_start, current_end, embedding_type)

        if len(baseline_embeddings) == 0 or len(current_embeddings) == 0:
            return {
                'timestamp': now.isoformat(),
                'error': 'Insufficient data for drift detection',
                'baseline_count': len(baseline_embeddings),
                'current_count': len(current_embeddings)
            }

        # Run all detection methods
        centroid_results = self.compute_centroid_distance(baseline_embeddings, current_embeddings)
        variance_results = self.compute_variance_change(baseline_embeddings, current_embeddings)
        cluster_results = self.compute_cluster_drift(baseline_embeddings, current_embeddings)
        psi_results = self.compute_population_stability_index(baseline_embeddings, current_embeddings)

        # Overall drift decision (if any method detects drift)
        drift_detected = (
            centroid_results.get('drift_detected', False) or
            variance_results.get('drift_detected', False) or
            cluster_results.get('drift_detected', False) or
            psi_results.get('drift_detected', False)
        )

        # Calculate drift score (0-1)
        drift_score = np.mean([
            centroid_results.get('euclidean_distance', 0) / self.distance_threshold,
            variance_results.get('variance_change_pct', 0) / 100,
            cluster_results.get('silhouette_change', 0) / self.silhouette_threshold,
            psi_results.get('psi', 0) / 0.2
        ])

        report = {
            'timestamp': now.isoformat(),
            'embedding_type': embedding_type,
            'baseline_period': {
                'start': baseline_start.isoformat(),
                'end': baseline_end.isoformat(),
                'sample_count': len(baseline_embeddings)
            },
            'current_period': {
                'start': current_start.isoformat(),
                'end': current_end.isoformat(),
                'sample_count': len(current_embeddings)
            },
            'drift_detected': drift_detected,
            'drift_score': float(np.clip(drift_score, 0, 1)),
            'methods': {
                'centroid_distance': centroid_results,
                'variance_change': variance_results,
                'cluster_analysis': cluster_results,
                'population_stability_index': psi_results
            }
        }

        logger.info(f"Drift detection complete: {'DRIFT DETECTED' if drift_detected else 'NO DRIFT'}")
        logger.info(f"Drift score: {drift_score:.3f}")

        return report


if __name__ == '__main__':
    # Example usage
    import os

    DB_CONNECTION = os.getenv(
        'SUPABASE_DB_URL',
        'postgresql://user:password@localhost:5432/mlops'
    )

    detector = EmbeddingDriftDetector(
        db_connection_string=DB_CONNECTION,
        distance_threshold=0.15,
        silhouette_threshold=0.2,
        variance_threshold=0.3
    )

    # Detect drift in query embeddings
    report = detector.detect_drift(
        baseline_days=30,
        current_days=7,
        embedding_type='query'
    )

    print("\n" + "="*70)
    print("EMBEDDING DRIFT DETECTION REPORT")
    print("="*70)
    print(f"Timestamp: {report['timestamp']}")
    print(f"Drift Detected: {report['drift_detected']}")
    print(f"Drift Score: {report['drift_score']:.3f}")
    print("\nBaseline Period:")
    print(f"  {report['baseline_period']['start']} to {report['baseline_period']['end']}")
    print(f"  Samples: {report['baseline_period']['sample_count']}")
    print("\nCurrent Period:")
    print(f"  {report['current_period']['start']} to {report['current_period']['end']}")
    print(f"  Samples: {report['current_period']['sample_count']}")
    print("\nMethods:")
    for method, results in report['methods'].items():
        print(f"\n  {method}:")
        for key, value in results.items():
            if key != 'drift_detected':
                print(f"    {key}: {value}")
    print("="*70)
