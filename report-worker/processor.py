"""Report job processor: reads MongoDB data, generates files, uploads to S3."""

import logging
from datetime import UTC, datetime
from typing import Any

from pymongo.database import Database

from generator import generate_report_bytes

logger = logging.getLogger("report-worker")


def _update_report_status(
    database: Database,
    report_id: str,
    status: str,
    extra_fields: dict[str, Any] | None = None,
) -> None:
    """Update report job status and metadata in MongoDB."""
    update_doc: dict[str, Any] = {
        "status": status,
        "updated_at": datetime.now(UTC),
    }
    if extra_fields:
        update_doc.update(extra_fields)

    database["reports"].update_one(
        {"report_id": report_id},
        {"$set": update_doc},
        upsert=True,
    )


def _fetch_vehicle_and_trips(
    database: Database,
    vehicle_id: str,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Retrieve vehicle record and its completed trips from MongoDB."""
    vehicle = database["vehicles"].find_one({"vehicle_id": vehicle_id})
    if vehicle is None:
        raise ValueError(f"Vehicle not found: {vehicle_id}")

    trips = list(
        database["trips"]
        .find({"vehicle_id": vehicle_id})
        .sort("started_at", -1)
        .limit(100)
    )
    return vehicle, trips


def process_report_job(
    payload: dict[str, Any],
    database: Database,
    s3_client: Any,
    bucket_name: str,
) -> str:
    """Execute a single report generation job and return the S3 object key."""
    report_id = payload.get("report_id")
    vehicle_id = payload.get("vehicle_id")
    report_format = payload.get("format", "pdf").lower().strip()

    if not report_id or not vehicle_id:
        raise ValueError("Job payload must include 'report_id' and 'vehicle_id'")

    logger.info(
        "correlation_id=%s event=report_processing_started vehicle_id=%s format=%s",
        report_id,
        vehicle_id,
        report_format,
    )
    _update_report_status(database, report_id, "Processing")

    try:
        vehicle, trips = _fetch_vehicle_and_trips(database, vehicle_id)
        content, content_type = generate_report_bytes(report_format, vehicle, trips)
        object_key = f"reports/{vehicle_id}/{report_id}.{report_format}"

        s3_client.put_object(
            Bucket=bucket_name,
            Key=object_key,
            Body=content,
            ContentType=content_type,
        )

        _update_report_status(
            database,
            report_id,
            "Completed",
            {
                "vehicle_id": vehicle_id,
                "format": report_format,
                "object_key": object_key,
                "completed_at": datetime.now(UTC),
                "failure_reason": None,
            },
        )
        logger.info(
            "correlation_id=%s event=report_completed object_key=%s bytes=%d",
            report_id,
            object_key,
            len(content),
        )
        return object_key

    except Exception as exc:
        _update_report_status(
            database,
            report_id,
            "Failed",
            {
                "vehicle_id": vehicle_id,
                "format": report_format,
                "failure_reason": str(exc),
            },
        )
        logger.error(
            "correlation_id=%s event=report_failed reason=%s",
            report_id,
            str(exc),
        )
        raise
