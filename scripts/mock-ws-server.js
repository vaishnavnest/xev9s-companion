/**
 * Fake WebSocket Realtime Server for XEV 9S Companion Platform.
 * Simulates push events (vehicle.status, connectivity.changed, charging.updated).
 *
 * NOTE: For local development only.
 * Run with: node scripts/mock-ws-server.js
 */

const { WebSocketServer } = require('ws');
const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 4011;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('XEV 9S Mock Realtime Server running on port ' + PORT);
});

const wss = new WebSocketServer({ noServer: true });

let batteryPercent = 64.0;
let isOffline = false;
let isCharging = false;

function broadcast(event) {
  const json = JSON.stringify(event);
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // OPEN
      client.send(json);
    }
  });
}

function sendVehicleStatus(targetVehicleId) {
  batteryPercent = +(batteryPercent + (Math.random() * 2 - 1)).toFixed(1);
  if (batteryPercent > 98) batteryPercent = 60.0;
  if (batteryPercent < 15) batteryPercent = 60.0;

  const event = {
    event: 'vehicle.status',
    vehicleId: targetVehicleId || 'veh_9S0001',
    timestamp: new Date().toISOString(),
    data: {
      vehicleId: targetVehicleId || 'veh_9S0001',
      name: 'Asha\'s XEV 9S',
      model: 'XEV 9S AWD Performance',
      vehicleState: isOffline ? 'OFFLINE' : (isCharging ? 'CHARGING' : 'PARKED'),
      connectivity: isOffline ? 'OFFLINE' : 'ONLINE',
      battery: {
        percent: batteryPercent,
        level: batteryPercent <= 20 ? 'WARNING' : 'NORMAL',
      },
      range: {
        estimatedKm: +(batteryPercent * 4.88).toFixed(1),
      },
      odometerKm: 12874.3,
      speedKmh: isOffline ? null : 0.0,
      lockState: 'LOCKED',
      preconditioningState: 'INACTIVE',
      charging: {
        state: isCharging ? 'CHARGING' : 'NOT_CONNECTED',
        powerKw: isCharging ? 11.2 : null,
      },
      lastUpdatedAt: new Date().toISOString(),
      isStale: isOffline,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted vehicle.status (battery: ${batteryPercent}%, offline: ${isOffline})`);
}

function sendConnectivity(status) {
  isOffline = status === 'OFFLINE';
  const event = {
    event: 'connectivity.changed',
    vehicleId: 'veh_9S0001',
    timestamp: new Date().toISOString(),
    data: {
      vehicleId: 'veh_9S0001',
      status: status,
      lastCommunicationAt: new Date().toISOString(),
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted connectivity.changed -> ${status}`);
}

function sendChargingUpdate() {
  const stateStr = isCharging ? 'CHARGING' : 'NOT_CONNECTED';
  const event = {
    event: 'charging.updated',
    vehicleId: 'veh_9S0001',
    timestamp: new Date().toISOString(),
    data: {
      state: stateStr,
      batteryPercent: batteryPercent,
      powerKw: isCharging ? 11.2 : null,
      targetPercent: 80,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted charging.updated -> ${stateStr}`);
}

server.on('upgrade', (request, socket, head) => {
  const parsed = url.parse(request.url, true);
  if (parsed.pathname === '/ws') {
    // Note: Do not log authentication tokens in server logs
    const hasToken = Boolean(parsed.query.token);
    const vehicleId = parsed.query.vehicleId || 'all';

    console.log(`[MockWS] Inbound client connection: hasToken=${hasToken}, vehicleId=${vehicleId}`);

    wss.handleUpgrade(request, socket, head, (ws) => {
      ws.vehicleId = parsed.query.vehicleId || 'veh_9S0001';
      wss.emit('connection', ws, request);
    });
  } else {
    socket.destroy();
  }
});

wss.on('connection', (ws) => {
  console.log(`[MockWS] Client connected successfully (vehicleId: ${ws.vehicleId})`);

  // Immediately send initial status to the client
  sendVehicleStatus(ws.vehicleId);

  ws.on('close', (code, reason) => {
    console.log(`[MockWS] Client disconnected (code: ${code})`);
  });
});

// Periodic event emitter
// Every 3 seconds emit vehicle.status
const statusInterval = setInterval(() => {
  if (wss.clients.size > 0) {
    sendVehicleStatus('veh_9S0001');
  }
}, 3000);

// Note: Automatic random charging and offline intervals have been disabled to
// prevent unexpected state flapping during development.
// Use interactive keyboard controls (o, n, c) or scripts/inject.py.

// Interactive keyboard controls in terminal
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (key) => {
    if (key === '\u0003') { // Ctrl+C
      process.exit();
    } else if (key === 'o') {
      sendConnectivity('OFFLINE');
    } else if (key === 'n') {
      sendConnectivity('ONLINE');
    } else if (key === 'c') {
      isCharging = !isCharging;
      sendChargingUpdate();
      sendVehicleStatus('veh_9S0001');
    }
  });
  console.log('Interactive controls: press "o" (offline), "n" (online), "c" (toggle charging), Ctrl+C (stop)');
}

server.listen(PORT, () => {
  console.log(`Fake WebSocket Realtime Server listening on ws://localhost:${PORT}/ws`);
  console.log(`For Android emulator: ws://10.0.2.2:${PORT}/ws`);
});
