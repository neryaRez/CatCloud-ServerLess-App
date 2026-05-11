#!/bin/bash
set -e

export AWS_PAGER=""

ROLE_NAME="CatCloudGitHubActionsDeployRole"
POLICY_NAME="CatCloudGitHubActionsDeployPolicy"
OIDC_PROVIDER_URL="token.actions.githubusercontent.com"
DEFAULT_BRANCH="main"

echo "======================================"
echo "🔐 CatCloud GitHub OIDC Setup"
echo "======================================"
echo

echo "Checking AWS identity..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo

AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

echo "AWS Region: $AWS_REGION"
echo

GIT_REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)

DEFAULT_OWNER=""
DEFAULT_REPO=""

if [[ "$GIT_REMOTE_URL" == git@github.com:* ]]; then
  REPO_PATH="${GIT_REMOTE_URL#git@github.com:}"
  REPO_PATH="${REPO_PATH%.git}"
  DEFAULT_OWNER="${REPO_PATH%%/*}"
  DEFAULT_REPO="${REPO_PATH##*/}"
elif [[ "$GIT_REMOTE_URL" == https://github.com/* ]]; then
  REPO_PATH="${GIT_REMOTE_URL#https://github.com/}"
  REPO_PATH="${REPO_PATH%.git}"
  DEFAULT_OWNER="${REPO_PATH%%/*}"
  DEFAULT_REPO="${REPO_PATH##*/}"
fi

echo "GitHub repository detection:"
echo "Owner: ${DEFAULT_OWNER:-not detected}"
echo "Repo:  ${DEFAULT_REPO:-not detected}"
echo

read -p "Enter GitHub owner/user/org [${DEFAULT_OWNER}]: " GITHUB_OWNER
read -p "Enter GitHub repo name [${DEFAULT_REPO}]: " GITHUB_REPO
read -p "Enter branch name [${DEFAULT_BRANCH}]: " BRANCH_NAME

GITHUB_OWNER="${GITHUB_OWNER:-$DEFAULT_OWNER}"
GITHUB_REPO="${GITHUB_REPO:-$DEFAULT_REPO}"
BRANCH_NAME="${BRANCH_NAME:-$DEFAULT_BRANCH}"

if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
  echo "Error: GitHub owner and repo name are required."
  exit 1
fi

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_URL}"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

echo
echo "Configuration:"
echo "GitHub repo: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "Branch:      ${BRANCH_NAME}"
echo "Role name:   ${ROLE_NAME}"
echo

echo "Checking if GitHub OIDC provider already exists..."

EXISTING_PROVIDER=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, '${OIDC_PROVIDER_URL}')].Arn" \
  --output text)

if [ -z "$EXISTING_PROVIDER" ]; then
  echo "GitHub OIDC provider was not found. Creating it..."

  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_PROVIDER_URL}" \
    --client-id-list "sts.amazonaws.com"

  echo "GitHub OIDC provider created."
else
  echo "GitHub OIDC provider already exists:"
  echo "$EXISTING_PROVIDER"
fi

echo
echo "Creating trust policy..."

cat > /tmp/catcloud-github-oidc-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/${BRANCH_NAME}"
        }
      }
    }
  ]
}
EOF

echo "Creating or updating IAM role..."

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role already exists. Updating trust policy..."

  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file:///tmp/catcloud-github-oidc-trust-policy.json
else
  echo "Role does not exist. Creating role..."

  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/catcloud-github-oidc-trust-policy.json \
    --description "GitHub Actions OIDC deployment role for CatCloud"
fi

echo
echo "Creating deployment permissions policy..."

cat > /tmp/catcloud-github-oidc-permissions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StsIdentityCheck",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFormationManageCatCloudStack",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateChangeSet",
        "cloudformation:CreateStack",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeChangeSet",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResource",
        "cloudformation:DescribeStackResources",
        "cloudformation:DescribeStacks",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:GetTemplate",
        "cloudformation:GetTemplateSummary",
        "cloudformation:ListStackResources",
        "cloudformation:UpdateStack",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": [
        "arn:aws:cloudformation:*:${AWS_ACCOUNT_ID}:stack/CatCloudStack/*",
        "arn:aws:cloudformation:*:${AWS_ACCOUNT_ID}:stack/CDKToolkit/*"
      ]
    },
    {
      "Sid": "S3ManageCatCloudAndCdkAssets",
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:DeleteBucketPolicy",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketEncryption",
        "s3:GetBucketLocation",
        "s3:GetBucketPolicy",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListBucketVersions",
        "s3:ListMultipartUploadParts",
        "s3:PutBucketEncryption",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketTagging",
        "s3:PutObject",
        "s3:PutObjectTagging"
      ],
      "Resource": [
        "arn:aws:s3:::catcloudstack-*",
        "arn:aws:s3:::catcloudstack-*/*",
        "arn:aws:s3:::cdk-hnb659fds-assets-${AWS_ACCOUNT_ID}-*",
        "arn:aws:s3:::cdk-hnb659fds-assets-${AWS_ACCOUNT_ID}-*/*"
      ]
    },
    {
      "Sid": "LambdaManageCatCloudFunctions",
      "Effect": "Allow",
      "Action": [
        "lambda:AddPermission",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:InvokeFunction",
        "lambda:ListVersionsByFunction",
        "lambda:PublishVersion",
        "lambda:RemovePermission",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration"
      ],
      "Resource": [
        "arn:aws:lambda:*:${AWS_ACCOUNT_ID}:function:CatCloudStack-*"
      ]
    },
    {
      "Sid": "SnsManageCatCloudTopicAndSubscriptions",
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:ListSubscriptionsByTopic",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:TagResource",
        "sns:Unsubscribe"
      ],
      "Resource": [
        "arn:aws:sns:*:${AWS_ACCOUNT_ID}:CatCloudStack-*"
      ]
    },
    {
      "Sid": "IamManageCatCloudRolesOnly",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:PutRolePolicy",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/CatCloudStack-*"
      ]
    },
    {
      "Sid": "AllowPassingCatCloudRolesToLambdaOnly",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/CatCloudStack-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    },
    {
     "Sid": "AllowPassingCdkExecutionRoleToCloudFormation",
     "Effect": "Allow",
     "Action": [
      "iam:PassRole"
    ],
    "Resource": [
      "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cdk-hnb659fds-cfn-exec-role-${AWS_ACCOUNT_ID}-${AWS_REGION}"
    ],
    "Condition": {
      "StringEquals": {
        "iam:PassedToService": "cloudformation.amazonaws.com"
      }
     }
    },
    {
    "Sid": "AllowAssumingCdkBootstrapRoles",
    "Effect": "Allow",
    "Action": [
        "sts:AssumeRole"
    ],
    "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cdk-hnb659fds-deploy-role-${AWS_ACCOUNT_ID}-${AWS_REGION}",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cdk-hnb659fds-file-publishing-role-${AWS_ACCOUNT_ID}-${AWS_REGION}",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cdk-hnb659fds-image-publishing-role-${AWS_ACCOUNT_ID}-${AWS_REGION}",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cdk-hnb659fds-lookup-role-${AWS_ACCOUNT_ID}-${AWS_REGION}"
    ]
    },
    {
      "Sid": "LogsManageCatCloudLogGroups",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource"
      ],
      "Resource": [
        "arn:aws:logs:*:${AWS_ACCOUNT_ID}:log-group:/aws/lambda/CatCloudStack-*",
        "arn:aws:logs:*:${AWS_ACCOUNT_ID}:log-group:/aws/lambda/CatCloudStack-*:*"
      ]
    },
    {
      "Sid": "SsmReadCdkBootstrapVersion",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:*:${AWS_ACCOUNT_ID}:parameter/cdk-bootstrap/*"
      ]
    }
  ]
}
EOF

echo "Attaching inline policy to role..."

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/catcloud-github-oidc-permissions-policy.json

rm -f /tmp/catcloud-github-oidc-trust-policy.json
rm -f /tmp/catcloud-github-oidc-permissions-policy.json

echo
echo "======================================"
echo "GitHub OIDC setup completed ✅"
echo "======================================"
echo
echo "Add this secret to your GitHub repository:"
echo
echo "Secret name:"
echo "AWS_ROLE_TO_ASSUME"
echo
echo "Secret value:"
echo "$ROLE_ARN"
echo
echo "Also add this GitHub Actions variable:"
echo
echo "Variable name:"
echo "AWS_REGION"
echo
echo "Secret value:"
echo "$AWS_REGION"
echo
echo "GitHub Actions will use this role with OIDC."
echo