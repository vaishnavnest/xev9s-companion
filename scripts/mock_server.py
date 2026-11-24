"""
Lightweight mock server for XEV 9S Companion Platform API.
Runs with Python standard library (no dependencies required).
Supports CORS and conforms to the OpenAPI envelope schema.

POST /control  — update live state without restarting:
  {"battery": 15.0, "vehicleState": "DRIVING", "speedKmh": 90.0,
   "chargingState": "CHARGING", "powerKw": 48.5, "isOnline": false}
"""

import json
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import sys
import threading
import time
import urllib.request
from datetime import datetime, timezone

PORT = 4010

# ── Shared mutable state (updated via POST /control) ─────────────────────────
_state_lock = threading.Lock()

vehicle_states = {
    "veh_mock_9s_01": {
        "vehicleId":            "veh_mock_9s_01",
        "name":                 "My XEV 9S",
        "model":                "XEV 9S AWD Performance",
        "vehicleState":         "PARKED",
        "isOnline":             True,
        "batteryPercent":       64.0,
        "speedKmh":             0.0,
        "odometerKm":           12874.3,
        "lockState":            "LOCKED",
        "preconditioningState": "INACTIVE",
        "chargingState":        "CONNECTED",
        "powerKw":              0.0,
        "targetPercent":        80,
        "sessionDurationSeconds": None,
        "currentSessionId":      None,
        "schedule": {
            "enabled": True,
            "startTime": "22:00",
            "endTime": "06:00",
            "daysOfWeek": ["MON", "TUE", "WED", "THU", "FRI"],
        },
        "location": {
            "latitude": 12.9716,
            "longitude": 77.5946,
            "description": "MG Road, Bengaluru",
        },
    },
    "veh_mock_9s_02": {
        "vehicleId":            "veh_mock_9s_02",
        "name":                 "Asha's City Cruiser",
        "model":                "XEV 9S Long Range RWD",
        "vehicleState":         "CHARGING",
        "isOnline":             True,
        "batteryPercent":       42.0,
        "speedKmh":             0.0,
        "odometerKm":           5420.8,
        "lockState":            "LOCKED",
        "preconditioningState": "ACTIVE",
        "chargingState":        "CHARGING",
        "powerKw":              48.5,
        "targetPercent":        90,
        "sessionDurationSeconds": 1800,
        "currentSessionId":      "chs_mock_003",
        "schedule": {
            "enabled": False,
            "startTime": "00:00",
            "endTime": "06:00",
            "daysOfWeek": ["SAT", "SUN"],
        },
        "location": {
            "latitude": 12.9352,
            "longitude": 77.6245,
            "description": "Koramangala 4th Block, Bengaluru",
        },
    },
}

state = vehicle_states["veh_mock_9s_01"]

def _sync_to_ws_server(payload: dict):
    """Notify mock WebSocket servers (port 4012 for python, port 4011 for node) of state changes."""
    data = json.dumps(payload).encode("utf-8")
    for port in (4012, 4011):
        try:
            req = urllib.request.Request(
                f"http://127.0.0.1:{port}/control",
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=0.8) as _:
                pass
        except Exception:
            pass

def _get_vehicle_state(vehicle_id: str) -> dict:
    if vehicle_id in vehicle_states:
        return vehicle_states[vehicle_id]
    return vehicle_states["veh_mock_9s_01"]

def _extract_vehicle_id(path: str) -> str:
    if '/vehicles/' in path:
        parts = path.split('/vehicles/')[1].split('/')
        if parts and parts[0]:
            return parts[0]
    return 'veh_mock_9s_01'

charging_sessions = [
    {
        "sessionId": "chs_mock_001",
        "vehicleId": "veh_mock_9s_01",
        "startedAt": "2026-11-23T08:00:00Z",
        "endedAt": "2026-11-23T09:30:00Z",
        "durationSeconds": 5400,
        "startBatteryPercent": 30.0,
        "endBatteryPercent": 80.0,
        "targetPercent": 80,
        "avgPowerKw": 11.2,
        "maxPowerKw": 11.4,
        "status": "COMPLETED",
        "interruptionReason": None
    },
    {
        "sessionId": "chs_mock_002",
        "vehicleId": "veh_mock_9s_01",
        "startedAt": "2026-11-22T14:00:00Z",
        "endedAt": "2026-11-22T14:25:00Z",
        "durationSeconds": 1500,
        "startBatteryPercent": 45.0,
        "endBatteryPercent": 55.0,
        "targetPercent": 90,
        "avgPowerKw": 9.5,
        "maxPowerKw": 11.0,
        "status": "INTERRUPTED",
        "interruptionReason": "Connector unlatched during charge"
    },
    {
        "sessionId": "chs_mock_003",
        "vehicleId": "veh_mock_9s_02",
        "startedAt": "2026-11-23T10:30:00Z",
        "endedAt": None,
        "durationSeconds": 1800,
        "startBatteryPercent": 18.0,
        "endBatteryPercent": 42.0,
        "targetPercent": 90,
        "avgPowerKw": 48.0,
        "maxPowerKw": 50.2,
        "status": "CHARGING",
        "interruptionReason": None
    },
    {
        "sessionId": "chs_mock_004",
        "vehicleId": "veh_mock_9s_02",
        "startedAt": "2026-11-21T18:00:00Z",
        "endedAt": "2026-11-21T19:15:00Z",
        "durationSeconds": 4500,
        "startBatteryPercent": 25.0,
        "endBatteryPercent": 85.0,
        "targetPercent": 85,
        "avgPowerKw": 22.4,
        "maxPowerKw": 24.0,
        "status": "COMPLETED",
        "interruptionReason": None
    }
]

DEFAULT_TOKEN = "mock_jwt_access_token_123456789"
# Map of token -> list of associated vehicles
# Default demo user token has 2 pre-associated vehicles with distinct data.
# Newly registered users start with an empty vehicle list.
user_vehicles = {
    DEFAULT_TOKEN: [
        {
            "vehicleId": "veh_mock_9s_01",
            "name": "My XEV 9S",
            "model": "XEV 9S AWD Performance",
            "identifier": "VIN9S2026MOCK01",
            "associationStatus": "ASSOCIATED",
            "connectivity": "ONLINE",
        },
        {
            "vehicleId": "veh_mock_9s_02",
            "name": "Asha's City Cruiser",
            "model": "XEV 9S Long Range RWD",
            "identifier": "VIN9S2026MOCK02",
            "associationStatus": "ASSOCIATED",
            "connectivity": "ONLINE",
        },
    ]
}
user_profiles = {
    DEFAULT_TOKEN: {
        "userId": "usr_mock_001",
        "name": "Jane Doe",
        "email": "jane@example.com",
    }
}
user_passwords = {
    "jane@example.com": "password123",
}

class MockApiHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept, X-Requested-With')

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def _send_json(self, status_code, data=None, error=None, meta=None):
        if meta is None:
            meta = {"requestId": "mock_req_123", "timestamp": "2026-11-17T09:00:00Z"}
        
        response = {
            "success": error is None,
            "data": data,
            "meta": meta,
            "error": error
        }
        
        body = json.dumps(response).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _get_auth_token(self):
        auth = self.headers.get('Authorization', '')
        if auth.startswith('Bearer '):
            return auth[7:].strip()
        return auth.strip()

    def _read_body_json(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            raw = self.rfile.read(content_length).decode('utf-8')
            try:
                return json.loads(raw)
            except Exception:
                return {}
        return {}

    def do_GET(self):
        path = self.path.split('?')[0]
        token = self._get_auth_token()

        if path in ('/users/me', '/api/v1/users/me'):
            profile = user_profiles.get(token, user_profiles.get(DEFAULT_TOKEN))
            self._send_json(200, data={
                "userId": profile["userId"],
                "name": profile["name"],
                "email": profile["email"],
                "createdAt": "2026-01-01T00:00:00Z"
            })
        elif path in ('/vehicles', '/api/v1/vehicles'):
            with _state_lock:
                if token and token in user_vehicles:
                    veh_list = [dict(v) for v in user_vehicles[token]]
                elif not token:
                    veh_list = [dict(v) for v in user_vehicles.get(DEFAULT_TOKEN, [])]
                else:
                    veh_list = []

                for v in veh_list:
                    s = _get_vehicle_state(v.get("vehicleId"))
                    v["connectivity"] = "ONLINE" if s["isOnline"] else "OFFLINE"
            self._send_json(200, data=veh_list)
        elif '/status' in path:
            vehicle_id = _extract_vehicle_id(path)
            with _state_lock:
                s = dict(_get_vehicle_state(vehicle_id))
            battery_pct = s["batteryPercent"]
            self._send_json(200, data={
                "vehicleId": vehicle_id,
                "name": s["name"],
                "model": s["model"],
                "vehicleState": s["vehicleState"],
                "connectivity": "ONLINE" if s["isOnline"] else "OFFLINE",
                "battery": {
                    "percent": battery_pct,
                    "level": "WARNING" if battery_pct <= 20 else "NORMAL",
                },
                "range": {
                    "estimatedKm": round(battery_pct * 4.8, 1),
                },
                "odometerKm": s["odometerKm"],
                "speedKmh": s["speedKmh"],
                "lockState": s["lockState"],
                "preconditioningState": s["preconditioningState"],
                "charging": {
                    "state": s["chargingState"],
                    "powerKw": s["powerKw"],
                },
                "lastUpdatedAt": datetime.now(timezone.utc).isoformat(),
                "isStale": not s["isOnline"],
            })
        elif '/charging/sessions/' in path:
            session_id = path.split('/charging/sessions/')[1].split('?')[0]
            with _state_lock:
                for sess in charging_sessions:
                    if sess["sessionId"] == session_id:
                        self._send_json(200, data=sess)
                        return
            self._send_json(404, error={"code": "NOT_FOUND", "message": "Session not found", "retryable": False})
            return
        elif '/charging/sessions' in path:
            vehicle_id = _extract_vehicle_id(path)
            with _state_lock:
                items = [sess for sess in charging_sessions if sess.get("vehicleId") == vehicle_id]
                if not items and vehicle_id == "veh_mock_9s_01":
                    items = list(charging_sessions)
            self._send_json(200, data={
                "items": items,
                "page": 1,
                "pageSize": 20,
                "total": len(items),
                "totalPages": 1
            })
            return
        elif '/charging' in path:
            vehicle_id = _extract_vehicle_id(path)
            with _state_lock:
                s = dict(_get_vehicle_state(vehicle_id))
            self._send_json(200, data={
                "state": s["chargingState"],
                "batteryPercent": s["batteryPercent"],
                "targetPercent": s.get("targetPercent", 80),
                "powerKw": s["powerKw"],
                "sessionDurationSeconds": s.get("sessionDurationSeconds"),
                "schedule": s.get("schedule"),
                "currentSessionId": s.get("currentSessionId")
            })
            return
        elif '/location' in path:
            vehicle_id = _extract_vehicle_id(path)
            with _state_lock:
                s = dict(_get_vehicle_state(vehicle_id))
            is_online = s.get("isOnline", True)
            loc = s.get("location", {"latitude": 12.9716, "longitude": 77.5946, "description": "MG Road, Bengaluru"})
            self._send_json(200, data={
                "vehicleId": vehicle_id,
                "latitude": loc["latitude"],
                "longitude": loc["longitude"],
                "description": loc["description"],
                "vehicleState": s.get("vehicleState", "PARKED") if is_online else "OFFLINE",
                "reportedAt": datetime.now(timezone.utc).isoformat(),
                "isCurrent": is_online,
            })
        elif path in ('/control/state', '/api/v1/control/state'):
            # Read-only view of current mock state
            with _state_lock:
                self._send_json(200, data=dict(vehicle_states))
        else:
            self._send_json(200, data={})

    def do_POST(self):
        path = self.path.split('?')[0]
        body = self._read_body_json()

        # ── Control endpoint: update live mock state ──────────────────────────
        if path in ('/control', '/api/v1/control'):
            vid = body.get('vehicleId', 'veh_mock_9s_01')
            with _state_lock:
                target_state = _get_vehicle_state(vid)
                if 'battery' in body:
                    target_state['batteryPercent'] = float(body['battery'])
                if 'vehicleState' in body:
                    target_state['vehicleState'] = body['vehicleState']
                    if target_state['vehicleState'] == 'PARKED':
                        target_state['speedKmh'] = 0.0
                    elif target_state['vehicleState'] == 'DRIVING':
                        if target_state.get('speedKmh', 0.0) == 0.0:
                            target_state['speedKmh'] = 42.0
                        if 'chargingState' not in body:
                            target_state['chargingState'] = 'NOT_CONNECTED'
                            target_state['powerKw'] = None
                            target_state['sessionDurationSeconds'] = None
                            target_state['currentSessionId'] = None
                if 'speedKmh' in body:
                    target_state['speedKmh'] = float(body['speedKmh'])
                    if 'vehicleState' not in body:
                        target_state['vehicleState'] = 'DRIVING' if target_state['speedKmh'] > 0 else 'PARKED'
                    if target_state['speedKmh'] > 0 and 'chargingState' not in body:
                        target_state['chargingState'] = 'NOT_CONNECTED'
                        target_state['powerKw'] = None
                        target_state['sessionDurationSeconds'] = None
                        target_state['currentSessionId'] = None
                if 'isOnline' in body:
                    target_state['isOnline'] = bool(body['isOnline'])
                if 'lockState' in body:
                    target_state['lockState'] = body['lockState']
                if 'preconditioningState' in body:
                    target_state['preconditioningState'] = body['preconditioningState']
                if 'chargingState' in body:
                    target_state['chargingState'] = body['chargingState']
                if 'powerKw' in body:
                    target_state['powerKw'] = body['powerKw']
                if 'odometerKm' in body:
                    target_state['odometerKm'] = float(body['odometerKm'])
                current = dict(target_state)
            print(f"[MockServer] /control → state updated: {current}")
            sys.stdout.flush()
            _sync_to_ws_server(dict(body))
            self._send_json(200, data={"message": "State updated", "state": current})
            return
        # ─────────────────────────────────────────────────────────────────────

        token = self._get_auth_token()

        if path in ('/auth/register', '/api/v1/auth/register'):
            name = body.get('name', 'Jane Doe')
            email = body.get('email', 'jane@example.com')
            password = body.get('password', '')
            user_id = f"usr_{abs(hash(email)) % 1000000:06d}"
            user_token = f"mock_jwt_token_{abs(hash(email)) % 1000000:06d}"

            with _state_lock:
                user_profiles[user_token] = {
                    "userId": user_id,
                    "name": name,
                    "email": email,
                }
                user_passwords[email] = password
                # A brand new user starts with 0 vehicles!
                user_vehicles[user_token] = []

            self._send_json(201, data={
                "accessToken": user_token,
                "refreshToken": f"mock_refresh_{user_token}",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "user": {
                    "userId": user_id,
                    "name": name,
                    "email": email
                }
            })
        elif path in ('/auth/login', '/api/v1/auth/login'):
            identifier = body.get('identifier', '').strip()
            password = body.get('password', '')

            # Validate credentials
            with _state_lock:
                expected_password = user_passwords.get(identifier)

            # If user does not exist or password does not match -> 401 INVALID_CREDENTIALS
            if expected_password is None or expected_password != password:
                self._send_json(401, error={
                    "code": "INVALID_CREDENTIALS",
                    "message": "Incorrect email or password.",
                    "details": None,
                    "retryable": True
                })
                return

            # Find matching token or generate one
            matched_token = None
            for tok, prof in user_profiles.items():
                if prof.get("email") == identifier:
                    matched_token = tok
                    break
            if not matched_token:
                matched_token = DEFAULT_TOKEN

            profile = user_profiles.get(matched_token, user_profiles[DEFAULT_TOKEN])
            self._send_json(200, data={
                "accessToken": matched_token,
                "refreshToken": f"mock_refresh_{matched_token}",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "user": {
                    "userId": profile["userId"],
                    "name": profile["name"],
                    "email": profile["email"]
                }
            })
        elif path in ('/auth/refresh', '/api/v1/auth/refresh'):
            self._send_json(200, data={
                "accessToken": "mock_refreshed_access_token_987654321",
                "refreshToken": "mock_jwt_refresh_token_123456789",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "user": {
                    "userId": "usr_mock_001",
                    "name": "Jane Doe",
                    "email": "jane@example.com"
                }
            })
        elif path in ('/auth/logout', '/api/v1/auth/logout'):
            self._send_json(200, data={"message": "Logged out successfully"})
        elif path in ('/vehicles', '/api/v1/vehicles'):
            target_token = token if token and token in user_vehicles else DEFAULT_TOKEN
            with _state_lock:
                if target_token not in user_vehicles:
                    user_vehicles[target_token] = []

                new_veh = {
                    "vehicleId": f"veh_mock_{int(datetime.now().timestamp())}",
                    "name": body.get("name") or "My XEV 9S",
                    "model": "XEV 9S",
                    "identifier": body.get("vehicleIdentifier", "VIN9S2026MOCK01"),
                    "associationStatus": "ASSOCIATED",
                    "connectivity": "ONLINE" if state["isOnline"] else "OFFLINE"
                }
                user_vehicles[target_token].append(new_veh)
                current_list = [dict(v) for v in user_vehicles[target_token]]

            self._send_json(201, data=current_list)
        else:
            self._send_json(200, data={})

    def do_PUT(self):
        path = self.path.split('?')[0]
        body = self._read_body_json()
        vehicle_id = _extract_vehicle_id(path)
        if '/charging/target' in path:
            target = body.get('targetPercent')
            with _state_lock:
                s = _get_vehicle_state(vehicle_id)
                s['targetPercent'] = target
                snap = dict(s)
            _sync_to_ws_server({"vehicleId": vehicle_id, "targetPercent": target})
            self._send_json(200, data={
                "state": snap["chargingState"],
                "batteryPercent": snap["batteryPercent"],
                "targetPercent": snap.get("targetPercent", 80),
                "powerKw": snap["powerKw"],
                "sessionDurationSeconds": snap.get("sessionDurationSeconds"),
                "schedule": snap.get("schedule"),
                "currentSessionId": snap.get("currentSessionId")
            })
        elif '/charging/schedule' in path:
            with _state_lock:
                s = _get_vehicle_state(vehicle_id)
                s['schedule'] = {
                    "enabled": body.get("enabled", True),
                    "startTime": body.get("startTime", "22:00"),
                    "endTime": body.get("endTime", "06:00"),
                    "daysOfWeek": body.get("daysOfWeek", ["MON", "TUE", "WED", "THU", "FRI"])
                }
                snap = dict(s)
            _sync_to_ws_server({"vehicleId": vehicle_id, "schedule": snap['schedule']})
            self._send_json(200, data={
                "state": snap["chargingState"],
                "batteryPercent": snap["batteryPercent"],
                "targetPercent": snap.get("targetPercent", 80),
                "powerKw": snap["powerKw"],
                "sessionDurationSeconds": snap.get("sessionDurationSeconds"),
                "schedule": snap.get("schedule"),
                "currentSessionId": snap.get("currentSessionId")
            })
        else:
            self._send_json(200, data={})

    def do_DELETE(self):
        path = self.path.split('?')[0]
        vehicle_id = _extract_vehicle_id(path)
        if '/charging/schedule' in path:
            with _state_lock:
                s = _get_vehicle_state(vehicle_id)
                s['schedule'] = None
                snap = dict(s)
            _sync_to_ws_server({"vehicleId": vehicle_id, "schedule": None})
            self._send_json(200, data={
                "state": snap["chargingState"],
                "batteryPercent": snap["batteryPercent"],
                "targetPercent": snap.get("targetPercent", 80),
                "powerKw": snap["powerKw"],
                "sessionDurationSeconds": snap.get("sessionDurationSeconds"),
                "schedule": None,
                "currentSessionId": snap.get("currentSessionId")
            })
        else:
            self._send_json(200, data={})

    def log_message(self, format, *args):
        sys.stdout.write(f"[MockServer] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

if __name__ == '__main__':
    def _bg_ticker():
        while True:
            time.sleep(3)
            with _state_lock:
                for vid, v_state in vehicle_states.items():
                    if not v_state.get("isOnline", True):
                        continue
                    if v_state.get("vehicleState") == "DRIVING":
                        new_battery = round(v_state["batteryPercent"] - 0.1, 1)
                        if new_battery <= 0.0:
                            v_state["batteryPercent"] = 0.0
                            v_state["speedKmh"] = 0.0
                            v_state["vehicleState"] = "OFFLINE"
                            v_state["isOnline"] = False
                        else:
                            v_state["batteryPercent"] = new_battery
                    elif v_state.get("chargingState") == "CHARGING" or v_state.get("vehicleState") == "CHARGING":
                        target = float(v_state.get("targetPercent") or 80)
                        current_bat = float(v_state.get("batteryPercent", 50.0))
                        if current_bat < target:
                            v_state["batteryPercent"] = round(min(target, current_bat + 0.2), 1)
                            if v_state.get("sessionDurationSeconds") is not None:
                                v_state["sessionDurationSeconds"] += 3
                            else:
                                v_state["sessionDurationSeconds"] = 3
                        elif current_bat >= target:
                            v_state["chargingState"] = "COMPLETED"
                            if v_state.get("vehicleState") == "CHARGING":
                                v_state["vehicleState"] = "PARKED"
                            v_state["powerKw"] = 0.0

    ticker_thread = threading.Thread(target=_bg_ticker, daemon=True)
    ticker_thread.start()

    server = ThreadingHTTPServer(('0.0.0.0', PORT), MockApiHandler)
    print(f"XEV 9S Mock Server running on http://127.0.0.1:{PORT} (and 0.0.0.0:{PORT})")
    print("Press Ctrl+C to stop.")
    sys.stdout.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Mock Server...")
        server.server_close()
