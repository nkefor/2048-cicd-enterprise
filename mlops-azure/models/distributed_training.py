"""
Distributed Training and Hyperparameter Tuning with Azure ML
- Leverages Azure ML compute clusters for scalable training
- Integrated hyperparameter tuning with HyperDrive
- MLflow tracking across distributed runs
"""

import os
import argparse
from azure.ai.ml import MLClient, command, Input
from azure.ai.ml.entities import AmlCompute, Environment
from azure.ai.ml.sweep import Choice, Uniform, RandomSamplingAlgorithm, BanditPolicy
from azure.identity import DefaultAzureCredential
from azure.ai.ml import dsl


class DistributedMLOpsTrainer:
    """
    Manages distributed training and hyperparameter tuning on Azure ML
    """

    def __init__(self, subscription_id: str, resource_group: str, workspace_name: str):
        """Initialize Azure ML client"""
        self.credential = DefaultAzureCredential()
        self.ml_client = MLClient(
            self.credential,
            subscription_id,
            resource_group,
            workspace_name
        )
        print(f"✅ Connected to Azure ML workspace: {workspace_name}")

    def create_compute_cluster(
        self,
        compute_name: str = "ml-compute-cluster",
        vm_size: str = "STANDARD_DS3_V2",
        min_instances: int = 0,
        max_instances: int = 4
    ):
        """
        Create or update Azure ML compute cluster for distributed training
        """
        try:
            # Check if compute already exists
            compute = self.ml_client.compute.get(compute_name)
            print(f"✅ Compute cluster '{compute_name}' already exists")
            return compute

        except Exception:
            print(f"Creating compute cluster '{compute_name}'...")

            compute = AmlCompute(
                name=compute_name,
                type="amlcompute",
                size=vm_size,
                min_instances=min_instances,
                max_instances=max_instances,
                idle_time_before_scale_down=300,  # 5 minutes
                tier="Dedicated"
            )

            compute = self.ml_client.compute.begin_create_or_update(compute).result()
            print(f"✅ Compute cluster '{compute_name}' created successfully")
            return compute

    def create_environment(self, environment_name: str = "mlops-training-env"):
        """
        Create Azure ML environment with required dependencies
        """
        try:
            env = self.ml_client.environments.get(environment_name, label="latest")
            print(f"✅ Environment '{environment_name}' already exists")
            return env

        except Exception:
            print(f"Creating environment '{environment_name}'...")

            environment = Environment(
                name=environment_name,
                description="MLOps training environment with scikit-learn and MLflow",
                conda_file="./conda_env.yaml",
                image="mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu20.04:latest"
            )

            env = self.ml_client.environments.create_or_update(environment)
            print(f"✅ Environment '{environment_name}' created successfully")
            return env

    def run_hyperparameter_tuning(
        self,
        experiment_name: str,
        compute_name: str,
        model_type: str = "random_forest",
        max_total_trials: int = 20,
        max_concurrent_trials: int = 4
    ):
        """
        Run hyperparameter tuning using Azure ML HyperDrive
        Automatically tunes model hyperparameters for optimal performance
        """
        print(f"\n{'='*80}")
        print(f"🔬 Starting Hyperparameter Tuning")
        print(f"{'='*80}")
        print(f"Model Type: {model_type}")
        print(f"Max Trials: {max_total_trials}")
        print(f"Concurrent Trials: {max_concurrent_trials}")
        print(f"{'='*80}\n")

        # Define the training command
        job = command(
            code="./",
            command="python train_model.py \
                    --model-name ${{inputs.model_name}} \
                    --experiment-name ${{inputs.experiment_name}} \
                    --model-type ${{inputs.model_type}} \
                    --n-estimators ${{inputs.n_estimators}} \
                    --max-depth ${{inputs.max_depth}} \
                    --learning-rate ${{inputs.learning_rate}} \
                    --min-samples-split ${{inputs.min_samples_split}} \
                    --min-samples-leaf ${{inputs.min_samples_leaf}}",
            environment=f"mlops-training-env@latest",
            compute=compute_name,
            experiment_name=experiment_name,
            inputs={
                "model_name": f"{model_type}-tuned",
                "experiment_name": experiment_name,
                "model_type": model_type,
                "n_estimators": 100,
                "max_depth": 10,
                "learning_rate": 0.1,
                "min_samples_split": 2,
                "min_samples_leaf": 1,
            }
        )

        # Define hyperparameter search space
        if model_type == "random_forest":
            job.sweep = {
                "sampling_algorithm": RandomSamplingAlgorithm(),
                "primary_metric": "accuracy",
                "goal": "maximize",
            }
            job.inputs.n_estimators = Choice([50, 100, 150, 200])
            job.inputs.max_depth = Choice([5, 10, 15, 20, None])
            job.inputs.min_samples_split = Choice([2, 5, 10])
            job.inputs.min_samples_leaf = Choice([1, 2, 4])

        elif model_type == "gradient_boosting":
            job.sweep = {
                "sampling_algorithm": RandomSamplingAlgorithm(),
                "primary_metric": "accuracy",
                "goal": "maximize",
            }
            job.inputs.n_estimators = Choice([50, 100, 150, 200])
            job.inputs.max_depth = Choice([3, 5, 7, 10])
            job.inputs.learning_rate = Uniform(0.01, 0.3)

        # Configure sweep limits
        job.sweep.max_total_trials = max_total_trials
        job.sweep.max_concurrent_trials = max_concurrent_trials
        job.sweep.timeout_minutes = 60

        # Configure early termination policy
        job.sweep.early_termination = BanditPolicy(
            slack_factor=0.1,
            evaluation_interval=2,
            delay_evaluation=5
        )

        # Submit the hyperparameter tuning job
        print("🚀 Submitting hyperparameter tuning job...")
        returned_job = self.ml_client.jobs.create_or_update(job)

        print(f"\n✅ Hyperparameter tuning job submitted!")
        print(f"Job Name: {returned_job.name}")
        print(f"Job URL: {returned_job.studio_url}")
        print(f"\n💡 Monitor progress in Azure ML Studio")

        return returned_job

    def run_distributed_training(
        self,
        experiment_name: str,
        compute_name: str,
        model_type: str = "random_forest",
        n_estimators: int = 100,
        max_depth: int = 10,
        learning_rate: float = 0.1,
        instance_count: int = 2
    ):
        """
        Run distributed training across multiple compute nodes
        Scales model training for large datasets
        """
        print(f"\n{'='*80}")
        print(f"🚀 Starting Distributed Training")
        print(f"{'='*80}")
        print(f"Model Type: {model_type}")
        print(f"Instances: {instance_count}")
        print(f"Compute: {compute_name}")
        print(f"{'='*80}\n")

        # Define the training command
        job = command(
            code="./",
            command="python train_model.py \
                    --model-name ${{inputs.model_name}} \
                    --experiment-name ${{inputs.experiment_name}} \
                    --model-type ${{inputs.model_type}} \
                    --n-estimators ${{inputs.n_estimators}} \
                    --max-depth ${{inputs.max_depth}} \
                    --learning-rate ${{inputs.learning_rate}} \
                    --distributed",
            environment=f"mlops-training-env@latest",
            compute=compute_name,
            instance_count=instance_count,
            distribution={
                "type": "PyTorch",
                "process_count_per_instance": 1
            },
            experiment_name=experiment_name,
            inputs={
                "model_name": f"{model_type}-distributed",
                "experiment_name": experiment_name,
                "model_type": model_type,
                "n_estimators": n_estimators,
                "max_depth": max_depth,
                "learning_rate": learning_rate,
            }
        )

        # Submit the distributed training job
        print("🚀 Submitting distributed training job...")
        returned_job = self.ml_client.jobs.create_or_update(job)

        print(f"\n✅ Distributed training job submitted!")
        print(f"Job Name: {returned_job.name}")
        print(f"Job URL: {returned_job.studio_url}")
        print(f"\n💡 Monitor progress in Azure ML Studio")

        return returned_job

    def get_best_model_from_hyperparam_run(self, job_name: str):
        """
        Retrieve the best model from hyperparameter tuning run
        """
        print(f"\n🔍 Retrieving best model from job: {job_name}")

        try:
            # Get the job
            job = self.ml_client.jobs.get(job_name)

            # Get best child run
            best_run = None
            best_metric = float('-inf')

            # List all child runs
            child_runs = self.ml_client.jobs.list(parent_job_name=job_name)

            for child_run in child_runs:
                if child_run.properties.get('accuracy', 0) > best_metric:
                    best_metric = child_run.properties.get('accuracy', 0)
                    best_run = child_run

            if best_run:
                print(f"\n✅ Best model found!")
                print(f"Run ID: {best_run.name}")
                print(f"Accuracy: {best_metric:.4f}")
                print(f"\nBest Hyperparameters:")
                for param, value in best_run.inputs.items():
                    print(f"  {param}: {value}")

                return best_run
            else:
                print("❌ No runs found")
                return None

        except Exception as e:
            print(f"❌ Error retrieving best model: {e}")
            return None


def main():
    parser = argparse.ArgumentParser(
        description='Distributed training and hyperparameter tuning with Azure ML'
    )

    # Azure ML configuration
    parser.add_argument('--subscription-id', type=str, required=True,
                        help='Azure subscription ID')
    parser.add_argument('--resource-group', type=str, required=True,
                        help='Azure resource group')
    parser.add_argument('--workspace-name', type=str, required=True,
                        help='Azure ML workspace name')

    # Training configuration
    parser.add_argument('--experiment-name', type=str, default='mlops-distributed-training',
                        help='Experiment name')
    parser.add_argument('--model-type', type=str, default='random_forest',
                        choices=['random_forest', 'gradient_boosting'],
                        help='Model type to train')

    # Compute configuration
    parser.add_argument('--compute-name', type=str, default='ml-compute-cluster',
                        help='Compute cluster name')
    parser.add_argument('--vm-size', type=str, default='STANDARD_DS3_V2',
                        help='VM size for compute cluster')
    parser.add_argument('--max-nodes', type=int, default=4,
                        help='Maximum number of nodes in compute cluster')

    # Training mode
    parser.add_argument('--mode', type=str, default='hyperparameter-tuning',
                        choices=['hyperparameter-tuning', 'distributed-training', 'both'],
                        help='Training mode')

    # Hyperparameter tuning configuration
    parser.add_argument('--max-trials', type=int, default=20,
                        help='Maximum number of trials for hyperparameter tuning')
    parser.add_argument('--concurrent-trials', type=int, default=4,
                        help='Maximum concurrent trials')

    # Distributed training configuration
    parser.add_argument('--instance-count', type=int, default=2,
                        help='Number of instances for distributed training')

    args = parser.parse_args()

    # Initialize trainer
    trainer = DistributedMLOpsTrainer(
        subscription_id=args.subscription_id,
        resource_group=args.resource_group,
        workspace_name=args.workspace_name
    )

    # Create compute cluster
    trainer.create_compute_cluster(
        compute_name=args.compute_name,
        vm_size=args.vm_size,
        max_instances=args.max_nodes
    )

    # Create environment
    trainer.create_environment()

    # Run training based on mode
    if args.mode in ['hyperparameter-tuning', 'both']:
        print("\n🔬 Running hyperparameter tuning...")
        tuning_job = trainer.run_hyperparameter_tuning(
            experiment_name=args.experiment_name,
            compute_name=args.compute_name,
            model_type=args.model_type,
            max_total_trials=args.max_trials,
            max_concurrent_trials=args.concurrent_trials
        )

    if args.mode in ['distributed-training', 'both']:
        print("\n🚀 Running distributed training...")
        distributed_job = trainer.run_distributed_training(
            experiment_name=args.experiment_name,
            compute_name=args.compute_name,
            model_type=args.model_type,
            instance_count=args.instance_count
        )

    print(f"\n{'='*80}")
    print("✅ Training jobs submitted successfully!")
    print(f"{'='*80}")
    print("\n💡 Next steps:")
    print("1. Monitor jobs in Azure ML Studio")
    print("2. Review MLflow experiments for detailed metrics")
    print("3. Deploy best model to production")


if __name__ == "__main__":
    main()
