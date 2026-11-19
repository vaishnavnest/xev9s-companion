"""
Pure Python Mock WebSocket Server for XEV 9S Companion.
Requires no external dependencies (built on Python standard library socketserver/hashlib/base64).
Listens on port 4011 at /ws?token=...&vehicleId=...
Simulates:
- Periodic vehicle.status telemetry broadcasts every 3 seconds
- Periodic charging.updated broadcasts every 15 seconds
- Connectivity toggles every 30 seconds

POST http://localhost:4012/control  — inject a custom WS broadcast:
  {"event": "vehicle.status", "battery": 15.0, "vehicleState": "DRIVING",
   "speedKmh": 90.0, "isOnline": true, "chargingState": "CHARGING", "powerKw": 48.5}
"""

import base64
import hashlib
import json
import socket
import socketserver
import threading
import time
import urllib.parse
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = 4011
CONTROL_PORT = 4012
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

clients = set()
client_subscriptions = {}  # socket -> vehicle_id string
clients_lock = threading.Lock()
state = {
    "isOnline": True,
    "batteryPercent": 64.0,
    "speed": 0.0,
    "chargingState": "NOT_CONNECTED",
    "powerKw": None,
    "vehicleState": "PARKED",
    "lockState": "LOCKED",
    "preconditioningState": "INACTIVE",
    "odometerKm": 12874.3,
    "name": "My XEV 9S",
    "model": "XEV 9S AWD Performance",
}
state_lock = threading.Lock()

def make_frame(payload_str: str) -> bytes:
    payload_bytes = payload_str.encode('utf-8')
    length = len(payload_bytes)
    if length < 126:
        header = bytes([0x81, length])
    elif length <= 65535:
        header = bytes([0x81, 126, (length >> 8) & 0xFF, length & 0xFF])
    else:
        header = bytes([0x81, 127]) + length.to_bytes(8, byteorder='big')
    return header + payload_bytes

def broadcast(event_name: str, data_or_builder, vehicle_id: str = None):
    """
    Broadcast an event to connected clients.
    If vehicle_id is provided, only clients subscribed to that vehicle_id receive it.
    If vehicle_id is None, each client receives a payload addressed to its own subscribed vehicleId.
    data_or_builder can be a dict, or a callable: fn(target_vid: str) -> dict.
    """
    with clients_lock:
        to_remove = set()
        for client in list(clients):
            client_vid = client_subscriptions.get(client, "veh_mock_9s_01")

            # If a specific vehicle_id is targeted and doesn't match this client's subscription, skip
            if vehicle_id is not None and vehicle_id != client_vid:
                continue

            target_vid = vehicle_id or client_vid

            if callable(data_or_builder):
                client_data = data_or_builder(target_vid)
            else:
                client_data = dict(data_or_builder)
                if "vehicleId" in client_data:
                    client_data["vehicleId"] = target_vid

            now_iso = datetime.now(timezone.utc).isoformat()
            message = json.dumps({
                "event": event_name,
                "vehicleId": target_vid,
                "timestamp": now_iso,
                "data": client_data,
            })
            frame = make_frame(message)
            try:
                client.sendall(frame)
            except Exception:
                to_remove.add(client)

        for dead in to_remove:
            clients.discard(dead)
            client_subscriptions.pop(dead, None)

class WebSocketHandler(socketserver.StreamRequestHandler):
    def handle(self):
        # Read HTTP Upgrade Handshake
        request_line = self.rfile.readline().decode('utf-8', errors='ignore')
        if not request_line or 'GET' not in request_line:
            return

        # Extract vehicleId from query string (?token=...&vehicleId=...)
        vehicle_id = "veh_mock_9s_01"
        try:
            req_parts = request_line.split()
            if len(req_parts) >= 2:
                req_path = req_parts[1]
                parsed = urllib.parse.urlparse(req_path)
                qs = urllib.parse.parse_qs(parsed.query)
                if 'vehicleId' in qs and qs['vehicleId'] and qs['vehicleId'][0].strip():
                    vehicle_id = qs['vehicleId'][0].strip()
        except Exception:
            pass

        headers = {}
        while True:
            line = self.rfile.readline().decode('utf-8', errors='ignore').strip()
            if not line:
                break
            if ':' in line:
                k, v = line.split(':', 1)
                headers[k.strip().lower()] = v.strip()

        key = headers.get('sec-websocket-key')
        if not key:
            self.wfile.write(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            return

        # Handshake response
        accept_val = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept_val}\r\n"
            "\r\n"
        )
        self.wfile.write(response.encode('utf-8'))
        self.wfile.flush()

        print(f"[MockWS] Client connected from {self.client_address} (subscribed to vehicleId={vehicle_id})")
        with clients_lock:
            clients.add(self.request)
            client_subscriptions[self.request] = vehicle_id

        # Send initial status frame immediately upon connect — tailored to this client's vehicleId
        with state_lock:
            s = dict(state)
        now_iso = datetime.now(timezone.utc).isoformat()
        self.request.sendall(make_frame(json.dumps({
            "event": "vehicle.status",
            "vehicleId": vehicle_id,
            "timestamp": now_iso,
            "data": _build_status_payload(s, vehicle_id=vehicle_id),
        })))

        try:
            while True:
                # Keep socket open and consume incoming frames / pings
                b1_b2 = self.rfile.read(2)
                if not b1_b2 or len(b1_b2) < 2:
                    break
                opcode = b1_b2[0] & 0x0F
                if opcode == 0x08:  # Close frame
                    break
                length = b1_b2[1] & 0x7F
                if length == 126:
                    length = int.from_bytes(self.rfile.read(2), 'big')
                elif length == 127:
                    length = int.from_bytes(self.rfile.read(8), 'big')
                # Read mask and payload
                mask = self.rfile.read(4)
                payload = self.rfile.read(length)
                if opcode == 0x09:  # Ping -> reply Pong
                    self.request.sendall(bytes([0x8A, 0x00]))
        except Exception:
            pass
        finally:
            with clients_lock:
                clients.discard(self.request)
                client_subscriptions.pop(self.request, None)
            print(f"[MockWS] Client disconnected from {self.client_address}")

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

def ticker():
    status_counter = 0
    while True:
        time.sleep(3)
        status_counter += 1
        with clients_lock:
            has_clients = len(clients) > 0

        if not has_clients:
            continue

        just_went_offline = False
        with state_lock:
            if not state["isOnline"]:
                continue
            # Only drain battery when actively driving (realistic simulation)
            if state["vehicleState"] == "DRIVING":
                new_battery = round(state["batteryPercent"] - 0.1, 1)
                if new_battery <= 0.0:
                    state["batteryPercent"] = 0.0
                    state["speed"] = 0.0
                    state["vehicleState"] = "OFFLINE"
                    state["isOnline"] = False
                    just_went_offline = True
                else:
                    state["batteryPercent"] = new_battery
                    state["speed"] = state.get("speed", 42.0) or 42.0
            else:
                state["speed"] = 0.0
            s = dict(state)

        if just_went_offline:
            print("[MockWS] Battery reached 0.0%! Vehicle shut down and is now OFFLINE.")
            broadcast("connectivity.changed", lambda vid: {
                "status": "OFFLINE",
                "lastCommunicationAt": datetime.now(timezone.utc).isoformat(),
            })

        # Full vehicle.status broadcast — sent to each client using its subscribed vehicleId
        broadcast("vehicle.status", lambda vid: _build_status_payload(s, vehicle_id=vid))

        # Charging update every 15s
        if status_counter % 5 == 0:
            with state_lock:
                s = dict(state)
            broadcast("charging.updated", lambda vid: {
                "state": s["chargingState"],
                "powerKw": s["powerKw"],
                "batteryPercent": s["batteryPercent"],
                "remainingMinutes": 45 if s["chargingState"] == "CHARGING" else None,
            })


def _build_status_payload(s: dict, vehicle_id: str = "veh_mock_9s_01") -> dict:
    """Build a full vehicle.status data payload from current state dict."""
    battery_pct = s["batteryPercent"]
    return {
        "vehicleId": vehicle_id,
        "name": s.get("name", "My XEV 9S"),
        "model": s.get("model", "XEV 9S AWD Performance"),
        "vehicleState": s["vehicleState"],
        "connectivity": "ONLINE" if s["isOnline"] else "OFFLINE",
        "battery": {
            "percent": battery_pct,
            "level": "WARNING" if battery_pct <= 20 else "NORMAL",
        },
        "range": {"estimatedKm": round(battery_pct * 4.8, 1)},
        "odometerKm": s.get("odometerKm", 12874.3),
        "speedKmh": s["speed"],
        "lockState": s.get("lockState", "LOCKED"),
        "preconditioningState": s.get("preconditioningState", "INACTIVE"),
        "charging": {
            "state": s["chargingState"],
            "powerKw": s["powerKw"],
        },
        "lastUpdatedAt": datetime.now(timezone.utc).isoformat(),
        "isStale": not s["isOnline"],
    }

state["vehicleState"] = "PARKED"

# ── HTTP Control Server on port 4012 ─────────────────────────────────────────
class ControlHandler(BaseHTTPRequestHandler):
    """Accepts POST /control to update state and trigger an immediate broadcast."""

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        # GET /control/state → read current state
        with state_lock:
            body = json.dumps({"state": dict(state)}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(length)) if length else {}

        event = payload.get("event", "vehicle.status")
        target_vid = payload.get("vehicleId")

        with state_lock:
            if "battery"              in payload: state["batteryPercent"]      = float(payload["battery"])
            if "speedKmh"             in payload:
                state["speed"] = float(payload["speedKmh"])
                if "vehicleState" not in payload:
                    if state["speed"] > 0:
                        state["vehicleState"] = "DRIVING"
                    elif state["vehicleState"] == "DRIVING":
                        state["vehicleState"] = "PARKED"
            if "isOnline"             in payload: state["isOnline"]            = bool(payload["isOnline"])
            if "vehicleState"         in payload: state["vehicleState"]        = payload["vehicleState"]
            if "chargingState"        in payload: state["chargingState"]       = payload["chargingState"]
            if "powerKw"              in payload: state["powerKw"]             = payload["powerKw"]
            if "lockState"            in payload: state["lockState"]           = payload["lockState"]
            if "preconditioningState" in payload: state["preconditioningState"]= payload["preconditioningState"]
            if "odometerKm"           in payload: state["odometerKm"]          = float(payload["odometerKm"])

            # Harmonize charging state & vehicle state
            if state.get("chargingState") == "CHARGING" and "vehicleState" not in payload:
                state["vehicleState"] = "CHARGING"
            elif state.get("vehicleState") == "CHARGING" and "chargingState" not in payload:
                state["chargingState"] = "CHARGING"

            s = dict(state)

        # Build and broadcast the right event immediately
        if event == "connectivity.changed":
            broadcast("connectivity.changed", lambda vid: {
                "status": "ONLINE" if s["isOnline"] else "OFFLINE",
                "lastCommunicationAt": datetime.now(timezone.utc).isoformat(),
            }, vehicle_id=target_vid)
            # Also send a full vehicle.status so the app updates all telemetry fields
            broadcast("vehicle.status", lambda vid: _build_status_payload(s, vehicle_id=vid), vehicle_id=target_vid)
        elif event == "charging.updated":
            broadcast("charging.updated", lambda vid: {
                "state": s["chargingState"],
                "powerKw": s["powerKw"],
                "batteryPercent": s["batteryPercent"],
                "remainingMinutes": payload.get("remainingMinutes", 45) if s["chargingState"] == "CHARGING" else None,
            }, vehicle_id=target_vid)
        else:  # default: vehicle.status — full payload with all telemetry fields
            broadcast("vehicle.status", lambda vid: _build_status_payload(s, vehicle_id=vid), vehicle_id=target_vid)

        print(f"[ControlServer] Broadcast '{event}' (target_vid={target_vid}) → state: {s}")
        import sys; sys.stdout.flush()

        resp = json.dumps({"ok": True, "event": event, "state": s}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self._cors()
        self.end_headers()
        self.wfile.write(resp)

    def log_message(self, fmt, *args):
        pass  # silence access logs


if __name__ == '__main__':
    t = threading.Thread(target=ticker, daemon=True)
    t.start()

    # Start HTTP control server on port 4012
    control_server = ThreadingHTTPServer(('0.0.0.0', CONTROL_PORT), ControlHandler)
    ct = threading.Thread(target=control_server.serve_forever, daemon=True)
    ct.start()
    print(f"XEV 9S Mock WebSocket Server  → ws://127.0.0.1:{PORT}/ws")
    print(f"XEV 9S Mock Control Endpoint  → http://127.0.0.1:{CONTROL_PORT}/control")
    print("Broadcasting live telemetry on port 4011...")

    ws_server = ThreadedTCPServer(('0.0.0.0', PORT), WebSocketHandler)
    try:
        ws_server.serve_forever()
    except KeyboardInterrupt:
        ws_server.server_close()
        control_server.server_close()
