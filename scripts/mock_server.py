"""
Lightweight mock server for XEV 9S Companion Platform API.
Runs with Python standard library (no dependencies required).
Supports CORS and conforms to the OpenAPI envelope schema.
"""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import sys

PORT = 4010

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
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

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

        if path in ('/users/me', '/api/v1/users/me'):
            self._send_json(200, data={
                "userId": "usr_mock_001",
                "name": "Jane Doe",
                "email": "jane@example.com",
                "createdAt": "2026-01-01T00:00:00Z"
            })
        elif path in ('/vehicles', '/api/v1/vehicles'):
            self._send_json(200, data=[
                {
                    "vehicleId": "veh_mock_9s_01",
                    "name": "My XEV 9S",
                    "model": "XEV 9S",
                    "identifier": "VIN9S2026MOCK01",
                    "associationStatus": "ASSOCIATED",
                    "connectivity": "ONLINE"
                }
            ])
        else:
            # Fallback 200 with empty map
            self._send_json(200, data={})

    def do_POST(self):
        path = self.path.split('?')[0]
        body = self._read_body_json()

        if path in ('/auth/register', '/api/v1/auth/register'):
            name = body.get('name', 'Jane Doe')
            email = body.get('email', 'jane@example.com')
            self._send_json(201, data={
                "accessToken": "mock_jwt_access_token_123456789",
                "refreshToken": "mock_jwt_refresh_token_123456789",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "user": {
                    "userId": "usr_mock_001",
                    "name": name,
                    "email": email
                }
            })
        elif path in ('/auth/login', '/api/v1/auth/login'):
            identifier = body.get('identifier', 'jane@example.com')
            self._send_json(200, data={
                "accessToken": "mock_jwt_access_token_123456789",
                "refreshToken": "mock_jwt_refresh_token_123456789",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "user": {
                    "userId": "usr_mock_001",
                    "name": "Jane Doe",
                    "email": identifier
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
            self._send_json(201, data=[
                {
                    "vehicleId": "veh_mock_9s_01",
                    "name": body.get("name") or "My XEV 9S",
                    "model": "XEV 9S",
                    "identifier": body.get("vehicleIdentifier", "VIN9S2026MOCK01"),
                    "associationStatus": "ASSOCIATED",
                    "connectivity": "ONLINE"
                }
            ])
        else:
            self._send_json(200, data={})

    def log_message(self, format, *args):
        sys.stdout.write(f"[MockServer] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), MockApiHandler)
    print(f"XEV 9S Mock Server running on http://127.0.0.1:{PORT} (and 0.0.0.0:{PORT})")
    print("Press Ctrl+C to stop.")
    sys.stdout.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Mock Server...")
        server.server_close()
