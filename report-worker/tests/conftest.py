"""Pytest configuration for report-worker unit tests."""

import sys
from pathlib import Path

# Ensure report-worker root is importable when pytest runs from repo root
REPORT_WORKER_DIR = Path(__file__).resolve().parent.parent
if str(REPORT_WORKER_DIR) not in sys.path:
    sys.path.insert(0, str(REPORT_WORKER_DIR))
