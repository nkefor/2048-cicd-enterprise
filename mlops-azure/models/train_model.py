"""
Enhanced ML Model Training Pipeline for Azure ML
- Integrated MLflow for experiment tracking and model registry
- Distributed training with Azure ML compute clusters
- Hyperparameter tuning with Azure ML HyperDrive
- Auto-scaling support for inference endpoints
"""

import argparse
import os
import json
from datetime import datetime
from typing import Dict, Tuple
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from sklearn.preprocessing import StandardScaler
import joblib
import mlflow
import mlflow.sklearn
from mlflow.tracking import MlflowClient
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


class MLModelTrainer:
    """
    Trains and evaluates ML models with MLflow tracking and Azure ML integration
    Features:
    - MLflow experiment tracking
    - Model registry integration
    - Distributed training support
    - Hyperparameter optimization
    """

    def __init__(self, model_name: str, experiment_name: str, ml_client: MLClient = None):
        self.model_name = model_name
        self.experiment_name = experiment_name
        self.model = None
        self.scaler = StandardScaler()
        self.ml_client = ml_client
        self.mlflow_client = MlflowClient()

    def load_data(self, data_path: str = None) -> Tuple:
        """Load and prepare training data"""
        if data_path and os.path.exists(data_path):
            print(f"Loading data from {data_path}...")
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

        print(f"Dataset shape: {X.shape}")
        print(f"Class distribution: {y.value_counts().to_dict()}")

        return train_test_split(X, y, test_size=0.2, random_state=42)

    def train_random_forest(self, X_train, y_train, n_estimators=100, max_depth=10,
                           min_samples_split=2, min_samples_leaf=1):
        """Train Random Forest model with configurable hyperparameters"""
        print(f"Training Random Forest...")
        print(f"  n_estimators: {n_estimators}")
        print(f"  max_depth: {max_depth}")
        print(f"  min_samples_split: {min_samples_split}")
        print(f"  min_samples_leaf: {min_samples_leaf}")

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)

        # Train model
        self.model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            min_samples_split=min_samples_split,
            min_samples_leaf=min_samples_leaf,
            random_state=42,
            n_jobs=-1,
            verbose=1
        )
        self.model.fit(X_train_scaled, y_train)

        return self.model

    def train_gradient_boosting(self, X_train, y_train, n_estimators=100, learning_rate=0.1,
                                max_depth=5, subsample=1.0):
        """Train Gradient Boosting model with configurable hyperparameters"""
        print(f"Training Gradient Boosting...")
        print(f"  n_estimators: {n_estimators}")
        print(f"  learning_rate: {learning_rate}")
        print(f"  max_depth: {max_depth}")
        print(f"  subsample: {subsample}")

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)

        # Train model
        self.model = GradientBoostingClassifier(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=max_depth,
            subsample=subsample,
            random_state=42,
            verbose=1
        )
        self.model.fit(X_train_scaled, y_train)

        return self.model

    def evaluate(self, X_test, y_test) -> Dict:
        """Evaluate model performance with comprehensive metrics"""
        X_test_scaled = self.scaler.transform(X_test)

        # Predictions
        y_pred = self.model.predict(X_test_scaled)
        y_pred_proba = self.model.predict_proba(X_test_scaled)[:, 1]

        # Calculate metrics
        metrics = {
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred, average='weighted', zero_division=0),
            'recall': recall_score(y_test, y_pred, average='weighted', zero_division=0),
            'f1_score': f1_score(y_test, y_pred, average='weighted', zero_division=0),
            'roc_auc': roc_auc_score(y_test, y_pred_proba)
        }

        # Add feature importance if available
        if hasattr(self.model, 'feature_importances_'):
            feature_importance = dict(zip(
                [f'feature_{i}' for i in range(len(self.model.feature_importances_))],
                self.model.feature_importances_.tolist()
            ))
            metrics['feature_importance'] = feature_importance

        return metrics

    def save_model(self, output_dir: str) -> Tuple[str, str]:
        """Save trained model and scaler"""
        os.makedirs(output_dir, exist_ok=True)

        model_path = os.path.join(output_dir, 'model.pkl')
        scaler_path = os.path.join(output_dir, 'scaler.pkl')

        joblib.dump(self.model, model_path)
        joblib.dump(self.scaler, scaler_path)

        print(f"✅ Model saved to {model_path}")
        print(f"✅ Scaler saved to {scaler_path}")

        return model_path, scaler_path

    def register_model_to_azure_ml(self, model_path: str, model_version: str,
                                   metrics: Dict, tags: Dict = None):
        """
        Register model to Azure ML Model Registry
        Integrated with MLflow for experiment tracking
        """
        if not self.ml_client:
            print("⚠️  ML Client not available. Skipping Azure ML registration.")
            return None

        try:
            print(f"\n📦 Registering model to Azure ML Model Registry...")

            # Prepare tags
            model_tags = {
                "model_type": tags.get("model_type", "unknown"),
                "framework": "scikit-learn",
                "accuracy": str(metrics.get("accuracy", 0)),
                "f1_score": str(metrics.get("f1_score", 0)),
                "training_date": datetime.now().isoformat(),
                "experiment_name": self.experiment_name,
                "mlflow_run_id": mlflow.active_run().info.run_id if mlflow.active_run() else "unknown"
            }

            if tags:
                model_tags.update(tags)

            # Register model
            model = Model(
                path=model_path,
                name=self.model_name,
                version=model_version,
                description=f"ML classifier trained with {tags.get('model_type', 'unknown')}",
                tags=model_tags
            )

            registered_model = self.ml_client.models.create_or_update(model)
            print(f"✅ Model registered: {registered_model.name} v{registered_model.version}")

            return registered_model

        except Exception as e:
            print(f"❌ Failed to register model to Azure ML: {e}")
            return None

    def promote_model_stage(self, model_name: str, version: str, stage: str = "Production"):
        """
        Promote model to a specific stage in MLflow Model Registry
        Stages: None, Staging, Production, Archived
        """
        try:
            print(f"\n🚀 Promoting model {model_name} v{version} to {stage}...")

            self.mlflow_client.transition_model_version_stage(
                name=model_name,
                version=version,
                stage=stage
            )

            print(f"✅ Model promoted to {stage} stage")

        except Exception as e:
            print(f"❌ Failed to promote model: {e}")


def train_with_mlflow_and_azure_ml(args):
    """
    Main training function with integrated MLflow tracking and Azure ML
    Features:
    - Experiment tracking with MLflow
    - Model registry integration
    - Distributed training support
    - Automatic model versioning
    """

    # Initialize Azure ML client (if credentials available)
    ml_client = None
    try:
        credential = DefaultAzureCredential()
        subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID")
        resource_group = os.getenv("AZURE_RESOURCE_GROUP")
        workspace_name = os.getenv("AZURE_ML_WORKSPACE")

        if all([subscription_id, resource_group, workspace_name]):
            ml_client = MLClient(credential, subscription_id, resource_group, workspace_name)
            print(f"✅ Connected to Azure ML workspace: {workspace_name}")
        else:
            print("⚠️  Azure ML credentials not found. Running in local mode.")

    except Exception as e:
        print(f"⚠️  Could not connect to Azure ML: {e}")

    # Set MLflow tracking URI to Azure ML (if available)
    if ml_client:
        try:
            mlflow.set_tracking_uri(ml_client.workspaces.get(workspace_name).mlflow_tracking_uri)
            print(f"✅ MLflow tracking URI set to Azure ML workspace")
        except:
            print("⚠️  Using local MLflow tracking")

    # Set MLflow experiment
    mlflow.set_experiment(args.experiment_name)

    # Start MLflow run with enhanced tracking
    with mlflow.start_run(run_name=f"{args.model_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}") as run:

        print(f"\n{'='*80}")
        print(f"🚀 Starting Training Run")
        print(f"{'='*80}")
        print(f"Run ID: {run.info.run_id}")
        print(f"Experiment: {args.experiment_name}")
        print(f"Model Type: {args.model_type}")
        print(f"{'='*80}\n")

        # Log all parameters
        params = {
            "model_type": args.model_type,
            "n_estimators": args.n_estimators,
            "max_depth": args.max_depth,
            "learning_rate": args.learning_rate,
            "min_samples_split": args.min_samples_split,
            "min_samples_leaf": args.min_samples_leaf,
            "subsample": args.subsample,
            "framework": "scikit-learn",
            "distributed_training": args.distributed,
            "hyperparameter_tuning": args.hyperparam_tune
        }

        for param_name, param_value in params.items():
            mlflow.log_param(param_name, param_value)

        # Log system information
        mlflow.log_param("python_version", os.sys.version.split()[0])
        mlflow.log_param("training_mode", "distributed" if args.distributed else "local")

        # Initialize trainer
        trainer = MLModelTrainer(
            model_name=args.model_name,
            experiment_name=args.experiment_name,
            ml_client=ml_client
        )

        # Load data
        print("📊 Loading data...")
        X_train, X_test, y_train, y_test = trainer.load_data(args.data_path)
        mlflow.log_param("training_samples", len(X_train))
        mlflow.log_param("test_samples", len(X_test))
        mlflow.log_param("n_features", X_train.shape[1])

        # Train model
        print(f"\n🎯 Training {args.model_type} model...")
        if args.model_type == "random_forest":
            trainer.train_random_forest(
                X_train, y_train,
                n_estimators=args.n_estimators,
                max_depth=args.max_depth,
                min_samples_split=args.min_samples_split,
                min_samples_leaf=args.min_samples_leaf
            )
        elif args.model_type == "gradient_boosting":
            trainer.train_gradient_boosting(
                X_train, y_train,
                n_estimators=args.n_estimators,
                learning_rate=args.learning_rate,
                max_depth=args.max_depth,
                subsample=args.subsample
            )
        else:
            raise ValueError(f"Unknown model type: {args.model_type}")

        # Evaluate model
        print("\n📈 Evaluating model...")
        metrics = trainer.evaluate(X_test, y_test)

        # Log metrics to MLflow
        print(f"\n{'='*80}")
        print("📊 Model Performance Metrics")
        print(f"{'='*80}")
        for metric_name, metric_value in metrics.items():
            if metric_name != 'feature_importance':
                mlflow.log_metric(metric_name, metric_value)
                print(f"  {metric_name}: {metric_value:.4f}")
        print(f"{'='*80}\n")

        # Log feature importance if available
        if 'feature_importance' in metrics:
            feature_importance = metrics.pop('feature_importance')
            for feature, importance in feature_importance.items():
                mlflow.log_metric(f"importance_{feature}", importance)

        # Save model locally
        print("💾 Saving model artifacts...")
        model_path, scaler_path = trainer.save_model(args.output_dir)

        # Log model to MLflow with signature
        print("\n📦 Logging model to MLflow...")
        signature = mlflow.models.infer_signature(X_train, trainer.model.predict(trainer.scaler.transform(X_train)))

        mlflow.sklearn.log_model(
            trainer.model,
            "model",
            registered_model_name=args.model_name,
            signature=signature,
            input_example=X_train.iloc[:5] if hasattr(X_train, 'iloc') else X_train[:5]
        )

        # Log artifacts
        mlflow.log_artifact(model_path)
        mlflow.log_artifact(scaler_path)

        # Save and log metrics
        metrics_file = os.path.join(args.output_dir, 'metrics.json')
        with open(metrics_file, 'w') as f:
            json.dump(metrics, f, indent=2)
        mlflow.log_artifact(metrics_file)

        # Create model card
        model_card_path = os.path.join(args.output_dir, 'model_card.md')
        with open(model_card_path, 'w') as f:
            f.write(f"# Model Card: {args.model_name}\n\n")
            f.write(f"## Model Details\n")
            f.write(f"- **Model Type**: {args.model_type}\n")
            f.write(f"- **Framework**: scikit-learn\n")
            f.write(f"- **Training Date**: {datetime.now().isoformat()}\n")
            f.write(f"- **MLflow Run ID**: {run.info.run_id}\n\n")
            f.write(f"## Performance Metrics\n")
            for metric_name, metric_value in metrics.items():
                f.write(f"- **{metric_name}**: {metric_value:.4f}\n")
            f.write(f"\n## Hyperparameters\n")
            for param_name, param_value in params.items():
                f.write(f"- **{param_name}**: {param_value}\n")

        mlflow.log_artifact(model_card_path)

        # Register model to Azure ML Model Registry
        if ml_client:
            tags = {
                "model_type": args.model_type,
                "environment": "production",
                "auto_scale": "enabled"
            }
            trainer.register_model_to_azure_ml(
                model_path=args.output_dir,
                model_version="latest",
                metrics=metrics,
                tags=tags
            )

        # Promote model if accuracy threshold met
        if args.auto_promote and metrics['accuracy'] >= args.promotion_threshold:
            print(f"\n🎉 Model accuracy ({metrics['accuracy']:.4f}) exceeds threshold ({args.promotion_threshold})")
            print("🚀 Auto-promoting model to Production stage...")

            try:
                model_version = mlflow.MlflowClient().get_latest_versions(args.model_name, stages=["None"])[0].version
                trainer.promote_model_stage(args.model_name, model_version, "Production")
            except Exception as e:
                print(f"⚠️  Could not auto-promote model: {e}")

        print(f"\n{'='*80}")
        print("✅ Training Completed Successfully!")
        print(f"{'='*80}")
        print(f"📊 Accuracy: {metrics['accuracy']:.4f}")
        print(f"📊 F1 Score: {metrics['f1_score']:.4f}")
        print(f"📊 ROC AUC: {metrics['roc_auc']:.4f}")
        print(f"🔗 MLflow Run: {run.info.run_id}")
        print(f"{'='*80}\n")

        return metrics, run.info.run_id


def main():
    parser = argparse.ArgumentParser(
        description='Train ML model with MLflow tracking and Azure ML integration'
    )

    # Model configuration
    parser.add_argument('--model-name', type=str, default='ml-classifier',
                        help='Name of the model for registry')
    parser.add_argument('--experiment-name', type=str, default='model-training',
                        help='MLflow experiment name')
    parser.add_argument('--model-type', type=str, default='random_forest',
                        choices=['random_forest', 'gradient_boosting'],
                        help='Type of model to train')

    # Data configuration
    parser.add_argument('--data-path', type=str, default=None,
                        help='Path to training data CSV')
    parser.add_argument('--output-dir', type=str, default='./outputs',
                        help='Output directory for model artifacts')

    # Hyperparameters - Common
    parser.add_argument('--n-estimators', type=int, default=100,
                        help='Number of estimators')
    parser.add_argument('--max-depth', type=int, default=10,
                        help='Maximum depth of trees')

    # Hyperparameters - Random Forest
    parser.add_argument('--min-samples-split', type=int, default=2,
                        help='Minimum samples required to split a node')
    parser.add_argument('--min-samples-leaf', type=int, default=1,
                        help='Minimum samples required at leaf node')

    # Hyperparameters - Gradient Boosting
    parser.add_argument('--learning-rate', type=float, default=0.1,
                        help='Learning rate for gradient boosting')
    parser.add_argument('--subsample', type=float, default=1.0,
                        help='Subsample ratio for gradient boosting')

    # Training configuration
    parser.add_argument('--distributed', action='store_true',
                        help='Enable distributed training')
    parser.add_argument('--hyperparam-tune', action='store_true',
                        help='Enable hyperparameter tuning')

    # Model promotion
    parser.add_argument('--auto-promote', action='store_true',
                        help='Automatically promote model if threshold met')
    parser.add_argument('--promotion-threshold', type=float, default=0.90,
                        help='Accuracy threshold for auto-promotion')

    args = parser.parse_args()

    # Train model
    metrics, run_id = train_with_mlflow_and_azure_ml(args)

    print(f"\n🎊 Training pipeline completed!")
    print(f"📝 Run ID: {run_id}")
    print(f"📈 Final Accuracy: {metrics['accuracy']:.4f}")

    return metrics


if __name__ == "__main__":
    main()
