"""Unit tests for report-worker PDF and CSV report generation."""

import pytest

from generator import generate_csv_report, generate_pdf_report, generate_report_bytes


def test_generate_csv_report_with_trips():
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

    csv_bytes = generate_csv_report(vehicle, trips)
    text = csv_bytes.decode("utf-8")

    assert "XEV-DEMO-001" in text
    assert "32.50" in text
    assert "5.80" in text


def test_generate_pdf_report_with_and_without_trips():
    vehicle = {"vehicle_id": "XEV-DEMO-001", "model": "XEV 9S"}
    trips = [
        {
            "started_at": "2026-11-25T08:00:00Z",
            "ended_at": "2026-11-25T08:30:00Z",
            "distance_km": 15.0,
            "duration_minutes": 30.0,
            "energy_consumed_kwh": 2.5,
        }
    ]

    pdf_with_trips = generate_pdf_report(vehicle, trips)
    pdf_empty = generate_pdf_report(vehicle, [])

    assert pdf_with_trips.startswith(b"%PDF-")
    assert pdf_empty.startswith(b"%PDF-")


def test_generate_report_bytes_dispatch_and_invalid_format():
    vehicle = {"vehicle_id": "XEV-DEMO-001", "model": "XEV 9S"}

    pdf_data, pdf_mime = generate_report_bytes("pdf", vehicle, [])
    csv_data, csv_mime = generate_report_bytes("CSV", vehicle, [])

    assert pdf_mime == "application/pdf"
    assert pdf_data.startswith(b"%PDF-")
    assert csv_mime == "text/csv"
    assert b"XEV-DEMO-001" in csv_data

    with pytest.raises(ValueError, match="Unsupported report format"):
        generate_report_bytes("xlsx", vehicle, [])
