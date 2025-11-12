"""
ML Model Training Pipeline for Azure ML
Trains a classification model with MLflow tracking
"""

import argparse
import os
import json
from datetime import datetime
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from sklearn.preprocessing import StandardScaler
import joblib
import mlflow
import mlflow.sklearn
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


class MLModelTrainer:
    """Trains and evaluates ML models with MLflow tracking"""

    def __init__(self, model_name: str, experiment_name: str):
        self.model_name = model_name
        self.experiment_name = experiment_name
        self.model = None
        self.scaler = StandardScaler()

    def load_data(self, data_path: str = None):
        """Load and prepare training data"""
        if data_path and os.path.exists(data_path):
            df = pd.read_csv(data_path)
        else:
            # Generate synthetic data for demo
            print("Generating synthetic dataset...")
            np.random.seed(42)
            n_samples = 10000

            df = pd.DataFrame({
                'feature_1': np.random.randn(n_samples),
                'feature_2': np.random.randn(n_samples),
                'feature_3': np.random.randn(n_samples),
                'feature_4': np.random.randn(n_samples),
                'feature_5': np.random.randn(n_samples),
            })

            # Create target based on features
            df['target'] = (
                (df['feature_1'] > 0).astype(int) +
                (df['feature_2'] > 0.5).astype(int) +
                (df['feature_3'] < -0.5).astype(int)
            ) > 1
            df['target'] = df['target'].astype(int)

        # Split features and target
        X = df.drop('target', axis=1)
        y = df['target']

        return train_test_split(X, y, test_size=0.2, random_state=42)

    def train_random_forest(self, X_train, y_train, n_estimators=100, max_depth=10):
        """Train Random Forest model"""
        print(f"Training Random Forest with {n_estimators} estimators...")

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)

        # Train model
        self.model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            random_state=42,
            n_jobs=-1
        )
        self.model.fit(X_train_scaled, y_train)

        return self.model

    def train_gradient_boosting(self, X_train, y_train, n_estimators=100, learning_rate=0.1):
        """Train Gradient Boosting model"""
        print(f"Training Gradient Boosting with {n_estimators} estimators...")

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)

        # Train model
        self.model = GradientBoostingClassifier(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=5,
            random_state=42
        )
        self.model.fit(X_train_scaled, y_train)

        return self.model

    def evaluate(self, X_test, y_test):
        """Evaluate model performance"""
        X_test_scaled = self.scaler.transform(X_test)

        # Predictions
        y_pred = self.model.predict(X_test_scaled)
        y_pred_proba = self.model.predict_proba(X_test_scaled)[:, 1]

        # Calculate metrics
        metrics = {
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred, average='weighted'),
            'recall': recall_score(y_test, y_pred, average='weighted'),
            'f1_score': f1_score(y_test, y_pred, average='weighted'),
            'roc_auc': roc_auc_score(y_test, y_pred_proba)
        }

        return metrics

    def save_model(self, output_dir: str):
        """Save trained model and scaler"""
        os.makedirs(output_dir, exist_ok=True)

        model_path = os.path.join(output_dir, 'model.pkl')
        scaler_path = os.path.join(output_dir, 'scaler.pkl')

        joblib.dump(self.model, model_path)
        joblib.dump(self.scaler, scaler_path)

        print(f"Model saved to {model_path}")
        print(f"Scaler saved to {scaler_path}")

        return model_path, scaler_path


def train_with_mlflow(args):
    """Main training function with MLflow tracking"""

    # Set MLflow experiment
    mlflow.set_experiment(args.experiment_name)

    # Start MLflow run
    with mlflow.start_run(run_name=f"{args.model_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"):

        # Log parameters
        mlflow.log_param("model_type", args.model_type)
        mlflow.log_param("n_estimators", args.n_estimators)
        mlflow.log_param("max_depth", args.max_depth)
        mlflow.log_param("learning_rate", args.learning_rate)

        # Initialize trainer
        trainer = MLModelTrainer(
            model_name=args.model_name,
            experiment_name=args.experiment_name
        )

        # Load data
        print("Loading data...")
        X_train, X_test, y_train, y_test = trainer.load_data(args.data_path)
        mlflow.log_param("training_samples", len(X_train))
        mlflow.log_param("test_samples", len(X_test))

        # Train model
        if args.model_type == "random_forest":
            trainer.train_random_forest(
                X_train, y_train,
                n_estimators=args.n_estimators,
                max_depth=args.max_depth
            )
        elif args.model_type == "gradient_boosting":
            trainer.train_gradient_boosting(
                X_train, y_train,
                n_estimators=args.n_estimators,
                learning_rate=args.learning_rate
            )
        else:
            raise ValueError(f"Unknown model type: {args.model_type}")

        # Evaluate model
        print("Evaluating model...")
        metrics = trainer.evaluate(X_test, y_test)

        # Log metrics
        for metric_name, metric_value in metrics.items():
            mlflow.log_metric(metric_name, metric_value)
            print(f"{metric_name}: {metric_value:.4f}")

        # Save model
        print("Saving model...")
        model_path, scaler_path = trainer.save_model(args.output_dir)

        # Log model to MLflow
        mlflow.sklearn.log_model(
            trainer.model,
            "model",
            registered_model_name=args.model_name
        )

        # Log artifacts
        mlflow.log_artifact(model_path)
        mlflow.log_artifact(scaler_path)

        # Save metrics to file
        metrics_file = os.path.join(args.output_dir, 'metrics.json')
        with open(metrics_file, 'w') as f:
            json.dump(metrics, f, indent=2)
        mlflow.log_artifact(metrics_file)

        print("\n✅ Training completed successfully!")
        print(f"Model accuracy: {metrics['accuracy']:.4f}")
        print(f"Model F1 score: {metrics['f1_score']:.4f}")

        return metrics


def main():
    parser = argparse.ArgumentParser(description='Train ML model with Azure ML')

    parser.add_argument('--model-name', type=str, default='ml-classifier',
                        help='Name of the model')
    parser.add_argument('--experiment-name', type=str, default='model-training',
                        help='MLflow experiment name')
    parser.add_argument('--model-type', type=str, default='random_forest',
                        choices=['random_forest', 'gradient_boosting'],
                        help='Type of model to train')
    parser.add_argument('--data-path', type=str, default=None,
                        help='Path to training data CSV')
    parser.add_argument('--output-dir', type=str, default='./outputs',
                        help='Output directory for model artifacts')
    parser.add_argument('--n-estimators', type=int, default=100,
                        help='Number of estimators')
    parser.add_argument('--max-depth', type=int, default=10,
                        help='Maximum depth of trees')
    parser.add_argument('--learning-rate', type=float, default=0.1,
                        help='Learning rate for gradient boosting')

    args = parser.parse_args()

    # Train model
    metrics = train_with_mlflow(args)

    return metrics


if __name__ == "__main__":
    main()
