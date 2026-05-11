from aws_cdk import (
    CfnOutput,
    Duration,
    RemovalPolicy,
    Stack,
    Tags,
    aws_iam as iam,
    aws_lambda as lambda_,
    aws_s3 as s3,
    aws_s3_deployment as s3_deployment,
    aws_sns as sns,
    aws_sns_subscriptions as sns_subscriptions,
)
from constructs import Construct

class CatCloudStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        notification_email = self.node.try_get_context("notification_email")

        if not notification_email:
            raise ValueError(
                "Missing required context value: notification_email. "
                "Run: cdk deploy -c notification_email=your-email@example.com"
            )

        catcloud_bucket = s3.Bucket(
            self,
            "CatCloudBucket",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            versioned=False,
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True,
        )

        catcloud_topic = sns.Topic(
            self,
            "CatCloudTopic",
            display_name="CatCloud Notifications",
        )

        catcloud_topic.add_subscription(
            sns_subscriptions.EmailSubscription(notification_email)
        )


        catcloud_lambda_role = iam.Role(
            self,
            "CatCloudLambdaRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            description="Least-privilege execution role for the CatCloud Lambda function",
        )

        catcloud_lambda_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name(
                "service-role/AWSLambdaBasicExecutionRole"
            )
        )

        catcloud_bucket.grant_read(catcloud_lambda_role)
        catcloud_topic.grant_publish(catcloud_lambda_role)

        catcloud_lambda = lambda_.Function(
            self,
            "CatCloudListObjectsFunction",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="s3_list_and_notify.handler",
            code=lambda_.Code.from_asset("../lambda"),
            role=catcloud_lambda_role,
            timeout=Duration.seconds(30),
            memory_size=128,
            environment={
                "BUCKET_NAME": catcloud_bucket.bucket_name,
                "TOPIC_ARN": catcloud_topic.topic_arn,
            },
        )

        CfnOutput(
            self,
            "CatCloudBucketName",
            value=catcloud_bucket.bucket_name,
            description="Name of the S3 bucket used by CatCloud",
        )

        CfnOutput(
            self,
            "CatCloudTopicArn",
            value=catcloud_topic.topic_arn,
            description="ARN of the SNS topic used by CatCloud",
        )

        CfnOutput(
            self,
            "NotificationEmail",
            value=notification_email,
            description="Email address subscribed to CatCloud SNS notifications",
        )

        CfnOutput(
            self,
            "CatCloudLambdaFunctionName",
            value=catcloud_lambda.function_name,
            description="Name of the CatCloud Lambda function",
        )

        CfnOutput(
            self,
            "CatCloudLambdaRoleArn",
            value=catcloud_lambda_role.role_arn,
            description="ARN of the IAM role attached to the CatCloud Lambda function",
        )    