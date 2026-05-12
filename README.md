# CatCloud Serverless App

CatCloud is a small serverless platform for uploading sample cat images to a private S3 bucket, scanning the bucket with Lambda, and sending an email summary through SNS.

The project was built for a DevOps Student home assignment and focuses on secure, automated AWS deployment.

---

CatCloud demonstrates a complete serverless DevOps workflow: infrastructure is defined with AWS CDK, deployed through GitHub Actions, and verified after deployment by invoking the Lambda function.

The deployment uses GitHub OIDC, so no long-lived AWS access keys are stored in GitHub. The stack creates a private S3 bucket, uploads sample cat images during deployment, deploys a Python Lambda function with least-privilege IAM permissions, and sends execution summaries through SNS email notifications.

---

## Quick Start

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

---

## What Gets Deployed

The CDK stack creates:

- Private S3 bucket
- SNS topic
- SNS email subscription
- Python Lambda function
- Lambda execution IAM role
- S3 read/list, SNS publish, and CloudWatch Logs permissions

During deployment, files from `sample_files/` are uploaded to:

```text
s3://<created-bucket>/cat-images/
```

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

- GitHub Actions uses OIDC instead of stored AWS keys.
- The OIDC role is restricted to the selected repository and branch.
- The Lambda role uses least-privilege permissions.
- The S3 bucket is private.
- S3 public access is blocked.
- No AWS credentials are committed to the repository.

---

## Requirement Mapping

| Requirement | Implementation |
|---|---|
| Infrastructure as Code | AWS CDK |
| CI/CD | GitHub Actions with `workflow_dispatch` |
| Secure AWS authentication | GitHub OIDC |
| S3 bucket | Created by CDK |
| Upload local files | GitHub Actions uploads `sample_files/` |
| Lambda lists S3 objects | `lambda/s3_list_and_notify.py` |
| SNS email notification | Lambda publishes to SNS |
| Least-privilege IAM | CDK-defined Lambda role |
| Manual Lambda trigger | `manual_lambda_test.sh` |
| Test event | `test-events/manual-test-event.json` |