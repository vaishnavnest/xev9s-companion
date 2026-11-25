"""Report file generation (PDF and CSV) for XEV 9S trip & energy reports."""

import csv
import io
from datetime import UTC, datetime
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


def _format_trip_rows(trips: list[dict[str, Any]]) -> list[list[str]]:
    """Convert MongoDB trip documents into tabular string rows."""
    rows = [["Start Time", "End Time", "Distance (km)", "Duration (min)", "Energy (kWh)"]]
    for trip in trips:
        start = str(trip.get("started_at", "N/A"))[:19]
        end = str(trip.get("ended_at", "N/A"))[:19]
        distance = f"{float(trip.get('distance_km', 0.0)):.2f}"
        duration = f"{float(trip.get('duration_minutes', 0.0)):.1f}"
        energy = f"{float(trip.get('energy_consumed_kwh', 0.0)):.2f}"
        rows.append([start, end, distance, duration, energy])
    return rows


def generate_csv_report(
    vehicle: dict[str, Any],
    trips: list[dict[str, Any]],
) -> bytes:
    """Build a UTF-8 CSV report containing vehicle summary and trip rows."""
    buffer = io.StringIO()
    writer = csv.writer(buffer)

    writer.writerow(["XEV 9S Companion - Vehicle Trip Report"])
    writer.writerow(["Vehicle ID", vehicle.get("vehicle_id", "unknown")])
    writer.writerow(["Model", vehicle.get("model", "XEV 9S")])
    writer.writerow(["Generated At (UTC)", datetime.now(UTC).isoformat()])
    writer.writerow([])

    for row in _format_trip_rows(trips):
        writer.writerow(row)

    return buffer.getvalue().encode("utf-8")


def generate_pdf_report(
    vehicle: dict[str, Any],
    trips: list[dict[str, Any]],
) -> bytes:
    """Build a PDF trip & energy report using ReportLab."""
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4)
    styles = getSampleStyleSheet()

    vehicle_id = vehicle.get("vehicle_id", "unknown")
    model = vehicle.get("model", "XEV 9S")
    generated_at = datetime.now(UTC).strftime("%Y-%m-%d %H:%M:%S UTC")

    total_distance = sum(float(t.get("distance_km", 0.0)) for t in trips)
    total_energy = sum(float(t.get("energy_consumed_kwh", 0.0)) for t in trips)

    elements: list[Any] = [
        Paragraph("XEV 9S Companion — Vehicle Trip Report", styles["Title"]),
        Spacer(1, 12),
        Paragraph(f"<b>Vehicle ID:</b> {vehicle_id}", styles["Normal"]),
        Paragraph(f"<b>Model:</b> {model}", styles["Normal"]),
        Paragraph(f"<b>Generated At:</b> {generated_at}", styles["Normal"]),
        Paragraph(
            f"<b>Completed Trips:</b> {len(trips)} | "
            f"<b>Total Distance:</b> {total_distance:.2f} km | "
            f"<b>Total Energy:</b> {total_energy:.2f} kWh",
            styles["Normal"],
        ),
        Spacer(1, 16),
    ]

    if trips:
        table = Table(_format_trip_rows(trips), repeatRows=1)
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F2937")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F4F6")]),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                ]
            )
        )
        elements.append(table)
    else:
        elements.append(Paragraph("No completed trips recorded for this period.", styles["Italic"]))

    doc.build(elements)
    return buffer.getvalue()


def generate_report_bytes(
    report_format: str,
    vehicle: dict[str, Any],
    trips: list[dict[str, Any]],
) -> tuple[bytes, str]:
    """Generate report bytes and MIME content type for the requested format."""
    fmt = report_format.lower().strip()
    if fmt == "csv":
        return generate_csv_report(vehicle, trips), "text/csv"
    if fmt == "pdf":
        return generate_pdf_report(vehicle, trips), "application/pdf"
    raise ValueError(f"Unsupported report format: {report_format}")
