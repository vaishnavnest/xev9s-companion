"""
XEV 9S Vehicle Simulator Entrypoint
Simulates connected vehicle state transitions, telemetry streaming,
and remote command processing for the XEV 9S electric vehicle.
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
    format="%(asctime)s [%(levelname)s] [simulator] %(message)s",
)
logger = logging.getLogger("simulator")

VEHICLE_ID = os.getenv("VEHICLE_ID", "xev9s-001")
MQTT_HOST = os.getenv("MQTT_BROKER_HOST", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_BROKER_PORT", "1883"))
TELEMETRY_INTERVAL = int(os.getenv("TELEMETRY_INTERVAL", "5"))

running = True


def handle_shutdown(signum, frame):
    """Graceful shutdown signal handler."""
    global running
    sig_name = signal.Signals(signum).name
    logger.info(f"Received shutdown signal {sig_name}. Stopping simulator...")
    running = False


def generate_baseline_telemetry(vehicle_id: str, battery: float) -> dict:
    """Generate a valid baseline telemetry dictionary adhering to openapi schema."""
    return {
        "vehicleId": vehicle_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "batteryLevel": round(battery, 1),
        "rangeKm": round(battery * 3.7, 1),
        "speed": 0.0,
        "odometer": 12450.5,
        "state": "PARKED",
        "lockStatus": "LOCKED",
        "chargingStatus": "NOT_CHARGING",
        "chargingPowerKw": 0.0,
        "targetChargingPercent": 80,
        "cabinPreconditioning": False,
        "connectivity": "ONLINE",
    }


def main():
    global running
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    logger.info("==================================================")
    logger.info(f"  XEV 9S Vehicle Simulator Engine Initialized")
    logger.info(f"  Vehicle ID : {VEHICLE_ID}")
    logger.info(f"  MQTT Broker: {MQTT_HOST}:{MQTT_PORT}")
    logger.info(f"  Interval   : {TELEMETRY_INTERVAL}s")
    logger.info("==================================================")

    current_battery = 65.0

    while running:
        telemetry = generate_baseline_telemetry(VEHICLE_ID, current_battery)
        logger.info(
            f"Vehicle state: {telemetry['state']} | "
            f"Battery: {telemetry['batteryLevel']}% | "
            f"Range: {telemetry['rangeKm']} km"
        )
        time.sleep(TELEMETRY_INTERVAL)

    logger.info("XEV 9S Vehicle Simulator stopped cleanly.")


if __name__ == "__main__":
    main()
