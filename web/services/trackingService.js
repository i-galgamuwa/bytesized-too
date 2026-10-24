// Single data-access layer the routes use. It calls the ByteSized backend API and
// translates the backend's domain model into the shape the dashboard views expect.
//
// All of the mapping lives here on purpose: routes, views and public/js stay unaware
// that the backend speaks a richer vocabulary than the dashboard needs.
const backend = require('./backendClient');

// --- client address lookup -------------------------------------------------
// VisitDto carries the client's name and coordinates but not its street address,
// so addresses are resolved from GET /clients and cached briefly. Clients change
// rarely, and this keeps one extra request off every log query.
const CLIENT_CACHE_TTL_MS = 5 * 60 * 1000;
let clientCache = { at: 0, byId: new Map() };

async function clientAddresses(token) {
  if (Date.now() - clientCache.at < CLIENT_CACHE_TTL_MS && clientCache.byId.size) {
    return clientCache.byId;
  }
  try {
    const clients = (await backend.get('/clients', token)) || [];
    clientCache = { at: Date.now(), byId: new Map(clients.map((c) => [c.id, c.address])) };
  } catch {
    // A missing address is cosmetic; never fail a log query over it.
    if (!clientCache.byId.size) clientCache = { at: 0, byId: new Map() };
  }
  return clientCache.byId;
}

// --- mapping ---------------------------------------------------------------

// The backend tracks four live states; the map only distinguishes a live marker
// from a greyed-out one. ON_VISIT counts as active — the rep is at a client.
function mapStatus(status) {
  return status === 'ACTIVE' || status === 'ON_VISIT' ? 'active' : 'idle';
}

// lat/lng are null until the first GPS fix of a shift arrives. Leaflet cannot plot
// those, so they are dropped rather than passed through as a marker at (null, null).
function hasFix(position) {
  return typeof position.lat === 'number' && typeof position.lng === 'number';
}

function mapPosition(p) {
  return {
    id: `rep_${p.repId}`,
    repId: p.repId,
    repName: p.repName,
    lat: p.lat,
    lng: p.lng,
    status: mapStatus(p.status),
    backendStatus: p.status,
    onVisit: p.status === 'ON_VISIT',
    clientName: p.activeClientName || null,
    battery: p.battery,
    timestamp: p.recordedAt
  };
}

function mapVisit(v, addresses) {
  return {
    id: v.id,
    repId: v.repId,
    repName: v.repName,
    clientName: v.clientName,
    address: addresses.get(v.clientId) || '',
    lat: v.startLat,
    lng: v.startLng,
    // The backend has no notion of an activity type; the table renders an em dash.
    activityType: null,
    checkInTime: v.startedAt,
    checkOutTime: v.endedAt,
    durationMinutes: v.durationMin, // null while the visit is still open
    verified: v.status === 'VERIFIED',
    inProgress: v.status === 'IN_PROGRESS',
    status: v.status,
    notes: v.notes
  };
}

/** Inclusive YYYY-MM-DD range covering the last `days` days, ending today. */
function recentRange(days) {
  const to = new Date();
  const from = new Date(to.getTime() - (days - 1) * 86400000);
  const iso = (d) => d.toISOString().slice(0, 10);
  return { from: iso(from), to: iso(to) };
}

// --- public API ------------------------------------------------------------

async function getLiveLocations(token) {
  const positions = (await backend.get('/tracking/live', token)) || [];
  return positions.map(mapPosition).filter(hasFix);
}

async function getActivityLogs(token, { repId, date, limit = 50 } = {}) {
  const range = date ? { from: date, to: date } : recentRange(7);
  const params = new URLSearchParams({ from: range.from, to: range.to });
  if (repId) params.set('repId', repId);

  const [visits, addresses] = await Promise.all([
    backend.get(`/visits?${params.toString()}`, token),
    clientAddresses(token)
  ]);

  // The backend returns the range newest-first and does not paginate, so the
  // dashboard's growing `limit` is applied here.
  return (visits || []).slice(0, limit).map((v) => mapVisit(v, addresses));
}

async function getReps(token) {
  const users = (await backend.get('/users?role=REP', token)) || [];
  return users.map((u) => ({ id: u.id, name: u.fullName, username: u.username, active: u.active }));
}

async function getMetricsSummary(token) {
  const overview = await backend.get('/admin/overview?days=7&recentLimit=1', token);
  const m = overview.metrics;
  return {
    totalVisits: m.totalVisits,
    verifiedCount: m.verified,
    // The doughnut labels these "Pending", so an open visit belongs here rather
    // than being silently counted as a failed verification.
    unverifiedCount: m.unverified + m.inProgress,
    inProgressCount: m.inProgress,
    avgDurationMinutes: m.avgDurationMinutes,
    visitsPerRep: m.visitsPerRep.map((r) => ({ name: r.repName, count: r.count })),
    visitsByDay: m.visitsByDay
  };
}

// --- reporting -------------------------------------------------------------
// These pass the backend's report shapes through almost unchanged: the reporting
// vocabulary (verified/unverified/in-progress, periods, coverage) is the same on
// both sides, so translating it would only invent a second set of names.

/** `window` is either {period, offset} or {from, to}; the backend resolves whichever is set. */
function windowParams({ period, offset, from, to } = {}) {
  const params = new URLSearchParams();
  if (period) {
    params.set('period', period);
    params.set('offset', String(offset ?? 0));
  } else {
    if (from) params.set('from', from);
    if (to) params.set('to', to);
  }
  return params;
}

function getPeriodReport(token, { period = 'WEEK', offset = 0 } = {}) {
  return backend.get(`/reports/period?period=${period}&offset=${offset}`, token);
}

function getRepReport(token, repId, window) {
  return backend.get(`/reports/reps/${repId}?${windowParams(window)}`, token);
}

function getClientCoverage(token, window) {
  return backend.get(`/reports/clients?${windowParams(window)}`, token);
}

// --- customers -------------------------------------------------------------

function listClients(token) {
  return backend.get('/clients', token);
}

/**
 * The backend prefers explicit coordinates and only geocodes the address when none are
 * given, so the dashboard sends lat/lng whenever a pin has been placed.
 */
function createClient(token, body) {
  clientCache = { at: 0, byId: new Map() }; // addresses just changed
  return backend.post('/clients', body, token);
}

function updateClient(token, id, body) {
  clientCache = { at: 0, byId: new Map() };
  return backend.put(`/clients/${id}`, body, token);
}

/** Soft delete: the client stays attached to its historical visits. */
function deactivateClient(token, id) {
  clientCache = { at: 0, byId: new Map() };
  return backend.del(`/clients/${id}`, token);
}

function geocode(token, query) {
  return backend.get(`/geocode/search?q=${encodeURIComponent(query)}`, token);
}

// --- scheduling ------------------------------------------------------------

function getAssignments(token, { repId, status, from, to } = {}) {
  const params = new URLSearchParams();
  if (repId) params.set('repId', repId);
  if (status) params.set('status', status);
  if (from) params.set('from', from);
  if (to) params.set('to', to);
  return backend.get(`/assignments?${params}`, token);
}

function createAssignment(token, body) {
  return backend.post('/assignments', body, token);
}

function createAssignmentsBulk(token, body) {
  return backend.post('/assignments/bulk', body, token);
}

function updateAssignment(token, id, body) {
  return backend.put(`/assignments/${id}`, body, token);
}

function cancelAssignment(token, id) {
  return backend.del(`/assignments/${id}`, token);
}

/** Everything the dashboard needs for a first paint, in one backend round trip. */
async function getOverview(token, { days = 7, recentLimit = 25 } = {}) {
  const [overview, addresses] = await Promise.all([
    backend.get(`/admin/overview?days=${days}&recentLimit=${recentLimit}`, token),
    clientAddresses(token)
  ]);
  return {
    generatedAt: overview.generatedAt,
    liveLocations: overview.liveReps.map(mapPosition).filter(hasFix),
    logs: overview.recentVisits.map((v) => mapVisit(v, addresses)),
    metrics: {
      totalVisits: overview.metrics.totalVisits,
      verifiedCount: overview.metrics.verified,
      unverifiedCount: overview.metrics.unverified + overview.metrics.inProgress,
      avgDurationMinutes: overview.metrics.avgDurationMinutes,
      visitsPerRep: overview.metrics.visitsPerRep.map((r) => ({ name: r.repName, count: r.count })),
      visitsByDay: overview.metrics.visitsByDay
    }
  };
}

module.exports = {
  getLiveLocations,
  getActivityLogs,
  getReps,
  getMetricsSummary,
  getOverview,
  getPeriodReport,
  listClients,
  createClient,
  updateClient,
  deactivateClient,
  geocode,
  getAssignments,
  createAssignment,
  createAssignmentsBulk,
  updateAssignment,
  cancelAssignment,
  getRepReport,
  getClientCoverage,
  windowParams,
  // exported for the SSE relay, which maps pushed events with the same rules
  mapPosition,
  mapVisit,
  hasFix,
  clientAddresses
};
