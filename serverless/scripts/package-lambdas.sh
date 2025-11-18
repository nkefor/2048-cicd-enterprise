#!/bin/bash

set -e

echo "📦 Packaging Lambda functions..."

# Directory containing Lambda functions
LAMBDA_DIR="$(dirname "$0")/../lambda"
cd "$LAMBDA_DIR"

# Function to package a Lambda function
package_lambda() {
    local func_path=$1
    local func_name=$(basename "$func_path")

    echo "Packaging $func_name..."

    cd "$func_path"

    # Create deployment package
    if [ -f "index.py" ]; then
        # Create a temporary directory for packaging
        rm -rf package
        mkdir -p package

        # Copy function code
        cp index.py package/

        # Install dependencies if requirements.txt exists
        if [ -f "requirements.txt" ]; then
            pip install -r requirements.txt -t package/ --quiet
        elif [ -f "../../../requirements.txt" ]; then
            pip install -r ../../../requirements.txt -t package/ --quiet
        fi

        # Create zip file
        cd package
        zip -r ../deployment.zip . -q
        cd ..

        # Clean up
        rm -rf package

        echo "✅ $func_name packaged successfully"
    fi

    cd - > /dev/null
}

# Package API Lambda functions
echo "📦 Packaging API Lambda functions..."
for func in api/*/; do
    package_lambda "$func"
done

# Package Event Lambda functions
echo "📦 Packaging Event Lambda functions..."
for func in events/*/; do
    package_lambda "$func"
done

echo "✅ All Lambda functions packaged successfully!"
