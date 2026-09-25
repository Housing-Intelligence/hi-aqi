import json
import os
from datetime import datetime
from zoneinfo import ZoneInfo

import boto3

s3 = boto3.client("s3")

S3_BUCKET = os.environ["S3_BUCKET"]

def lambda_handler(event, context):
    china_tz = ZoneInfo("Asia/Shanghai")

    for record in event["Records"]:
        body = json.loads(record["body"])

        source = body["source"]
        records = body["records"]

        print(f"Processing source: {source}")
        print(f"Record count: {len(records)}")

        measurement_time = body.get("measurement_time")

        if measurement_time:
            dt = datetime.fromisoformat(
                measurement_time.replace("Z", "+00:00")
            )
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=china_tz)
            else:
                dt = dt.astimezone(china_tz)
        else:
            dt = datetime.now(china_tz)

        # S3 object key
        key = (
            f"raw_data/public_data/air_quality/"
            f"{source.lower()}/"
            f"year={dt.year}/"
            f"month={dt.month:02d}/"
            f"day={dt.day:02d}/"
            f"{source.lower()}_{dt.strftime('%Y%m%dT%H%M%S')}.json"
        )

        # Write original SQS payload to S3
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=json.dumps(
                body,
                ensure_ascii=False
            ).encode("utf-8"),
            ContentType="application/json",
        )

        print(f"Written to s3://{S3_BUCKET}/{key}")

    return {
        "statusCode": 200
    }

    