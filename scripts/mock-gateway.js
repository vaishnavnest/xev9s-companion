/**
 * Development Mock Gateway for XEV 9S Companion Platform (UC-06 Trips).
 *
 * Serves rich trip fixtures (25 completed trips across multiple days, 1 ongoing trip,
 * 1 trip with an empty route, 1 trip with null energy & null end location) with
 * pagination, status filtering, and UTC date-range filtering on port 4012.
 *
 * All other requests are transparently forwarded to Prism (localhost:4010) with CORS enabled.
 *
 * Usage:
 *   node scripts/mock-gateway.js
 *   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4012
 */

const http = require('http');
const url = require('url');

const GATEWAY_PORT = Number(process.env.PORT || 4012);
const PRISM_HOST = process.env.PRISM_HOST || '127.0.0.1';
const PRISM_PORT = Number(process.env.PRISM_PORT || 4010);

const SAMPLE_ROUTE = [
  { latitude: 12.9716, longitude: 77.5946, timestamp: '2026-11-24T09:00:00.000Z', speed_kmh: 18.0 },
  { latitude: 12.9724, longitude: 77.5958, timestamp: '2026-11-24T09:05:00.000Z', speed_kmh: 34.5 },
  { latitude: 12.9735, longitude: 77.5975, timestamp: '2026-11-24T09:12:00.000Z', speed_kmh: 46.2 },
  { latitude: 12.9748, longitude: 77.5992, timestamp: '2026-11-24T09:20:00.000Z', speed_kmh: 38.0 },
  { latitude: 12.9759, longitude: 77.6010, timestamp: '2026-11-24T09:28:00.000Z', speed_kmh: 24.4 },
  { latitude: 12.9772, longitude: 77.6032, timestamp: '2026-11-24T09:34:00.000Z', speed_kmh: 0.0 },
];

function buildFixtures() {
  const now = new Date();
  const trips = [];

  // 1. Ongoing trip (newest)
  const ongoingStart = new Date(now.getTime() - 14 * 60 * 1000);
  trips.push({
    trip_id: 'trp_ongoing_01',
    status: 'ongoing',
    started_at: ongoingStart.toISOString(),
    ended_at: null,
    start_location: {
      latitude: 12.9716,
      longitude: 77.5946,
      description: 'MG Road, Bengaluru',
    },
    end_location: null,
    distance_km: 4.2,
    duration_seconds: null,
    energy_consumed_kwh: null,
    average_speed_kmh: null,
    battery: { start_percent: 82.0, end_percent: null },
    route: SAMPLE_ROUTE.slice(0, 4).map((p, idx) => ({
      ...p,
      timestamp: new Date(ongoingStart.getTime() + idx * 180000).toISOString(),
    })),
  });

  // 2. Completed trip with empty route (today)
  const emptyRouteStart = new Date(now.getTime() - 3 * 60 * 60 * 1000);
  const emptyRouteEnd = new Date(emptyRouteStart.getTime() + 18 * 60 * 1000);
  trips.push({
    trip_id: 'trp_empty_route',
    status: 'completed',
    started_at: emptyRouteStart.toISOString(),
    ended_at: emptyRouteEnd.toISOString(),
    start_location: {
      latitude: 12.9352,
      longitude: 77.6245,
      description: 'Koramangala 4th Block, Bengaluru',
    },
    end_location: {
      latitude: 12.9784,
      longitude: 77.6408,
      description: 'Indiranagar 100ft Road, Bengaluru',
    },
    distance_km: 6.4,
    duration_seconds: 1080,
    energy_consumed_kwh: 1.1,
    average_speed_kmh: 21.3,
    battery: { start_percent: 78.0, end_percent: 76.0 },
    route: [],
  });

  // 3. Completed trip with null energy and null end location (yesterday)
  const nullFieldsStart = new Date(now.getTime() - 28 * 60 * 60 * 1000);
  const nullFieldsEnd = new Date(nullFieldsStart.getTime() + 25 * 60 * 1000);
  trips.push({
    trip_id: 'trp_null_fields',
    status: 'completed',
    started_at: nullFieldsStart.toISOString(),
    ended_at: nullFieldsEnd.toISOString(),
    start_location: {
      latitude: 12.9716,
      longitude: 77.5946,
      description: 'Cubbon Park, Bengaluru',
    },
    end_location: null,
    distance_km: 9.8,
    duration_seconds: 1500,
    energy_consumed_kwh: null,
    average_speed_kmh: 23.5,
    battery: { start_percent: 70.0, end_percent: null },
    route: SAMPLE_ROUTE,
  });

  // 4. 25 completed trips spread across several days
  for (let i = 1; i <= 25; i++) {
    const daysAgo = Math.floor((i - 1) / 2);
    const start = new Date(now.getTime() - (daysAgo * 24 + 2 + (i % 5)) * 60 * 60 * 1000);
    const durationSec = 900 + i * 120;
    const end = new Date(start.getTime() + durationSec * 1000);
    const dist = Number((5.2 + i * 1.15).toFixed(1));
    const energy = Number((dist * 0.17).toFixed(1));
    const avgSpeed = Number(((dist / durationSec) * 3600).toFixed(1));

    trips.push({
      trip_id: `trp_${String(100 + i).padStart(4, '0')}`,
      status: 'completed',
      started_at: start.toISOString(),
      ended_at: end.toISOString(),
      start_location: {
        latitude: 12.9716,
        longitude: 77.5946,
        description: i % 2 === 0 ? 'Whitefield Main Rd, Bengaluru' : 'MG Road, Bengaluru',
      },
      end_location: {
        latitude: 12.9772,
        longitude: 77.6032,
        description: i % 2 === 0 ? 'Hebbal Flyover, Bengaluru' : 'Trinity Circle, Bengaluru',
      },
      distance_km: dist,
      duration_seconds: durationSec,
      energy_consumed_kwh: energy,
      average_speed_kmh: avgSpeed,
      battery: {
        start_percent: 80.0,
        end_percent: Number((80.0 - energy * 1.3).toFixed(1)),
      },
      route: SAMPLE_ROUTE.map((p, idx) => ({
        ...p,
        timestamp: new Date(start.getTime() + idx * Math.floor((durationSec * 1000) / SAMPLE_ROUTE.length)).toISOString(),
      })),
    });
  }

  trips.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
  return trips;
}

const FIXTURE_TRIPS = buildFixtures();

function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function sendJson(res, statusCode, data) {
  setCorsHeaders(res);
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function toTripSummary(detail) {
  const { average_speed_kmh, battery, route, ...summary } = detail;
  return summary;
}

function handleTripsRequest(req, res, parsedUrl) {
  const pathname = parsedUrl.pathname.replace(/^\/api\/v1/, '');

  const detailMatch = pathname.match(/^\/vehicles\/([^/]+)\/trips\/([^/]+)$/);
  if (detailMatch && req.method === 'GET') {
    const tripId = detailMatch[2];
    const found = FIXTURE_TRIPS.find((t) => t.trip_id === tripId);
    if (!found) {
      sendJson(res, 404, { detail: `Trip ${tripId} not found` });
      return true;
    }
    sendJson(res, 200, found);
    return true;
  }

  const listMatch = pathname.match(/^\/vehicles\/([^/]+)\/trips$/);
  if (listMatch && req.method === 'GET') {
    const q = parsedUrl.query || {};
    const page = Math.max(1, parseInt(q.page || '1', 10) || 1);
    const pageSize = Math.max(1, Math.min(100, parseInt(q.pageSize || q.page_size || '20', 10) || 20));
    const statusFilter = q.status ? String(q.status).toLowerCase() : null;
    const fromDate = q.from ? Date.parse(String(q.from)) : null;
    const toDate = q.to ? Date.parse(String(q.to)) : null;

    let filtered = FIXTURE_TRIPS;
    if (statusFilter) {
      filtered = filtered.filter((t) => t.status === statusFilter);
    }
    if (fromDate && !Number.isNaN(fromDate)) {
      filtered = filtered.filter((t) => Date.parse(t.started_at) >= fromDate);
    }
    if (toDate && !Number.isNaN(toDate)) {
      filtered = filtered.filter((t) => Date.parse(t.started_at) <= toDate);
    }

    const totalItems = filtered.length;
    const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
    const offset = (page - 1) * pageSize;
    const pageItems = filtered.slice(offset, offset + pageSize).map(toTripSummary);

    sendJson(res, 200, {
      trips: pageItems,
      pagination: {
        page,
        page_size: pageSize,
        total_items: totalItems,
        total_pages: totalPages,
      },
    });
    return true;
  }

  return false;
}

function proxyToPrism(req, res) {
  const options = {
    hostname: PRISM_HOST,
    port: PRISM_PORT,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: `${PRISM_HOST}:${PRISM_PORT}` },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    const headers = { ...proxyRes.headers };
    headers['access-control-allow-origin'] = '*';
    headers['access-control-allow-methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS';
    headers['access-control-allow-headers'] = 'Content-Type, Authorization';
    res.writeHead(proxyRes.statusCode || 502, headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    sendJson(res, 502, { detail: `Prism upstream error: ${err.message}` });
  });

  req.pipe(proxyReq, { end: true });
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res);
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url || '/', true);
  if (handleTripsRequest(req, res, parsedUrl)) {
    return;
  }

  proxyToPrism(req, res);
});

server.listen(GATEWAY_PORT, () => {
  console.log(`[MockGateway] Listening on http://localhost:${GATEWAY_PORT}`);
  console.log(`[MockGateway] Serving UC-06 Trips fixtures (${FIXTURE_TRIPS.length} trips) and proxying other routes to http://${PRISM_HOST}:${PRISM_PORT}`);
});
