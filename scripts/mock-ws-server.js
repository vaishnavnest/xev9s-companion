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
  if (req.method === 'POST' && (req.url === '/control' || req.url === '/api/v1/control')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        const vid = payload.vehicleId || 'veh_mock_9s_01';
        if (payload.targetPercent !== undefined) {
          if (vid === 'veh_mock_9s_02') {
            secondCarTargetPercent = Number(payload.targetPercent);
          } else {
            chargingTargetPercent = Number(payload.targetPercent);
          }
        }
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ success: true }));
        sendChargingUpdate(vid);
        return;
      } catch (e) {
        res.writeHead(400);
        res.end();
        return;
      }
    });
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('XEV 9S Mock Realtime Server running on port ' + PORT);
});

const wss = new WebSocketServer({ noServer: true });

let batteryPercent = 64.0;
let secondCarBattery = 42.0;
let secondCarTargetPercent = 90;
let isOffline = false;
let isCharging = false;
let isDriving = false;

// Charging simulation state
let chargingState = 'NOT_CONNECTED';
let chargingPowerKw = null;
let chargingTargetPercent = 80;
let chargingSessionDuration = null;
let chargingSessionId = null;
let interruptionReason = null;
let chargingSimulationInterval = null;

function getVehicleState() {
  if (isOffline) return 'OFFLINE';
  if (chargingState === 'CHARGING') return 'CHARGING';
  if (isDriving) return 'DRIVING';
  return 'PARKED';
}

// Small test route near MG Road, Bengaluru for live location simulation
const ROUTE_WAYPOINTS = [
  { lat: 12.9716, lng: 77.5946, desc: 'MG Road, Bengaluru' },
  { lat: 12.9724, lng: 77.5958, desc: 'Brigade Road Junction, Bengaluru' },
  { lat: 12.9735, lng: 77.5975, desc: 'Residency Road, Bengaluru' },
  { lat: 12.9748, lng: 77.5992, desc: 'Mayo Hall, MG Road, Bengaluru' },
  { lat: 12.9759, lng: 77.6010, desc: 'Trinity Circle, Bengaluru' },
  { lat: 12.9742, lng: 77.5985, desc: 'Webbs Ground, Bengaluru' },
  { lat: 12.9729, lng: 77.5962, desc: 'Church Street, Bengaluru' },
];
let routeIndex = 0;
let lastKnownLocation = {
  latitude: 12.9716,
  longitude: 77.5946,
  description: 'MG Road, Bengaluru',
};

function broadcast(event) {
  const json = JSON.stringify(event);
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // OPEN
      client.send(json);
    }
  });
}

function sendVehicleStatus(targetVehicleId) {
  const vid = targetVehicleId || 'veh_mock_9s_01';
  const isSecondCar = vid === 'veh_mock_9s_02';

  if (isSecondCar) {
    if (secondCarBattery < 90.0) {
      secondCarBattery = +(secondCarBattery + 0.2).toFixed(1);
    }
  } else {
    if (isDriving) {
      batteryPercent = +(Math.max(0.0, batteryPercent - 0.1)).toFixed(1);
    } else if (chargingState === 'CHARGING') {
      batteryPercent = +(Math.min(chargingTargetPercent, batteryPercent + 0.2)).toFixed(1);
    }
  }
  let currentBattery = isSecondCar ? secondCarBattery : batteryPercent;

  const event = {
    event: 'vehicle.status',
    vehicleId: vid,
    timestamp: new Date().toISOString(),
    data: {
      vehicleId: vid,
      name: isSecondCar ? "Asha's City Cruiser" : "My XEV 9S",
      model: isSecondCar ? "XEV 9S Long Range RWD" : "XEV 9S AWD Performance",
      vehicleState: isSecondCar ? 'CHARGING' : getVehicleState(),
      connectivity: isOffline ? 'OFFLINE' : 'ONLINE',
      battery: {
        percent: currentBattery,
        level: currentBattery <= 20 ? 'WARNING' : 'NORMAL',
      },
      range: {
        estimatedKm: +(currentBattery * 4.8).toFixed(1),
      },
      odometerKm: isSecondCar ? 5420.8 : 12874.3,
      speedKmh: isOffline ? null : (isSecondCar ? 0.0 : (isDriving ? 42.0 : 0.0)),
      lockState: 'LOCKED',
      preconditioningState: isSecondCar ? 'ACTIVE' : 'INACTIVE',
      charging: {
        state: isSecondCar ? 'CHARGING' : chargingState,
        powerKw: isSecondCar ? 48.5 : chargingPowerKw,
      },
      lastUpdatedAt: new Date().toISOString(),
      isStale: isOffline,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted vehicle.status for ${vid} (battery: ${currentBattery}%, state: ${event.data.vehicleState})`);
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

  // Emit vehicle.location reflecting the new online/offline state
  sendVehicleLocation('veh_9S0001');
}

function sendVehicleLocation(targetVehicleId, options = {}) {
  const vehicleId = targetVehicleId || 'veh_9S0001';

  if (options.nullLocation) {
    const event = {
      event: 'vehicle.location',
      vehicleId: vehicleId,
      timestamp: new Date().toISOString(),
      data: {
        vehicleId: vehicleId,
        latitude: null,
        longitude: null,
        description: null,
        vehicleState: isOffline ? 'OFFLINE' : (isCharging ? 'CHARGING' : 'PARKED'),
        reportedAt: new Date().toISOString(),
        isCurrent: !isOffline,
      },
    };
    broadcast(event);
    console.log(`[MockWS] Broadcasted vehicle.location -> null coordinates (unavailable state)`);
    return;
  }

  if (!isOffline && isDriving) {
    const pt = ROUTE_WAYPOINTS[routeIndex];
    routeIndex = (routeIndex + 1) % ROUTE_WAYPOINTS.length;
    lastKnownLocation = {
      latitude: pt.lat,
      longitude: pt.lng,
      description: pt.desc,
    };
  }

  const isCurrent = !isOffline;
  const vehicleState = getVehicleState();

  const event = {
    event: 'vehicle.location',
    vehicleId: vehicleId,
    timestamp: new Date().toISOString(),
    data: {
      vehicleId: vehicleId,
      latitude: lastKnownLocation.latitude,
      longitude: lastKnownLocation.longitude,
      description: lastKnownLocation.description,
      vehicleState: vehicleState,
      reportedAt: new Date().toISOString(),
      isCurrent: isCurrent,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted vehicle.location -> (${lastKnownLocation.latitude}, ${lastKnownLocation.longitude}) isCurrent=${isCurrent} state=${vehicleState}`);
}

function sendChargingUpdate(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_mock_9s_01';
  const isSecondCar = vehicleId === 'veh_mock_9s_02';

  const event = {
    event: 'charging.updated',
    vehicleId: vehicleId,
    timestamp: new Date().toISOString(),
    data: {
      state: isSecondCar ? 'CHARGING' : chargingState,
      batteryPercent: isSecondCar ? secondCarBattery : batteryPercent,
      targetPercent: isSecondCar ? secondCarTargetPercent : chargingTargetPercent,
      powerKw: isSecondCar ? 48.5 : chargingPowerKw,
      sessionDurationSeconds: isSecondCar ? 1800 : chargingSessionDuration,
      schedule: isSecondCar
          ? {
              enabled: false,
              startTime: '00:00',
              endTime: '06:00',
              daysOfWeek: ['SAT', 'SUN'],
            }
          : {
              enabled: true,
              startTime: '22:00',
              endTime: '06:00',
              daysOfWeek: ['MON', 'TUE', 'WED', 'THU', 'FRI'],
            },
      currentSessionId: isSecondCar ? 'chs_mock_003' : chargingSessionId,
    },
  };
  broadcast(event);
  console.log(`[MockWS] Broadcasted charging.updated for ${vehicleId} -> ${event.data.state} (battery: ${event.data.batteryPercent}%, power: ${event.data.powerKw} kW, session: ${event.data.currentSessionId})`);
}

function broadcastChargingAndStatus(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_9S0001';
  sendChargingUpdate(vehicleId);
  sendVehicleStatus(vehicleId);
}

function startChargingSimulation(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_9S0001';
  if (chargingSimulationInterval) {
    clearInterval(chargingSimulationInterval);
    chargingSimulationInterval = null;
  }

  isDriving = false;
  isOffline = false;
  chargingState = 'CONNECTED';
  chargingPowerKw = 0.0;
  chargingSessionDuration = 0;
  chargingSessionId = 'chs_' + Date.now().toString().slice(-4);
  interruptionReason = null;

  console.log(`[MockWS] Charging simulation initiated -> CONNECTED`);
  broadcastChargingAndStatus(vehicleId);

  setTimeout(() => {
    chargingState = 'CHARGING';
    chargingPowerKw = 11.2;
    console.log(`[MockWS] Charging started -> CHARGING at 11.2 kW`);
    broadcastChargingAndStatus(vehicleId);

    chargingSimulationInterval = setInterval(() => {
      chargingSessionDuration += 2;
      batteryPercent = Math.min(chargingTargetPercent, +(batteryPercent + 2.0).toFixed(1));

      if (batteryPercent >= chargingTargetPercent) {
        clearInterval(chargingSimulationInterval);
        chargingSimulationInterval = null;
        chargingState = 'COMPLETED';
        chargingPowerKw = 0.0;
        console.log(`[MockWS] Charging completed -> Target ${chargingTargetPercent}% reached.`);
      }
      broadcastChargingAndStatus(vehicleId);
    }, 2000);
  }, 1000);
}

function interruptChargingSession(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_9S0001';
  if (chargingSimulationInterval) {
    clearInterval(chargingSimulationInterval);
    chargingSimulationInterval = null;
  }
  chargingState = 'INTERRUPTED';
  chargingPowerKw = null;
  interruptionReason = 'Charging station power fault detected';
  console.log(`[MockWS] Charging interrupted -> INTERRUPTED`);
  broadcastChargingAndStatus(vehicleId);
}

function pauseChargingSession(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_9S0001';
  if (chargingSimulationInterval) {
    clearInterval(chargingSimulationInterval);
    chargingSimulationInterval = null;
  }
  chargingState = 'PAUSED';
  chargingPowerKw = 0.0;
  console.log(`[MockWS] Charging paused -> PAUSED`);
  broadcastChargingAndStatus(vehicleId);
}

function unplugVehicle(targetVehicleId) {
  const vehicleId = targetVehicleId || 'veh_9S0001';
  if (chargingSimulationInterval) {
    clearInterval(chargingSimulationInterval);
    chargingSimulationInterval = null;
  }
  chargingState = 'NOT_CONNECTED';
  chargingPowerKw = null;
  chargingSessionDuration = null;
  chargingSessionId = null;
  console.log(`[MockWS] Vehicle unplugged -> NOT_CONNECTED`);
  broadcastChargingAndStatus(vehicleId);
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

  // Immediately send initial status and location to the client
  sendVehicleStatus(ws.vehicleId);
  sendVehicleLocation(ws.vehicleId);

  ws.on('close', (code, reason) => {
    console.log(`[MockWS] Client disconnected (code: ${code})`);
  });
});

// Periodic event emitters
// Every 3 seconds emit vehicle.status
const statusInterval = setInterval(() => {
  if (wss.clients.size > 0) {
    sendVehicleStatus('veh_9S0001');
  }
}, 3000);

// Every 4 seconds emit vehicle.location for veh_9S0001
const locationInterval = setInterval(() => {
  if (wss.clients.size > 0 && !isOffline) {
    sendVehicleLocation('veh_9S0001');
  }
}, 4000);

// Note: Automatic random charging and offline intervals have been disabled to
// prevent unexpected state flapping during development.
// Use interactive keyboard controls (o, n, c, l) or scripts/inject.py.

// Interactive keyboard controls in terminal
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (key) => {
    if (key === '\u0003') { // Ctrl+C
      process.exit();
    } else if (key === 'd') {
      isDriving = !isDriving;
      if (isDriving) isCharging = false;
      sendVehicleStatus('veh_9S0001');
      sendVehicleLocation('veh_9S0001');
      console.log(`[MockWS] Toggled driving -> ${isDriving ? 'DRIVING (speed: 42 km/h, moving route)' : 'PARKED (speed: 0 km/h, stationary)'}`);
    } else if (key === 'o') {
      sendConnectivity('OFFLINE');
    } else if (key === 'n') {
      sendConnectivity('ONLINE');
    } else if (key === 'c') {
      startChargingSimulation('veh_9S0001');
    } else if (key === 'i') {
      interruptChargingSession('veh_9S0001');
    } else if (key === 'u') {
      pauseChargingSession('veh_9S0001');
    } else if (key === 'p') {
      unplugVehicle('veh_9S0001');
    } else if (key === 'l') {
      sendVehicleLocation('veh_9S0001', { nullLocation: true });
    }
  });
  console.log('Interactive controls: press "c" (simulate charging), "i" (interrupt), "u" (pause), "p" (unplug), "d" (driving), "o" (offline), "n" (online), "l" (null location), Ctrl+C (stop)');
}

server.listen(PORT, () => {
  console.log(`Fake WebSocket Realtime Server listening on ws://localhost:${PORT}/ws`);
  console.log(`For Android emulator: ws://10.0.2.2:${PORT}/ws`);
});
