// JSON API consumed by the dashboard's front-end JS (public/js/*.js).
// Every route sits behind requireAuthApi, and each one forwards the session's
// backend JWT — nothing here reaches the tracking data without an authenticated
// manager session on this server AND a valid token on the backend.
const express = require('express');
const router = express.Router();
const { requireAuthApi } = require('../middleware/auth');
const trackingService = require('../services/trackingService');
const backend = require('../services/backendClient');

router.use(requireAuthApi);

// Backend failures are reported with their own status so the browser can tell
// "backend is down" (503) apart from "your session expired" (401).
function fail(res, err, message) {
  const status = err.status && err.status >= 400 ? err.status : 500;
  if (status >= 500) console.error(message, err.message);
  res.status(status).json({ success: false, error: err.status === 401 ? 'Session expired. Please log in again.' : message });
}

// GET /api/locations/live — latest position per field rep, for the map
router.get('/locations/live', async (req, res) => {
  try {
    const locations = await trackingService.getLiveLocations(req.session.jwt);
    res.json({ success: true, count: locations.length, data: locations });
  } catch (err) {
    fail(res, err, 'Failed to fetch live locations.');
  }
});

// GET /api/logs?repId=&date=YYYY-MM-DD&limit=
router.get('/logs', async (req, res) => {
  try {
    const { repId, date, limit } = req.query;
    const logs = await trackingService.getActivityLogs(req.session.jwt, {
      repId: repId || undefined,
      date: date || undefined,
      limit: Number(limit) || 50
    });
    res.json({ success: true, count: logs.length, data: logs });
  } catch (err) {
    fail(res, err, 'Failed to fetch activity logs.');
  }
});

// GET /api/reps — team roster, used to populate the rep filter dropdown
router.get('/reps', async (req, res) => {
  try {
    const reps = await trackingService.getReps(req.session.jwt);
    res.json({ success: true, count: reps.length, data: reps });
  } catch (err) {
    fail(res, err, 'Failed to fetch representatives.');
  }
});

// GET /api/metrics/summary — aggregated numbers for the Team Metrics charts
router.get('/metrics/summary', async (req, res) => {
  try {
    const summary = await trackingService.getMetricsSummary(req.session.jwt);
    res.json({ success: true, data: summary });
  } catch (err) {
    fail(res, err, 'Failed to fetch team metrics.');
  }
});

// GET /api/overview — live positions, recent visits and metrics in one call
router.get('/overview', async (req, res) => {
  try {
    const data = await trackingService.getOverview(req.session.jwt, {
      days: Number(req.query.days) || 7,
      recentLimit: Number(req.query.recentLimit) || 25
    });
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch dashboard overview.');
  }
});

// --- scheduling ------------------------------------------------------------

// GET /api/assignments?repId=&status=&from=&to=
router.get('/assignments', async (req, res) => {
  try {
    const data = await trackingService.getAssignments(req.session.jwt, req.query);
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch the schedule.');
  }
});

// POST /api/assignments — one planned visit
router.post('/assignments', async (req, res) => {
  try {
    const data = await trackingService.createAssignment(req.session.jwt, req.body);
    res.status(201).json({ success: true, data });
  } catch (err) {
    fail(res, err, err.message || 'Failed to schedule the visit.');
  }
});

// POST /api/assignments/bulk — a whole route for one rep on one day
router.post('/assignments/bulk', async (req, res) => {
  try {
    const data = await trackingService.createAssignmentsBulk(req.session.jwt, req.body);
    res.status(201).json({ success: true, count: data.length, data });
  } catch (err) {
    fail(res, err, err.message || 'Failed to schedule the route.');
  }
});

router.put('/assignments/:id', async (req, res) => {
  try {
    const data = await trackingService.updateAssignment(req.session.jwt, req.params.id, req.body);
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, err.message || 'Failed to update the scheduled visit.');
  }
});

router.delete('/assignments/:id', async (req, res) => {
  try {
    await trackingService.cancelAssignment(req.session.jwt, req.params.id);
    res.json({ success: true });
  } catch (err) {
    fail(res, err, err.message || 'Failed to cancel the scheduled visit.');
  }
});

// --- customers -------------------------------------------------------------

router.get('/clients', async (req, res) => {
  try {
    const data = await trackingService.listClients(req.session.jwt);
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch clients.');
  }
});

router.post('/clients', async (req, res) => {
  try {
    const data = await trackingService.createClient(req.session.jwt, req.body);
    res.status(201).json({ success: true, data });
  } catch (err) {
    fail(res, err, err.message || 'Failed to add the customer.');
  }
});

router.put('/clients/:id', async (req, res) => {
  try {
    const data = await trackingService.updateClient(req.session.jwt, req.params.id, req.body);
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, err.message || 'Failed to update the customer.');
  }
});

router.delete('/clients/:id', async (req, res) => {
  try {
    await trackingService.deactivateClient(req.session.jwt, req.params.id);
    res.json({ success: true });
  } catch (err) {
    fail(res, err, err.message || 'Failed to remove the customer.');
  }
});

/** Address lookup for the add-customer form. Nominatim is throttled to 1 req/s upstream. */
router.get('/geocode', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (!q) return res.json({ success: true, data: [] });
  try {
    const data = await trackingService.geocode(req.session.jwt, q);
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, err.message || 'Address lookup is unavailable. Drop a pin instead.');
  }
});

// GET /api/reports/period?period=WEEK&offset=0
router.get('/reports/period', async (req, res) => {
  try {
    const data = await trackingService.getPeriodReport(req.session.jwt, {
      period: req.query.period || 'WEEK',
      offset: Number(req.query.offset) || 0
    });
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch the period report.');
  }
});

// GET /api/reports/reps/:repId?period=&offset=  — one rep drilled down
router.get('/reports/reps/:repId', async (req, res) => {
  try {
    const data = await trackingService.getRepReport(req.session.jwt, req.params.repId, req.query);
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch the representative report.');
  }
});

// GET /api/reports/clients?period=&offset=  — account coverage
router.get('/reports/clients', async (req, res) => {
  try {
    const data = await trackingService.getClientCoverage(req.session.jwt, req.query);
    res.json({ success: true, data });
  } catch (err) {
    fail(res, err, 'Failed to fetch client coverage.');
  }
});

/**
 * GET /api/reports/:file.csv — streams a backend CSV through to the browser.
 *
 * The download cannot go direct: the browser has no JWT, so Express fetches it with
 * the session token and forwards the body and filename unchanged.
 */
router.get('/reports/download/:file', async (req, res) => {
  const allowed = { summary: 'summary.csv', visits: 'visits.csv' };
  const target = allowed[req.params.file];
  if (!target) {
    return res.status(404).json({ success: false, error: 'Unknown report.' });
  }
  try {
    const params = trackingService.windowParams(req.query);
    const upstream = await fetch(`${backend.backendUrl}/api/v1/reports/${target}?${params}`, {
      headers: { Authorization: `Bearer ${req.session.jwt}` }
    });
    if (!upstream.ok) {
      return res.status(upstream.status).json({ success: false, error: `Backend returned ${upstream.status}` });
    }
    res.set({
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': upstream.headers.get('content-disposition') || `attachment; filename="${target}"`
    });
    res.send(await upstream.text());
  } catch (err) {
    console.error('CSV download failed:', err.message);
    res.status(502).json({ success: false, error: 'Could not reach the backend.' });
  }
});

/**
 * GET /api/stream — relays the backend's SSE feed to the browser.
 *
 * The browser cannot open the backend stream itself: EventSource cannot send an
 * Authorization header, and the backend has no CORS configuration. So Express holds
 * the authenticated upstream connection and re-emits events, mapped to the same
 * shapes the polling routes return.
 */
router.get('/stream', async (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no'
  });
  res.flushHeaders();

  const controller = new AbortController();
  req.on('close', () => controller.abort());

  const send = (event, payload) => res.write(`event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`);

  let upstream;
  try {
    upstream = await fetch(backend.streamUrl, {
      headers: { Authorization: `Bearer ${req.session.jwt}`, Accept: 'text/event-stream' },
      signal: controller.signal
    });
    if (!upstream.ok || !upstream.body) {
      send('fatal', { error: `Backend stream unavailable (${upstream.status})` });
      return res.end();
    }
  } catch (err) {
    if (!controller.signal.aborted) send('fatal', { error: 'Cannot reach the backend stream.' });
    return res.end();
  }

  send('open', { at: new Date().toISOString() });
  const addresses = await trackingService.clientAddresses(req.session.jwt);

  // Parse the upstream event stream incrementally: frames are separated by a blank
  // line and can straddle chunk boundaries, so a buffer is required.
  let buffer = '';
  try {
    for await (const chunk of upstream.body) {
      buffer += Buffer.from(chunk).toString('utf8');
      let split;
      while ((split = buffer.indexOf('\n\n')) !== -1) {
        const frame = buffer.slice(0, split);
        buffer = buffer.slice(split + 2);
        relay(frame, send, addresses);
      }
    }
  } catch {
    // Upstream closed or the client went away; either way the response ends below.
  }
  res.end();
});

function relay(frame, send, addresses) {
  let event = null;
  const dataLines = [];
  for (const line of frame.split('\n')) {
    if (line.startsWith(':')) continue; // heartbeat comment
    if (line.startsWith('event:')) event = line.slice(6).trim();
    else if (line.startsWith('data:')) dataLines.push(line.slice(5).trim());
  }
  if (!event || !dataLines.length) return;

  let payload;
  try {
    payload = JSON.parse(dataLines.join('\n'));
  } catch {
    return;
  }

  if (event === 'position') {
    const mapped = trackingService.mapPosition(payload);
    // A rep who has gone off shift, or has no fix yet, is sent as a removal so the
    // map can drop the marker instead of leaving it frozen at a stale position.
    if (payload.status === 'OFF_SHIFT' || !trackingService.hasFix(mapped)) {
      send('rep-offline', { repId: mapped.repId, repName: mapped.repName });
    } else {
      send('position', mapped);
    }
  } else if (event === 'visit') {
    send('visit', trackingService.mapVisit(payload, addresses));
  }
}

module.exports = router;
