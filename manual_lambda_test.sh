#!/bin/bash
set -e

STACK_NAME="${1:-CatCloudStack}"
REGION="${2:-us-east-1}"

echo "Using stack: $STACK_NAME"
echo "Using region: $REGION"

FUNCTION_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CatCloudLambdaFunctionName'].OutputValue" \
  --output text)

if [ -z "$FUNCTION_NAME" ] || [ "$FUNCTION_NAME" = "None" ]; then
  echo "Error: Could not find CatCloudLambdaFunctionName output in stack: $STACK_NAME"
  exit 1
fi

echo "Invoking Lambda function: $FUNCTION_NAME"

aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/manual-test-event.json \
  response.json \
  --region "$REGION"

echo
echo "Lambda response:"
cat response.json
echo