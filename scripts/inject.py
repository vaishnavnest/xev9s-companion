"""
inject.py — Manually push real-time telemetry data to the running XEV 9S mock servers.

Usage:
  python scripts/inject.py [options]

Vehicle State Options (--state):
  PARKED    Vehicle is parked (default)
  DRIVING   Vehicle is in motion
  CHARGING  Vehicle is charging
  OFFLINE   Vehicle is offline

Charging State Options (--charging):
  NOT_CONNECTED   No charger plugged in (default)
  CONNECTED       Charger plugged in, not charging
  CHARGING        Actively charging
  PAUSED          Charging paused
  COMPLETED       Charge target reached

Lock State Options (--lock):
  LOCKED      Doors locked (default)
  UNLOCKED    Doors unlocked

Climate Options (--climate):
  INACTIVE    Climate preconditioning off (default)
  ACTIVE      Climate preconditioning running

Examples:
  # Show dashboard telemetry: 64% battery, parked, locked
  python scripts/inject.py --battery 64 --state PARKED --lock LOCKED

  # Vehicle driving at 95 km/h, 55% battery
  python scripts/inject.py --battery 55.0 --speed 95.0 --state DRIVING --lock LOCKED

  # Low battery warning
  python scripts/inject.py --battery 12.0 --state PARKED

  # Start charging at 48.5 kW
  python scripts/inject.py --battery 42.0 --state CHARGING --charging CHARGING --power 48.5

  # Climate preconditioning on, doors unlocked
  python scripts/inject.py --climate ACTIVE --lock UNLOCKED

  # Vehicle goes offline → stale banner appears in app
  python scripts/inject.py --offline

  # Vehicle back online
  python scripts/inject.py --online

  # Update odometer
  python scripts/inject.py --odometer 15000.0
"""

import argparse
import json
import sys
import urllib.request
import urllib.error

REST_CONTROL = "http://127.0.0.1:4010/control"
WS_CONTROL   = "http://127.0.0.1:4012/control"

RESET  = "\033[0m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
DIM    = "\033[2m"


def post(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url, data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=3) as resp:
        return json.loads(resp.read())


def print_state(label: str, s: dict):
    battery = s.get("batteryPercent", s.get("battery", "?"))
    try:
        bval = float(battery)
        bcolor = RED if bval <= 20 else YELLOW if bval <= 40 else GREEN
        bstr = f"{bcolor}{bval}%{RESET}"
    except Exception:
        bstr = str(battery)

    rows = [
        ("Battery",          bstr),
        ("Speed",            f"{s.get('speed', s.get('speedKmh', '?'))} km/h"),
        ("Vehicle State",    s.get("vehicleState", "?")),
        ("Connectivity",     "ONLINE" if s.get("isOnline", True) else "OFFLINE"),
        ("Lock State",       s.get("lockState", "?")),
        ("Climate",          s.get("preconditioningState", "?")),
        ("Charging",         s.get("chargingState", "?")),
        ("Charging Power",   f"{s.get('powerKw', 'None')} kW"),
        ("Odometer",         f"{s.get('odometerKm', '?')} km"),
    ]
    print(f"  {BOLD}{label}{RESET}")
    for k, v in rows:
        print(f"    {DIM}{k:<18}{RESET} {v}")


def main():
    parser = argparse.ArgumentParser(
        description="Inject real-time telemetry into the XEV 9S mock servers.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    # Telemetry fields
    parser.add_argument("--battery",  type=float,  help="Battery %% (0–100)")
    parser.add_argument("--speed",    type=float,  help="Speed in km/h")
    parser.add_argument("--state",    type=str,    help="Vehicle state: PARKED | DRIVING | CHARGING | OFFLINE")
    parser.add_argument("--charging", type=str,    help="Charging state: NOT_CONNECTED | CONNECTED | CHARGING | PAUSED | COMPLETED")
    parser.add_argument("--power",    type=float,  help="Charging power in kW (e.g. 48.5)")
    parser.add_argument("--lock",     type=str,    help="Lock state: LOCKED | UNLOCKED")
    parser.add_argument("--climate",  type=str,    help="Preconditioning: INACTIVE | ACTIVE")
    parser.add_argument("--odometer", type=float,  help="Odometer reading in km")
    parser.add_argument("--vehicle",  type=str,    help="Target vehicle ID (default: broadcast to currently subscribed vehicle)")

    # Connectivity shortcuts
    parser.add_argument("--offline",  action="store_true", help="Set vehicle offline")
    parser.add_argument("--online",   action="store_true", help="Set vehicle back online")

    # Event type
    parser.add_argument(
        "--event", type=str, default="vehicle.status",
        choices=["vehicle.status", "charging.updated", "connectivity.changed"],
        help="WS event type to broadcast (default: vehicle.status)",
    )

    # Server targeting
    parser.add_argument("--rest-only", action="store_true", help="Only update REST server (port 4010)")
    parser.add_argument("--ws-only",   action="store_true", help="Only update WS server (port 4012)")

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    # ── Build payload ────────────────────────────────────────────────────────
    payload: dict = {}

    if args.battery  is not None: payload["battery"]               = args.battery
    if args.speed    is not None:
        payload["speedKmh"] = args.speed
        if args.state is None:
            payload["vehicleState"] = "DRIVING" if args.speed > 0 else "PARKED"
    if args.state    is not None: payload["vehicleState"]          = args.state.upper()
    if args.charging is not None: payload["chargingState"]         = args.charging.upper()
    if args.power    is not None: payload["powerKw"]               = args.power
    if args.lock     is not None: payload["lockState"]             = args.lock.upper()
    if args.climate  is not None: payload["preconditioningState"]  = args.climate.upper()
    if args.odometer is not None: payload["odometerKm"]            = args.odometer
    if args.vehicle  is not None: payload["vehicleId"]             = args.vehicle.strip()

    # Connectivity shortcuts
    if args.offline:
        payload["isOnline"] = False
        if args.event == "vehicle.status":
            args.event = "connectivity.changed"
    if args.online:
        payload["isOnline"] = True
        if args.event == "vehicle.status":
            args.event = "connectivity.changed"

    payload["event"] = args.event

    # ── Print header ─────────────────────────────────────────────────────────
    display_payload = {k: v for k, v in payload.items() if k != "event"}
    print(f"\n{BOLD}{CYAN}╔══ XEV 9S Data Injector ═══════════════════════╗{RESET}")
    print(f"{CYAN}  Event  : {BOLD}{args.event}{RESET}")
    print(f"{CYAN}  Fields : {json.dumps(display_payload)}{RESET}")
    print()

    errors = []

    # ── REST server (4010) ───────────────────────────────────────────────────
    if not args.ws_only:
        try:
            rest_payload = {k: v for k, v in payload.items() if k != "event"}
            result = post(REST_CONTROL, rest_payload)
            print(f"{GREEN}✔ REST (4010){RESET} state updated")
            print_state("REST state now:", result.get("state", {}))
        except urllib.error.URLError as e:
            msg = f"{RED}✘ REST (4010){RESET} — unreachable: {e.reason}  (is mock_server.py running?)"
            print(msg); errors.append(msg)
        except Exception as e:
            msg = f"{RED}✘ REST (4010){RESET} — error: {e}"
            print(msg); errors.append(msg)

    print()

    # ── WS control server (4012 → 4011) ─────────────────────────────────────
    if not args.rest_only:
        try:
            result = post(WS_CONTROL, payload)
            print(f"{GREEN}✔ WebSocket (4012→4011){RESET} broadcast sent")
            print_state("WS state now:", result.get("state", {}))
        except urllib.error.URLError as e:
            msg = f"{RED}✘ WebSocket (4012){RESET} — unreachable: {e.reason}  (is mock_ws_server.py running?)"
            print(msg); errors.append(msg)
        except Exception as e:
            msg = f"{RED}✘ WebSocket (4012){RESET} — error: {e}"
            print(msg); errors.append(msg)

    print()
    if errors:
        print(f"{YELLOW}⚠  Some servers unreachable. Restart mock servers and try again.{RESET}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}{BOLD}✔ Done — check your app!{RESET}\n")


if __name__ == "__main__":
    main()
