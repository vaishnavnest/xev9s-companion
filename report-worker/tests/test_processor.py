"""Unit tests for report-worker job processing and SQS polling."""

import json
from unittest.mock import MagicMock

import pytest

import main as worker_main
from processor import process_report_job


def _make_mock_database(vehicle: dict | None, trips: list[dict]):
    db = MagicMock()
    db["vehicles"].find_one.return_value = vehicle
    cursor = db["trips"].find.return_value
    cursor.sort.return_value.limit.return_value = trips
    return db


def test_process_report_job_success_pdf():
    vehicle = {"vehicle_id": "XEV-DEMO-001", "model": "XEV 9S"}
    trips = [
        {
            "started_at": "2026-11-25T08:00:00Z",
            "ended_at": "2026-11-25T08:45:00Z",
            "distance_km": 32.5,
            "duration_minutes": 45.0,
            "energy_consumed_kwh": 5.8,
        }
    ]
    db = _make_mock_database(vehicle, trips)
    s3_client = MagicMock()

    object_key = process_report_job(
        {"report_id": "rep-101", "vehicle_id": "XEV-DEMO-001", "format": "pdf"},
        db,
        s3_client,
        "xev9s-reports",
    )

    assert object_key == "reports/XEV-DEMO-001/rep-101.pdf"
    s3_client.put_object.assert_called_once()
    put_kwargs = s3_client.put_object.call_args.kwargs
    assert put_kwargs["Bucket"] == "xev9s-reports"
    assert put_kwargs["Key"] == object_key
    assert put_kwargs["ContentType"] == "application/pdf"
    assert db["reports"].update_one.call_count == 2


def test_process_report_job_missing_vehicle_marks_failed():
    db = _make_mock_database(None, [])
    s3_client = MagicMock()

    with pytest.raises(ValueError, match="Vehicle not found"):
        process_report_job(
            {"report_id": "rep-404", "vehicle_id": "UNKNOWN", "format": "csv"},
            db,
            s3_client,
            "xev9s-reports",
        )

    s3_client.put_object.assert_not_called()
    last_update = db["reports"].update_one.call_args_list[-1].args[1]["$set"]
    assert last_update["status"] == "Failed"
    assert "Vehicle not found" in last_update["failure_reason"]


def test_process_report_job_invalid_payload_raises():
    db = _make_mock_database(None, [])
    s3_client = MagicMock()

    with pytest.raises(ValueError, match="report_id"):
        process_report_job({"vehicle_id": "XEV-DEMO-001"}, db, s3_client, "xev9s-reports")


def test_poll_once_deletes_on_success_and_keeps_on_failure():
    vehicle = {"vehicle_id": "XEV-DEMO-001", "model": "XEV 9S"}
    db = _make_mock_database(vehicle, [])
    s3_client = MagicMock()
    sqs_client = MagicMock()
    sqs_client.receive_message.return_value = {
        "Messages": [
            {
                "MessageId": "msg-ok",
                "ReceiptHandle": "rh-ok",
                "Body": json.dumps({"report_id": "rep-1", "vehicle_id": "XEV-DEMO-001", "format": "csv"}),
            },
            {
                "MessageId": "msg-bad",
                "ReceiptHandle": "rh-bad",
                "Body": "{invalid-json",
            },
        ]
    }

    processed = worker_main.poll_once(sqs_client, s3_client, db)

    assert processed == 1
    sqs_client.delete_message.assert_called_once_with(
        QueueUrl=worker_main.REPORT_QUEUE_URL,
        ReceiptHandle="rh-ok",
    )
