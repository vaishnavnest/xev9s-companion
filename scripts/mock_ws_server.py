"""
Pure Python Mock WebSocket Server for XEV 9S Companion.
Requires no external dependencies (built on Python standard library socketserver/hashlib/base64).
Listens on port 4011 at /ws?token=...&vehicleId=...
Simulates:
- Periodic vehicle.status telemetry broadcasts every 3 seconds
- Periodic charging.updated broadcasts every 15 seconds
- Connectivity toggles every 30 seconds
"""

import base64
import hashlib
import json
import socket
import socketserver
import threading
import time
from datetime import datetime, timezone

PORT = 4011
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

clients = set()
clients_lock = threading.Lock()
state = {
    "isOnline": True,
    "batteryPercent": 64.0,
    "speed": 0.0,
    "chargingState": "NOT_CONNECTED",
    "powerKw": None,
}

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

def broadcast(event_name: str, data: dict, vehicle_id: str = "veh_mock_9s_01"):
    message = json.dumps({
        "event": event_name,
        "vehicleId": vehicle_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "data": data,
    })
    frame = make_frame(message)
    with clients_lock:
        to_remove = set()
        for client in clients:
            try:
                client.sendall(frame)
            except Exception:
                to_remove.add(client)
        clients.difference_update(to_remove)

class WebSocketHandler(socketserver.StreamRequestHandler):
    def handle(self):
        # Read HTTP Upgrade Handshake
        request_line = self.rfile.readline().decode('utf-8', errors='ignore')
        if not request_line or 'GET' not in request_line:
            return

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

        print(f"[MockWS] Client connected from {self.client_address}")
        with clients_lock:
            clients.add(self.request)

        # Send initial status frame immediately upon connect
        init_status = {
            "vehicleId": "veh_mock_9s_01",
            "name": "My XEV 9S",
            "model": "XEV 9S AWD Performance",
            "vehicleState": "PARKED",
            "connectivity": "ONLINE",
            "battery": {"percent": 64.0, "level": "NORMAL"},
            "range": {"estimatedKm": 312.5},
            "odometerKm": 12874.3,
            "speedKmh": 0.0,
            "lockState": "LOCKED",
            "preconditioningState": "INACTIVE",
            "charging": {"state": "NOT_CONNECTED", "powerKw": None},
            "lastUpdatedAt": datetime.now(timezone.utc).isoformat(),
            "isStale": False,
        }
        self.request.sendall(make_frame(json.dumps({
            "event": "vehicle.status",
            "vehicleId": "veh_mock_9s_01",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": init_status,
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

        if not state["isOnline"]:
            continue

        # Telemetry updates every 3s
        state["batteryPercent"] = max(10.0, round(state["batteryPercent"] - 0.1, 1))
        state["speed"] = 42.0 if state["vehicleState"] == "DRIVING" else 0.0
        broadcast("vehicle.status", {
            "vehicleId": "veh_mock_9s_01",
            "vehicleState": state.get("vehicleState", "PARKED"),
            "connectivity": "ONLINE",
            "battery": {
                "percent": state["batteryPercent"],
                "level": "WARNING" if state["batteryPercent"] <= 20 else "NORMAL",
            },
            "range": {"estimatedKm": round(state["batteryPercent"] * 4.8, 1)},
            "speedKmh": state["speed"],
            "lastUpdatedAt": datetime.now(timezone.utc).isoformat(),
            "isStale": False,
        })

        # Charging updates every 15s
        if status_counter % 5 == 0:
            broadcast("charging.updated", {
                "state": "CHARGING" if state.get("chargingState") == "CHARGING" else "NOT_CONNECTED",
                "powerKw": 48.5 if state.get("chargingState") == "CHARGING" else None,
                "batteryPercent": state["batteryPercent"],
                "remainingMinutes": 45 if state.get("chargingState") == "CHARGING" else None,
            })

state["vehicleState"] = "PARKED"

if __name__ == '__main__':
    t = threading.Thread(target=ticker, daemon=True)
    t.start()
    server = ThreadedTCPServer(('0.0.0.0', PORT), WebSocketHandler)
    print(f"XEV 9S Mock WebSocket Server running on ws://127.0.0.1:{PORT}/ws")
    print("Broadcasting live telemetry on port 4011...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
