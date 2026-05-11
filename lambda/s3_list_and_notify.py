import json
import os
from datetime import datetime, timezone

import boto3


s3_client = boto3.client("s3")
sns_client = boto3.client("sns")


def handler(event, context):
    bucket_name = os.environ["BUCKET_NAME"]
    topic_arn = os.environ["TOPIC_ARN"]

    response = s3_client.list_objects_v2(Bucket=bucket_name)

    objects = []

    for item in response.get("Contents", []):
        objects.append({
            "key": item["Key"],
            "size": item["Size"],
            "last_modified": item["LastModified"].isoformat()
        })

    execution_details = {
        "message": "CatCloud Lambda execution completed successfully.",
        "execution_time": datetime.now(timezone.utc).isoformat(),
        "bucket_name": bucket_name,
        "object_count": len(objects),
        "objects": objects,
        "request_id": context.aws_request_id if context else None,
        "trigger_event": event
    }

    sns_client.publish(
        TopicArn=topic_arn,
        Subject="CatCloud S3 Object Scan Completed",
        Message=json.dumps(execution_details, indent=2, default=str)
    )

    return {
        "statusCode": 200,
        "body": json.dumps(execution_details, indent=2, default=str)
    }