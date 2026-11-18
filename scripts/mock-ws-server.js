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
      vehicleState: isOffline ? 'OFFLINE' : 'PARKED',
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
        state: 'NOT_CONNECTED',
        powerKw: null,
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
  const event = {
    event: 'charging.updated',
    vehicleId: 'veh_9S0001',
    timestamp: new Date().toISOString(),
    data: {
      state: 'CHARGING',
      batteryPercent: batteryPercent,
      powerKw: 11.2,
      targetPercent: 80,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted charging.updated`);
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

// Connectivity toggling every 20s (OFFLINE) and 10s later (ONLINE)
let onlineTimeout;
const connectivityInterval = setInterval(() => {
  if (wss.clients.size > 0) {
    sendConnectivity('OFFLINE');
    clearTimeout(onlineTimeout);
    onlineTimeout = setTimeout(() => {
      sendConnectivity('ONLINE');
    }, 10000);
  }
}, 30000);

// Occasionally emit charging.updated every 15s
const chargingInterval = setInterval(() => {
  if (wss.clients.size > 0 && !isOffline) {
    sendChargingUpdate();
  }
}, 15000);

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
      sendChargingUpdate();
    }
  });
  console.log('Interactive controls: press "o" (offline), "n" (online), "c" (charging), Ctrl+C (stop)');
}

server.listen(PORT, () => {
  console.log(`Fake WebSocket Realtime Server listening on ws://localhost:${PORT}/ws`);
  console.log(`For Android emulator: ws://10.0.2.2:${PORT}/ws`);
});
