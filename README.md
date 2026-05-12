# CatCloud Serverless App

CatCloud is a small serverless platform for uploading sample cat images to a private S3 bucket, scanning the bucket with Lambda, and sending an email summary through SNS.

The project was built for a DevOps Student home assignment and focuses on:

- Infrastructure as Code with AWS CDK
- GitHub Actions deployment with OIDC
- No long-lived AWS keys stored in GitHub
- Least-privilege IAM for the Lambda function
- Manual Lambda verification with AWS CLI

---

## Quick Start

### 1. Create the GitHub OIDC role

Run once from the project root:

```bash
chmod +x create_github_oidc.sh
./create_github_oidc.sh
```

The script prints an IAM role ARN similar to:

```text
arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Copy this ARN.

### 2. Add GitHub configuration

In the GitHub repository, go to:

```text
Settings -> Secrets and variables -> Actions
```

Add a repository secret:

```text
AWS_ROLE_TO_ASSUME = arn:aws:iam::<ACCOUNT_ID>:role/CatCloudGitHubActionsDeployRole
```

Add a repository variable:

```text
AWS_REGION = us-east-1
```

### 3. Run the deployment workflow

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

Click **Confirm subscription** before expecting notification emails.

### 5. Run the manual Lambda test

After confirming SNS, run:

```bash
chmod +x manual_lambda_test.sh
./manual_lambda_test.sh
```

Expected result:

```text
StatusCode: 200
```

---

## Architecture

```text
GitHub Actions
  -> GitHub OIDC
  -> AWS IAM Role
  -> AWS CDK Deployment
  -> S3 + Lambda + SNS
  -> Upload sample_files/ to S3
  -> Invoke Lambda
  -> Email summary through SNS
```

---

## What the App Does

During deployment:

- CDK creates the AWS infrastructure.
- `sample_files/` is uploaded to the S3 bucket under `cat-images/`.
- The workflow invokes the Lambda function for verification.

During Lambda execution:

- Lambda lists the S3 objects.
- Lambda builds an execution summary.
- Lambda publishes the summary to SNS.
- SNS sends the email notification after subscription confirmation.

---

## Example Email Summary

The SNS email includes a short scan summary similar to:

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
- **Testing and CLI:** Pytest, AWS CLI

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

## GitHub Actions Deployment

The main deployment file is:

```text
.github/workflows/deploy.yml
```

The workflow is triggered manually with `workflow_dispatch`.

It performs:

1. AWS authentication through GitHub OIDC
2. Dependency installation
3. Unit tests
4. `cdk synth`
5. CDK deployment
6. Upload of `sample_files/` to S3
7. Lambda invocation for verification

This is the primary deployment path for the assignment.

---

## GitHub OIDC

This project does not use long-lived AWS access keys in GitHub.

`create_github_oidc.sh` creates or updates:

- GitHub OIDC provider in AWS
- IAM role for GitHub Actions
- Trust policy restricted to the selected repository and branch
- Permissions required for CDK deployment

The GitHub workflow then assumes this role using OIDC.

---

## Manual Lambda Test

The manual test script is:

```text
manual_lambda_test.sh
```

Run:

```bash
./manual_lambda_test.sh
```

Optional explicit usage:

```bash
./manual_lambda_test.sh CatCloudStack us-east-1
```

The script reads the Lambda function name from CloudFormation outputs and invokes it with:

```text
test-events/manual-test-event.json
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
| Secure AWS auth | GitHub OIDC |
| S3 bucket | Created by CDK |
| Local files uploaded during deployment | `sample_files/` uploaded by workflow |
| Lambda lists S3 objects | `lambda/s3_list_and_notify.py` |
| SNS email notification | Lambda publishes to SNS |
| Least-privilege IAM | CDK-defined Lambda role |
| Manual Lambda trigger | `manual_lambda_test.sh` |
| Test event | `test-events/manual-test-event.json` |