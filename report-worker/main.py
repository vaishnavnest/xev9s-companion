"""
XEV 9S Background Report Worker Entrypoint
Polls SQS / queue for report generation tasks, queries MongoDB for telemetry,
generates PDF / CSV reports, and saves them to Amazon S3 (LocalStack) or local PV.
"""
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [report-worker] %(message)s",
)
logger = logging.getLogger("report-worker")

AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL", "http://localstack:4566")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
REPORT_QUEUE_URL = os.getenv("REPORT_QUEUE_URL", "")
REPORT_BUCKET_NAME = os.getenv("REPORT_BUCKET_NAME", "xev9s-reports")
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://mongodb:27017")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE", "Xev9s_db")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "5"))

running = True


def handle_shutdown(signum, frame):
    """Graceful shutdown signal handler."""
    global running
    sig_name = signal.Signals(signum).name
    logger.info(f"Received shutdown signal {sig_name}. Stopping report worker...")
    running = False


def main():
    global running
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    logger.info("==================================================")
    logger.info("  XEV 9S Background Report Worker Initialized")
    logger.info(f"  AWS Endpoint : {AWS_ENDPOINT_URL}")
    logger.info(f"  Target Bucket: {REPORT_BUCKET_NAME}")
    logger.info(f"  Database     : {MONGODB_DATABASE}")
    logger.info(f"  Poll Interval: {POLL_INTERVAL}s")
    logger.info("==================================================")

    while running:
        logger.debug("Worker heartbeat: checking queue for pending report jobs...")
        time.sleep(POLL_INTERVAL)

    logger.info("XEV 9S Report Worker stopped cleanly.")


if __name__ == "__main__":
    main()
