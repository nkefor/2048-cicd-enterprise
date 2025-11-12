"""
A/B Test Manager for MLOps Platform
Manages A/B tests, analyzes results, and promotes winning models
"""

import argparse
import os
import json
from datetime import datetime, timedelta
from typing import Dict, List
import numpy as np
from scipy import stats
from azure.cosmos import CosmosClient
from azure.storage.blob import BlobServiceClient
import pandas as pd


class ABTestManager:
    """Manages A/B testing for ML models"""

    def __init__(self, cosmos_endpoint: str, cosmos_key: str):
        self.cosmos_client = CosmosClient(cosmos_endpoint, cosmos_key)
        self.database = self.cosmos_client.get_database_client("mlops")
        self.experiments_container = self.database.get_container_client("experiments")

    def get_experiment_data(self, experiment_id: str, days: int = 7) -> pd.DataFrame:
        """Fetch experiment data from Cosmos DB"""
        cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

        query = f"""
            SELECT *
            FROM c
            WHERE c.experiment_id = '{experiment_id}'
            AND c.timestamp >= '{cutoff_date}'
        """

        items = list(self.experiments_container.query_items(
            query=query,
            enable_cross_partition_query=True
        ))

        if not items:
            print(f"No data found for experiment {experiment_id}")
            return pd.DataFrame()

        return pd.DataFrame(items)

    def analyze_ab_test(self, experiment_id: str, metric: str = "probability") -> Dict:
        """
        Analyze A/B test results using statistical testing
        Returns comparison between model A and model B
        """
        df = self.get_experiment_data(experiment_id)

        if df.empty:
            return {"error": "No data available for analysis"}

        # Split data by model version
        model_a_data = df[df['model_version'].str.contains('_A')]
        model_b_data = df[df['model_version'].str.contains('_B')]

        if model_a_data.empty or model_b_data.empty:
            return {"error": "Insufficient data for both variants"}

        # Extract metrics
        metric_a = model_a_data[metric].values
        metric_b = model_b_data[metric].values

        # Perform statistical tests
        t_stat, p_value = stats.ttest_ind(metric_a, metric_b)

        # Calculate statistics
        results = {
            "experiment_id": experiment_id,
            "metric": metric,
            "model_a": {
                "count": len(metric_a),
                "mean": float(np.mean(metric_a)),
                "std": float(np.std(metric_a)),
                "median": float(np.median(metric_a)),
                "min": float(np.min(metric_a)),
                "max": float(np.max(metric_a))
            },
            "model_b": {
                "count": len(metric_b),
                "mean": float(np.mean(metric_b)),
                "std": float(np.std(metric_b)),
                "median": float(np.median(metric_b)),
                "min": float(np.min(metric_b)),
                "max": float(np.max(metric_b))
            },
            "statistical_test": {
                "t_statistic": float(t_stat),
                "p_value": float(p_value),
                "significant": p_value < 0.05,
                "confidence_level": 0.95
            },
            "recommendation": self._get_recommendation(metric_a, metric_b, p_value)
        }

        # Calculate lift
        baseline_mean = results["model_a"]["mean"]
        variant_mean = results["model_b"]["mean"]
        lift = ((variant_mean - baseline_mean) / baseline_mean) * 100 if baseline_mean != 0 else 0
        results["lift_percentage"] = float(lift)

        return results

    def _get_recommendation(self, metric_a: np.ndarray, metric_b: np.ndarray, p_value: float) -> str:
        """Generate recommendation based on statistical analysis"""
        mean_a = np.mean(metric_a)
        mean_b = np.mean(metric_b)

        if p_value >= 0.05:
            return "No statistically significant difference. Continue testing or keep current model."

        if mean_b > mean_a:
            improvement = ((mean_b - mean_a) / mean_a) * 100
            return f"Model B shows {improvement:.2f}% improvement. Recommend promoting Model B."
        else:
            degradation = ((mean_a - mean_b) / mean_a) * 100
            return f"Model B shows {degradation:.2f}% degradation. Recommend keeping Model A."

    def generate_report(self, experiment_id: str, output_file: str = None) -> Dict:
        """Generate comprehensive A/B test report"""
        print(f"\n{'='*80}")
        print(f"A/B Test Analysis Report")
        print(f"{'='*80}\n")

        # Analyze main metrics
        probability_results = self.analyze_ab_test(experiment_id, metric="probability")
        latency_results = self.analyze_ab_test(experiment_id, metric="latency_ms")

        report = {
            "experiment_id": experiment_id,
            "generated_at": datetime.utcnow().isoformat(),
            "prediction_confidence": probability_results,
            "latency": latency_results
        }

        # Print results
        print(f"Experiment ID: {experiment_id}")
        print(f"Generated: {report['generated_at']}\n")

        print("=" * 80)
        print("PREDICTION CONFIDENCE ANALYSIS")
        print("=" * 80)
        self._print_metric_analysis(probability_results)

        print("\n" + "=" * 80)
        print("LATENCY ANALYSIS")
        print("=" * 80)
        self._print_metric_analysis(latency_results)

        # Save report
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"\n✅ Report saved to {output_file}")

        return report

    def _print_metric_analysis(self, results: Dict):
        """Print formatted metric analysis"""
        if "error" in results:
            print(f"Error: {results['error']}")
            return

        print(f"\nMetric: {results['metric']}")
        print(f"\nModel A (Champion):")
        print(f"  Count: {results['model_a']['count']}")
        print(f"  Mean: {results['model_a']['mean']:.4f}")
        print(f"  Std: {results['model_a']['std']:.4f}")

        print(f"\nModel B (Challenger):")
        print(f"  Count: {results['model_b']['count']}")
        print(f"  Mean: {results['model_b']['mean']:.4f}")
        print(f"  Std: {results['model_b']['std']:.4f}")

        print(f"\nStatistical Test:")
        print(f"  T-statistic: {results['statistical_test']['t_statistic']:.4f}")
        print(f"  P-value: {results['statistical_test']['p_value']:.4f}")
        print(f"  Significant: {'Yes' if results['statistical_test']['significant'] else 'No'}")
        print(f"  Lift: {results['lift_percentage']:.2f}%")

        print(f"\n📊 Recommendation:")
        print(f"  {results['recommendation']}")

    def get_active_experiments(self) -> List[Dict]:
        """Get list of active experiments"""
        # Get experiments from last 30 days
        cutoff_date = (datetime.utcnow() - timedelta(days=30)).isoformat()

        query = f"""
            SELECT DISTINCT c.experiment_id
            FROM c
            WHERE c.timestamp >= '{cutoff_date}'
        """

        items = list(self.experiments_container.query_items(
            query=query,
            enable_cross_partition_query=True
        ))

        return items


def main():
    parser = argparse.ArgumentParser(description='A/B Test Manager')

    parser.add_argument('--cosmos-endpoint', type=str, required=True,
                        help='Cosmos DB endpoint')
    parser.add_argument('--cosmos-key', type=str, required=True,
                        help='Cosmos DB key')
    parser.add_argument('--experiment-id', type=str,
                        help='Experiment ID to analyze')
    parser.add_argument('--list-experiments', action='store_true',
                        help='List active experiments')
    parser.add_argument('--output', type=str,
                        help='Output file for report')
    parser.add_argument('--days', type=int, default=7,
                        help='Number of days to analyze')

    args = parser.parse_args()

    # Initialize manager
    manager = ABTestManager(args.cosmos_endpoint, args.cosmos_key)

    if args.list_experiments:
        print("\n🔬 Active Experiments:")
        experiments = manager.get_active_experiments()
        for exp in experiments:
            print(f"  - {exp['experiment_id']}")

    elif args.experiment_id:
        # Generate report
        report = manager.generate_report(args.experiment_id, args.output)

    else:
        print("Please specify --experiment-id or --list-experiments")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
