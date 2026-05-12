# CatCloud Serverless App

CatCloud is an AWS serverless application built for a DevOps Student home assignment.

It uses AWS CDK and GitHub Actions to deploy a Lambda workflow that lists objects in an S3 bucket and sends execution details through SNS email notifications.

The main deployment path is GitHub Actions with OIDC.

---

## Overview

Flow:

```text
sample_files/
  -> uploaded to S3 during deployment
  -> Lambda is invoked
  -> Lambda lists S3 objects
  -> Lambda publishes details to SNS
  -> SNS sends an email notification
```

---

## Tech Stack

- AWS CDK v2
- Python 3.12
- AWS Lambda
- Amazon S3
- Amazon SNS
- AWS IAM
- GitHub Actions
- GitHub OIDC
- AWS CLI
- Pytest

---

## Repository Structure

```text
CatCloud-ServerLess-App/
├── .github/workflows/deploy.yml
├── infra_aws_cdk/
├── lambda/s3_list_and_notify.py
├── sample_files/
├── test-events/manual-test-event.json
├── optional/deploy_local.sh
├── create_github_oidc.sh
├── manual_lambda_test.sh
└── README.md
```

---

## AWS Resources

The CDK stack creates:

- Private S3 bucket
- SNS topic
- SNS email subscription
- Python Lambda function
- Lambda execution IAM role
- Least-privilege permissions for S3 read/list, SNS publish, and CloudWatch Logs

During deployment, files from `sample_files/` are uploaded to:

```text
s3://<created-bucket>/cat-images/
```

---

## Main Deployment: GitHub Actions

The main deployment method is:

```text
.github/workflows/deploy.yml
```

The workflow is manually triggered with `workflow_dispatch`.

It performs:

1. Checkout repository
2. Authenticate to AWS using GitHub OIDC
3. Install Python, Node.js, CDK, and Python dependencies
4. Run unit tests
5. Run `cdk synth`
6. Deploy the CDK stack
7. Upload `sample_files/` to S3
8. List uploaded files
9. Invoke the Lambda for verification

---

## One-Time OIDC Setup

This project uses GitHub OIDC instead of storing AWS access keys in GitHub.

Before running the workflow in a new AWS account, run:

```bash
chmod +x create_github_oidc.sh
./create_github_oidc.sh
```

The script creates or updates:

- GitHub OIDC provider in AWS
- IAM role for GitHub Actions
- Trust policy restricted to the selected repository and branch
- Permissions required for CDK deployment

At the end, the script prints a role ARN:

```text
arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Copy this ARN for the next step.

---

## GitHub Secret and Variable

In the GitHub repository, go to:

```text
Settings -> Secrets and variables -> Actions
```

Add this Repository Secret:

```text
Name:  AWS_ROLE_TO_ASSUME
Value: arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Add this Repository Variable:

```text
Name:  AWS_REGION
Value: us-east-1
```

`AWS_ROLE_TO_ASSUME` is stored as a secret.  
`AWS_REGION` is stored as a variable because it is not sensitive.

---

## Run the Workflow

In GitHub:

```text
Actions -> Deploy CatCloud -> Run workflow
```

Use:

```text
notification_email: your-email@example.com
invoke_lambda_after_deploy: true
```

A successful run should show:

```text
StatusCode: 200
```

The Lambda response should include the uploaded S3 objects.

---

## SNS Email Confirmation

AWS SNS email subscriptions require manual confirmation.

After the first deployment, AWS sends a confirmation email to the provided address.

Click **Confirm subscription** before expecting notification emails.

Important:

- The Lambda can run successfully before confirmation.
- SNS publish can succeed before confirmation.
- Email delivery starts only after the subscription is confirmed.
- Check Spam or Promotions if the confirmation email is missing.

After confirmation, run the manual Lambda test or re-run the workflow.

---

## Manual Lambda Test

The assignment requires a manual Lambda trigger.

Run from the project root:

```bash
chmod +x manual_lambda_test.sh
./manual_lambda_test.sh
```

Optional explicit usage:

```bash
./manual_lambda_test.sh CatCloudStack us-east-1
```

The script reads the Lambda name from CloudFormation outputs, invokes it with `test-events/manual-test-event.json`, and prints the response.

Expected result:

```text
StatusCode: 200
```

---

## Optional Local Deployment

The main deployment path is GitHub Actions.

For local testing only, a convenience script is provided:

```bash
chmod +x optional/deploy_local.sh
./optional/deploy_local.sh
```

This script deploys the same CDK stack from a local machine using local AWS CLI credentials.

It is not the primary CI/CD deployment method.

After local deployment, confirm the SNS email subscription and run:

```bash
./manual_lambda_test.sh
```

---

## Cleanup

Destroy the stack:

```bash
cd infra_aws_cdk
cdk destroy CatCloudStack -c notification_email=your-email@example.com --force
```

The `notification_email` context is required because the CDK app validates it during synthesis, including during destroy.

---

## Security Notes

- GitHub Actions uses OIDC, not long-lived AWS keys.
- The OIDC trust policy is restricted to the selected repository and branch.
- The Lambda role uses least-privilege permissions.
- The S3 bucket is private.
- S3 public access is blocked.
- No AWS credentials are committed to the repository.

---

## Requirement Mapping

| Requirement | Implementation |
|---|---|
| IaC | AWS CDK |
| Lambda lists S3 objects | `lambda/s3_list_and_notify.py` |
| SNS email notification | Lambda publishes to SNS |
| S3 bucket | Created by CDK |
| Upload local files | GitHub Actions uploads `sample_files/` |
| Least-privilege IAM | CDK Lambda role |
| GitHub Actions CI/CD | `.github/workflows/deploy.yml` |
| Manual Lambda trigger | `manual_lambda_test.sh` |
| Test event | `test-events/manual-test-event.json` |

---

## Recommended Review Flow

1. Run the GitHub Actions workflow.
2. Confirm the SNS email subscription.
3. Run `manual_lambda_test.sh`.
4. Verify `StatusCode: 200`.
5. Verify the SNS email notification was received.