import os

from dotenv import load_dotenv

load_dotenv()

DEFAULT_BATTERY_CAPACITY_KWH = float(os.getenv("DEFAULT_BATTERY_CAPACITY_KWH", "60.0"))
if DEFAULT_BATTERY_CAPACITY_KWH <= 0:
    raise ValueError("DEFAULT_BATTERY_CAPACITY_KWH must be positive")

TRIP_START_STATE = os.getenv("TRIP_START_STATE", "driving")
TRIP_END_STATE = os.getenv("TRIP_END_STATE", "parked")
