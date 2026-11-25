import os

from dotenv import load_dotenv

load_dotenv()

VEHICLE_ONLINE_TIMEOUT_SECONDS = int(
    os.getenv("VEHICLE_ONLINE_TIMEOUT_SECONDS", "30")
)

if VEHICLE_ONLINE_TIMEOUT_SECONDS <= 0:
    raise ValueError(
        "VEHICLE_ONLINE_TIMEOUT_SECONDS must be positive"
    )
COMMAND_EXECUTION_TIMEOUT_SECONDS = int(
    os.getenv("COMMAND_EXECUTION_TIMEOUT_SECONDS", "10")
)

if COMMAND_EXECUTION_TIMEOUT_SECONDS <= 0:
    raise ValueError(
        "COMMAND_EXECUTION_TIMEOUT_SECONDS must be positive"
    )