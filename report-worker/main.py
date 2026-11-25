"""
XEV 9S Background Report Worker Entrypoint.

Polls Amazon SQS (LocalStack) for report generation tasks, queries MongoDB,
generates PDF/CSV reports, uploads them to S3, and updates MongoDB status.
Failed jobs are left unacknowledged so SQS retries and routes them to the DLQ.
"""

import json
import logging
import os
import signal
import time
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from pymongo import MongoClient
from pymongo.errors import PyMongoError

from processor import process_report_job

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [report-worker] %(message)s",
)
logger = logging.getLogger("report-worker")

AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL", "http://localstack:4566")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
REPORT_QUEUE_URL = os.getenv(
    "REPORT_QUEUE_URL",
    "http://localstack:4566/000000000000/xev9s-report-queue",
)
REPORT_BUCKET_NAME = os.getenv("REPORT_BUCKET_NAME", "xev9s-reports")
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://mongodb:27017")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE", "Xev9s_db")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "5"))

running = True


def handle_shutdown(signum: int, _frame: Any) -> None:
    """Graceful shutdown signal handler."""
    global running
    sig_name = signal.Signals(signum).name
    logger.info("Received %s. Stopping report worker...", sig_name)
    running = False


def create_aws_clients() -> tuple[Any, Any]:
    """Create boto3 SQS and S3 clients configured for LocalStack."""
    aws_kwargs = {
        "region_name": AWS_REGION,
        "endpoint_url": AWS_ENDPOINT_URL,
        "aws_access_key_id": os.getenv("AWS_ACCESS_KEY_ID", "test"),  # gitleaks:allow
        "aws_secret_access_key": os.getenv("AWS_SECRET_ACCESS_KEY", "test"),  # gitleaks:allow
    }
    return boto3.client("sqs", **aws_kwargs), boto3.client("s3", **aws_kwargs)


def poll_once(
    sqs_client: Any,
    s3_client: Any,
    database: Any,
) -> int:
    """Receive and process up to 5 SQS messages. Returns processed count."""
    response = sqs_client.receive_message(
        QueueUrl=REPORT_QUEUE_URL,
        MaxNumberOfMessages=5,
        WaitTimeSeconds=10,
    )
    messages = response.get("Messages", [])
    processed = 0

    for message in messages:
        receipt_handle = message["ReceiptHandle"]
        try:
            payload = json.loads(message["Body"])
            process_report_job(payload, database, s3_client, REPORT_BUCKET_NAME)
            sqs_client.delete_message(
                QueueUrl=REPORT_QUEUE_URL,
                ReceiptHandle=receipt_handle,
            )
            processed += 1
        except (json.JSONDecodeError, ValueError, KeyError, BotoCoreError, ClientError, PyMongoError) as exc:
            logger.warning(
                "Message %s left in queue for retry/DLQ due to error: %s",
                message.get("MessageId"),
                exc,
            )

    return processed


def main() -> None:
    """Initialize clients and run the SQS polling loop."""
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    logger.info("Starting XEV 9S Report Worker (endpoint=%s, bucket=%s)", AWS_ENDPOINT_URL, REPORT_BUCKET_NAME)
    mongo_client = MongoClient(MONGODB_URI)
    database = mongo_client[MONGODB_DATABASE]
    sqs_client, s3_client = create_aws_clients()

    try:
        while running:
            try:
                poll_once(sqs_client, s3_client, database)
            except (BotoCoreError, ClientError) as exc:
                logger.warning("SQS poll error (retrying in %ss): %s", POLL_INTERVAL, exc)
                time.sleep(POLL_INTERVAL)
            except (PyMongoError, OSError):
                logger.exception("Unexpected worker error")
                time.sleep(POLL_INTERVAL)
    finally:
        mongo_client.close()
        logger.info("XEV 9S Report Worker stopped cleanly.")


if __name__ == "__main__":
    main()
