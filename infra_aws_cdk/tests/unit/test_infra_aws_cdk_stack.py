import aws_cdk as cdk
from aws_cdk.assertions import Template, Match

from infra_aws_cdk.cat_cloud_stack import CatCloudStack


def create_template():
    app = cdk.App(context={
        "notification_email": "test@example.com"
    })

    stack = CatCloudStack(app, "TestCatCloudStack")
    return Template.from_stack(stack)


def test_s3_bucket_created():
    template = create_template()

    template.resource_count_is("AWS::S3::Bucket", 1)

    template.has_resource_properties("AWS::S3::Bucket", {
        "BucketEncryption": {
            "ServerSideEncryptionConfiguration": [
                {
                    "ServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        },
        "PublicAccessBlockConfiguration": {
            "BlockPublicAcls": True,
            "BlockPublicPolicy": True,
            "IgnorePublicAcls": True,
            "RestrictPublicBuckets": True
        }
    })


def test_sns_topic_and_email_subscription_created():
    template = create_template()

    template.resource_count_is("AWS::SNS::Topic", 1)

    template.has_resource_properties("AWS::SNS::Subscription", {
        "Protocol": "email",
        "Endpoint": "test@example.com"
    })


def test_lambda_function_created_with_environment_variables():
    template = create_template()

    template.has_resource_properties("AWS::Lambda::Function", {
        "Runtime": "python3.12",
        "Handler": "s3_list_and_notify.handler",
        "Environment": {
            "Variables": {
                "BUCKET_NAME": Match.any_value(),
                "TOPIC_ARN": Match.any_value()
            }
        },
        "Timeout": 30,
        "MemorySize": 128
    })


def test_lambda_execution_role_created():
    template = create_template()

    template.has_resource_properties("AWS::IAM::Role", {
        "AssumeRolePolicyDocument": {
            "Statement": Match.array_with([
                Match.object_like({
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                })
            ])
        }
    })


def test_lambda_role_has_s3_read_and_sns_publish_permissions():
    template = create_template()

    template.has_resource_properties("AWS::IAM::Policy", {
        "PolicyDocument": {
            "Statement": Match.array_with([
                Match.object_like({
                    "Effect": "Allow",
                    "Action": Match.array_with([
                        "s3:GetObject*",
                        "s3:List*"
                    ])
                }),
                Match.object_like({
                    "Effect": "Allow",
                    "Action": "sns:Publish"
                })
            ])
        }
    })