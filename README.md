# CatCloud Serverless App

CatCloud is an AWS serverless application built for a DevOps Student home assignment.

It deploys a Python Lambda function that lists objects in an S3 bucket and sends execution details through SNS email notifications.

The main deployment method is **GitHub Actions with OIDC**.

---

## Quick Start

1. Create the GitHub OIDC role:

```bash
chmod +x create_github_oidc.sh
./create_github_oidc.sh
```

2. Add the printed role ARN to GitHub repository secrets:

```text
AWS_ROLE_TO_ASSUME = arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

3. Add the AWS region to GitHub repository variables:

```text
AWS_REGION = us-east-1
```

4. Run the GitHub Actions workflow:

```text
Actions -> Deploy CatCloud -> Run workflow
```

5. Confirm the SNS email subscription.

6. Run the manual Lambda test:

```bash
chmod +x manual_lambda_test.sh
./manual_lambda_test.sh
```

---

## Architecture

```text
GitHub Actions
  -> OIDC authentication
  -> AWS CDK deployment
  -> S3 bucket + Lambda + SNS
  -> Upload sample_files/ to S3
  -> Invoke Lambda
  -> Lambda lists S3 objects
  -> SNS sends email notification
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

## What Gets Deployed

The CDK stack creates:

- Private S3 bucket
- SNS topic
- SNS email subscription
- Python Lambda function
- Lambda execution IAM role
- Least-privilege permissions for:
  - S3 read/list
  - SNS publish
  - CloudWatch Logs

During deployment, files from `sample_files/` are uploaded to:

```text
s3://<created-bucket>/cat-images/
```

---

## GitHub Actions Deployment

The main workflow is:

```text
.github/workflows/deploy.yml
```

It is triggered manually with `workflow_dispatch`.

The workflow:

1. Authenticates to AWS using GitHub OIDC
2. Installs dependencies
3. Runs unit tests
4. Runs `cdk synth`
5. Deploys the CDK stack
6. Uploads `sample_files/` to S3
7. Lists the uploaded files
8. Invokes the Lambda for verification

A successful run should show:

```text
StatusCode: 200
```

---

## GitHub OIDC Setup

This project does not store AWS access keys in GitHub.

Run:

```bash
./create_github_oidc.sh
```

The script creates or updates:

- GitHub OIDC provider in AWS
- IAM role for GitHub Actions
- Trust policy restricted to the selected repository and branch
- Deployment permissions required by CDK

At the end, copy the printed role ARN.

Then configure GitHub:

```text
Repository -> Settings -> Secrets and variables -> Actions
```

Add Repository Secret:

```text
Name:  AWS_ROLE_TO_ASSUME
Value: arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Add Repository Variable:

```text
Name:  AWS_REGION
Value: us-east-1
```

---

## SNS Email Confirmation

SNS email subscriptions require manual confirmation.

After the first deployment, AWS sends a confirmation email to the provided address.

Click **Confirm subscription** before expecting notification emails.

The Lambda may run successfully before confirmation, but SNS email delivery starts only after confirmation.

---

## Manual Lambda Test

Run from the project root:

```bash
./manual_lambda_test.sh
```

Optional explicit usage:

```bash
./manual_lambda_test.sh CatCloudStack us-east-1
```

The script reads the Lambda name from CloudFormation outputs, invokes it with:

```text
test-events/manual-test-event.json
```

and prints the response.

Expected result:

```text
StatusCode: 200
```

---

## Optional Local Deployment

The main deployment path is GitHub Actions.

For local testing only:

```bash
chmod +x optional/deploy_local.sh
./optional/deploy_local.sh
```

This deploys the same CDK stack from a local machine using local AWS CLI credentials.

It is not the primary CI/CD deployment method.

---

## Cleanup

Destroy the stack:

```bash
cd infra_aws_cdk
cdk destroy CatCloudStack -c notification_email=your-email@example.com --force
```

The `notification_email` context is required because the CDK app validates it during synthesis.

---

## Security Notes

- GitHub Actions uses OIDC instead of long-lived AWS keys.
- The OIDC role is restricted to the selected GitHub repository and branch.
- The Lambda role uses least-privilege permissions.
- The S3 bucket is private.
- S3 public access is blocked.
- No AWS credentials are committed to the repository.

---

## Requirement Mapping

| Requirement | Implementation |
|---|---|
| IaC | AWS CDK |
| GitHub Actions CI/CD | `.github/workflows/deploy.yml` |
| Lambda lists S3 objects | `lambda/s3_list_and_notify.py` |
| SNS email notification | Lambda publishes to SNS |
| S3 bucket | Created by CDK |
| Upload local files | GitHub Actions uploads `sample_files/` |
| Least-privilege IAM | CDK Lambda role |
| Manual Lambda trigger | `manual_lambda_test.sh` |
| Test event | `test-events/manual-test-event.json` |