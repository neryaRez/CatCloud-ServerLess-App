#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "======================================"
echo "🐱 CatCloud Manual Deployment"
echo "======================================"
echo

export AWS_PAGER=""

AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"
echo "AWS Region: $AWS_REGION"
echo

read -p "Enter your notification email: " EMAIL

if [ -z "$EMAIL" ]; then
  echo "Error: email is required."
  exit 1
fi

echo
echo "Using email: $EMAIL"
echo

echo "Checking AWS identity..."
aws sts get-caller-identity

echo
echo "Installing AWS CDK if missing..."
if ! command -v cdk >/dev/null 2>&1; then
  npm install -g aws-cdk
else
  echo "AWS CDK already installed."
fi

echo
echo "Moving into CDK project..."
cd "$PROJECT_ROOT/infra_aws_cdk"

echo
echo "Creating Python virtual environment if missing..."
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

echo
echo "Activating virtual environment..."
source .venv/bin/activate

echo
echo "Installing Python dependencies..."
pip install -r requirements.txt

if [ -f "requirements-dev.txt" ]; then
  pip install -r requirements-dev.txt
fi

echo
echo "Running tests..."
pytest

echo
echo "Running CDK synth..."
cdk synth -c notification_email="$EMAIL"

echo
echo "Deploying CatCloudStack..."
cdk deploy CatCloudStack \
  -c notification_email="$EMAIL" \
  --require-approval never

echo
echo "Getting S3 bucket name from CloudFormation outputs..."

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name CatCloudStack \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CatCloudBucketName'].OutputValue" \
  --output text)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
  echo "Error: Could not find CatCloudBucketName output."
  exit 1
fi

echo "Bucket name: $BUCKET_NAME"

echo
echo "Waiting for S3 bucket to be ready..."

for i in {1..12}; do
  if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "Bucket is ready ✅"
    break
  fi

  echo "Bucket is not ready yet. Waiting 5 seconds..."
  sleep 5

  if [ "$i" -eq 12 ]; then
    echo "Error: Bucket was not ready after waiting."
    exit 1
  fi
done

echo
echo "Uploading local sample files to S3 using AWS CLI..."

aws s3 sync "$PROJECT_ROOT/sample_files/" "s3://$BUCKET_NAME/cat-images/" \
  --region "$AWS_REGION" \
  --delete

echo
echo "Uploaded files:"
aws s3 ls "s3://$BUCKET_NAME/cat-images/" --region "$AWS_REGION"
cd "$PROJECT_ROOT"

echo
echo "======================================"
echo "Deployment finished successfully ✅"
echo "======================================"
echo
echo "Important:"
echo "Check your email and confirm the SNS subscription."
echo "If you do not see it, check Spam / Promotions."
echo
echo "After confirming the SNS email subscription, run:"
echo "./manual_lambda_test.sh"