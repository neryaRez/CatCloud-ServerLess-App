import json
import os
from datetime import datetime, timezone

import boto3


s3_client = boto3.client("s3")
sns_client = boto3.client("sns")


def format_file_size(size_in_bytes):
    if size_in_bytes < 1024:
        return f"{size_in_bytes} bytes"

    if size_in_bytes < 1024 * 1024:
        return f"{size_in_bytes / 1024:.2f} KB"

    return f"{size_in_bytes / (1024 * 1024):.2f} MB"


def handler(event, context):
    bucket_name = os.environ["BUCKET_NAME"]
    topic_arn = os.environ["TOPIC_ARN"]

    response = s3_client.list_objects_v2(Bucket=bucket_name)

    objects = []

    for item in response.get("Contents", []):
        object_key = item["Key"]

        presigned_url = s3_client.generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": bucket_name,
                "Key": object_key,
            },
            ExpiresIn=3600,
        )

        objects.append({
            "key": object_key,
            "size": item["Size"],
            "size_readable": format_file_size(item["Size"]),
            "last_modified": item["LastModified"].isoformat(),
            "view_url": presigned_url,
        })

    execution_time = datetime.now(timezone.utc).isoformat()

    execution_details = {
        "message": "CatCloud Lambda execution completed successfully.",
        "execution_time": execution_time,
        "bucket_name": bucket_name,
        "object_count": len(objects),
        "objects": objects,
        "request_id": context.aws_request_id if context else None,
        "trigger_event": event,
    }

    email_lines = [
        "🐱 CatCloud Scan Completed",
        "",
        "Your CatCloud Lambda function ran successfully.",
        "",
        f"Execution time: {execution_time}",
        f"Bucket name: {bucket_name}",
        f"Images found: {len(objects)}",
        "",
        "Uploaded cat images:",
        "",
    ]

    if objects:
        for index, obj in enumerate(objects, start=1):
            email_lines.extend([
                f"{index}. {obj['key']}",
                f"   Size: {obj['size_readable']}",
                f"   Last modified: {obj['last_modified']}",
                "",
            ])

        email_lines.extend([
            "Note:",
            "The S3 bucket is private. Temporary image links are returned in the Lambda response JSON for manual testing.",
            "This SNS email intentionally keeps the message clean and avoids long presigned URLs.",
        ])
    else:
        email_lines.append("No objects were found in the bucket.")

    email_message = "\n".join(email_lines)

    sns_client.publish(
        TopicArn=topic_arn,
        Subject="CatCloud Scan Completed",
        Message=email_message,
    )

    return {
        "statusCode": 200,
        "body": json.dumps(execution_details, indent=2, default=str),
    }