# CatCloud Serverless App

CatCloud is a small serverless platform built for a DevOps Student home assignment.

It uploads sample cat images to a private S3 bucket during deployment, invokes a Python Lambda function to scan the bucket, and sends an execution summary through SNS email notifications.

The recommended deployment path is automated with AWS CDK and GitHub Actions. GitHub authenticates to AWS using OIDC, so no long-lived AWS access keys are stored in the repository.

---

## Deployment Options

The recommended and primary deployment method is [GitHub Actions with OIDC](#quick-start-github-actions-with-oidc).

This flow demonstrates the full CI/CD process for the assignment: GitHub Actions authenticates to AWS using OIDC, deploys the CDK stack, uploads sample files, and invokes the Lambda function for verification.

For quick manual validation, the project also includes an [Optional Local Deployment Without OIDC](#optional-local-deployment-without-oidc).

The local option deploys the same CDK stack from a local machine using existing AWS CLI credentials.

---

## Quick Start: GitHub Actions with OIDC

### 1. Create the GitHub OIDC role

Run once from the project root:

```bash
chmod +x create_github_oidc.sh
./create_github_oidc.sh
```

The script prints an IAM role ARN:

```text
arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Copy this ARN.

### 2. Configure GitHub

Go to:

```text
Repository -> Settings -> Secrets and variables -> Actions
```

Add this **Repository Secret**:

```text
AWS_ROLE_TO_ASSUME = arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Add this **Repository Variable**:

```text
AWS_REGION = us-east-1
```

### 3. Run the deployment

Go to:

```text
Actions -> Deploy CatCloud -> Run workflow
```

Use:

```text
notification_email: your-email@example.com
invoke_lambda_after_deploy: true
```

### 4. Confirm SNS email subscription

After the first deployment, AWS SNS sends a confirmation email.

The recipient must click **Confirm subscription** before notification emails can be delivered.

### 5. Run manual Lambda test

After confirming the SNS subscription:

```bash
chmod +x manual_lambda_test.sh
./manual_lambda_test.sh
```

Expected result:

```text
StatusCode: 200
```

---

## Optional Local Deployment Without OIDC

The main deployment path is **GitHub Actions with OIDC**.

This local option is provided only as a fallback for quick manual testing, or for reviewers who prefer to validate the CDK stack without configuring GitHub Actions and OIDC.

It deploys the same CDK stack from a local machine using the AWS credentials already configured in the local AWS CLI.

### Prerequisites

Before running the local deployment, verify that your AWS CLI is authenticated to the target AWS account:

```bash
aws sts get-caller-identity
```

Then run:

```bash
chmod +x optional/deploy_local.sh
./optional/deploy_local.sh
```

This is **not** the primary CI/CD deployment method. It is only a convenience path for local validation.

[Back to Deployment Options](#deployment-options)

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

## GitHub OIDC

This project does **not** store AWS access keys in GitHub.

`create_github_oidc.sh` creates or updates:

- GitHub OIDC provider in AWS
- IAM role for GitHub Actions
- Trust policy restricted to the selected repository and branch
- Permissions required for CDK deployment

The GitHub Actions workflow assumes this role using OIDC.

The setup script is safe to run even if the GitHub OIDC provider does not already exist in the AWS account. It checks for an existing GitHub OIDC provider and creates one if needed.

The first setup requires AWS permissions to manage IAM OIDC providers, IAM roles, and IAM policies.

---

## GitHub Actions Workflow

The main deployment file is:

```text
.github/workflows/deploy.yml
```

The workflow:

1. Authenticates to AWS using OIDC
2. Installs dependencies
3. Runs unit tests
4. Runs `cdk synth`
5. Deploys the CDK stack
6. Uploads `sample_files/` to S3
7. Lists uploaded files
8. Invokes Lambda for verification

This is the primary deployment path for the assignment.

---

## SNS Email Confirmation

SNS email subscriptions require manual confirmation.

The Lambda can run successfully before confirmation, but the email notification is delivered only after the recipient confirms the SNS subscription.

If the confirmation email is missing, check Spam or Promotions.

---

## Example Email Summary

The SNS email includes a short scan summary:

```text
CatCloud Scan Completed

Bucket name: <created-bucket>
Images found: 3

Uploaded cat images:
1. cat-images/cat1.jpg
2. cat-images/cat2.jpeg
3. cat-images/cat3.jpg
```

---

## Tech Stack

- **Infrastructure:** AWS CDK v2
- **Runtime:** Python 3.12, AWS Lambda
- **AWS services:** S3, SNS, IAM, CloudFormation
- **CI/CD:** GitHub Actions with OIDC
- **Testing:** Pytest, AWS CLI

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

- GitHub Actions uses OIDC instead of stored AWS keys.
- The OIDC role is restricted to the selected repository and branch.
- The Lambda role uses least-privilege permissions.
- The S3 bucket is private.
- S3 public access is blocked.
- No AWS credentials are committed to the repository.
- Local deployment uses credentials from the reviewer's local AWS CLI configuration and does not require committing or storing AWS keys in the repository.

---

## Author

Developed by **Nerya Reznikovich**.

Focused on software development, AWS cloud infrastructure, and automation workflows.

This project was built as part of a DevOps Student home assignment, with an emphasis on Infrastructure as Code, secure AWS deployment, least-privilege IAM, and automated delivery workflows.