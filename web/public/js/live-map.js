// Live Map page: renders field-rep positions on Leaflet and the latest visit-log
// table underneath it.
//
// Positions arrive over an EventSource connected to /api/stream, which Express
// relays from the backend — so markers move as pings land rather than on a timer.
// The periodic refresh below is only a safety net for a dropped stream.
const DEFAULT_CENTER = [6.9271, 79.8612]; // Colombo, Sri Lanka
const FALLBACK_REFRESH_MS = 60000;

// Tile provider.
//
// OpenStreetMap's volunteer servers block apps they judge to be over-using them, and
// the block arrives as a normal HTTP 200 carrying an "Access blocked" image — so
// Leaflet sees a valid tile, no error event fires, and no fallback can detect it.
// A dashboard that reloads often trips this easily. Esri's World Street Map needs no
// API key and imposes no such limit, so it is the default.
//
// Set TILES to TILE_PROVIDERS.osm for OpenStreetMap rendering. Note the URL there has
// no {s} subdomain: that sharding is deprecated, and using it is what OSM treats as
// "not following the tile usage policy".
const TILE_PROVIDERS = {
  esri: {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Tiles &copy; Esri — Esri, HERE, Garmin, USGS, NGA',
    maxZoom: 19
  },
  osm: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors',
    maxZoom: 19
  }
};
const TILES = TILE_PROVIDERS.esri;

let map;
const markers = {};
// Last known payload per rep, so the side panel can show status and fix age
// without re-querying. Keyed by repId, same as markers.
const reps = {};

function initMap() {
  map = L.map('live-map').setView(DEFAULT_CENTER, 12);
  L.tileLayer(TILES.url, { maxZoom: TILES.maxZoom, attribution: TILES.attribution }).addTo(map);
}

function statusColor(status) {
  return status === 'active' ? '#2563EB' : '#94A3B8';
}

function timeAgo(iso) {
  return ageLabel(minutesSince(iso));
}

function upsertMarker(loc) {
  if (typeof loc.lat !== 'number' || typeof loc.lng !== 'number') return;
  reps[loc.repId] = loc;

  const icon = L.divIcon({
    html: `<span style="background:${statusColor(loc.status)}" class="block w-3.5 h-3.5 rounded-full ring-2 ring-white shadow"></span>`,
    className: '',
    iconSize: [14, 14]
  });

  if (markers[loc.repId]) {
    markers[loc.repId].setLatLng([loc.lat, loc.lng]).setIcon(icon);
  } else {
    markers[loc.repId] = L.marker([loc.lat, loc.lng], { icon }).addTo(map);
  }

  const where = loc.onVisit && loc.clientName ? ` at ${loc.clientName}` : '';
  const state = loc.onVisit ? 'On visit' : loc.status === 'active' ? 'Active' : 'Idle';
  markers[loc.repId].bindPopup(`
    <div class="text-sm">
      <p class="font-semibold">${loc.repName}</p>
      <p class="text-slate-500">${state}${where} &middot; updated ${timeAgo(loc.timestamp)}</p>
    </div>
  `);
}

// A rep who ended a shift should disappear rather than linger at their last position.
function removeMarker(repId) {
  if (markers[repId]) {
    map.removeLayer(markers[repId]);
    delete markers[repId];
  }
  delete reps[repId];
  renderRepList();
}

/**
 * Centres the map on a rep and opens their popup.
 *
 * The popup must wait for the movement to finish: opening it mid-flight makes Leaflet
 * pan to fit the popup, which cancels the fly animation and leaves the map where it was.
 */
function focusRep(repId) {
  const marker = markers[repId];
  if (!marker) return;

  let opened = false;
  const open = () => {
    if (opened) return;
    opened = true;
    marker.openPopup();
  };

  map.once('moveend', open);
  map.flyTo(marker.getLatLng(), Math.max(map.getZoom(), 15), { duration: 0.6 });
  // If the map was already centred there, moveend may never fire.
  setTimeout(open, 900);

  renderRepList(repId);
}

// Minutes since a fix, used to show when a marker is older than it looks. The backend
// reports ON_VISIT ahead of STALE, so a rep parked in a visit stays "active" however
// long their phone has been silent — this is the only place that silence is visible.
function minutesSince(iso) {
  if (!iso) return null;
  return Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
}

function ageLabel(mins) {
  if (mins === null) return 'no fix yet';
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const h = Math.floor(mins / 60);
  return h < 24 ? `${h} h ago` : `${Math.floor(h / 24)} d ago`;
}

function renderRepList(selectedId) {
  const list = document.getElementById('rep-list');
  if (!list) return;

  const rows = Object.values(reps).sort((a, b) => a.repName.localeCompare(b.repName));
  if (!rows.length) {
    list.innerHTML = '<li class="px-4 py-6 text-center text-sm text-slate-400">No representatives on shift.</li>';
    return;
  }

  list.innerHTML = rows.map((r) => {
    const mins = minutesSince(r.timestamp);
    const silent = mins !== null && mins >= 5;
    const dot = r.status === 'active' ? '#2563EB' : '#94A3B8';
    const selected = String(r.repId) === String(selectedId) ? ' bg-slate-50' : '';
    const where = r.onVisit && r.clientName ? `at ${r.clientName}` : r.status === 'active' ? 'Active' : 'Idle';
    return `
      <li>
        <button type="button" data-rep-id="${r.repId}"
          class="w-full text-left px-4 py-3 hover:bg-slate-50 transition-colors${selected}">
          <div class="flex items-center gap-2">
            <span style="background:${dot}" class="w-2.5 h-2.5 rounded-full flex-shrink-0"></span>
            <span class="text-sm font-medium text-ink truncate">${r.repName}</span>
          </div>
          <p class="text-xs text-slate-500 mt-0.5 truncate pl-4.5">${where}</p>
          <p class="text-xs ${silent ? 'text-pending font-medium' : 'text-slate-400'} mt-0.5 pl-4.5">
            ${silent ? '&#9888; ' : ''}${ageLabel(mins)}
          </p>
        </button>
      </li>`;
  }).join('');

  list.querySelectorAll('button[data-rep-id]').forEach((btn) => {
    btn.addEventListener('click', () => focusRep(Number(btn.dataset.repId)));
  });
}

async function loadLiveLocations() {
  try {
    const res = await fetch('/api/locations/live');
    const json = await res.json();
    if (!json.success) return;

    // The snapshot is authoritative: anyone no longer in it has gone off shift,
    // so drop their marker rather than leaving it frozen on the map.
    const present = new Set(json.data.map((d) => String(d.repId)));
    Object.keys(markers).forEach((id) => {
      if (!present.has(String(id))) removeMarker(Number(id));
    });

    json.data.forEach(upsertMarker);
    renderRepList();
  } catch (err) {
    console.error('Failed to load live locations', err);
  }
}

function verifiedBadge(log) {
  if (log.inProgress) {
    return '<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600">In progress</span>';
  }
  return log.verified
    ? '<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-teal-50 text-verified">Verified</span>'
    : '<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-50 text-pending">Pending</span>';
}

function formatTime(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function formatDuration(mins) {
  return mins === null || mins === undefined ? '—' : `${mins} min`;
}

async function loadLatestLogs() {
  const tbody = document.getElementById('latest-logs-body');
  try {
    const res = await fetch('/api/logs?limit=8');
    const json = await res.json();
    if (!json.success) {
      tbody.innerHTML = `<tr><td colspan="6" class="px-6 py-6 text-center text-red-500">${json.error || 'Failed to load logs.'}</td></tr>`;
      return;
    }
    if (!json.data.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="px-6 py-6 text-center text-slate-400">No visit logs yet.</td></tr>';
      return;
    }
    tbody.innerHTML = json.data.map((log) => `
      <tr class="hover:bg-slate-50">
        <td class="px-6 py-3 font-medium text-ink">
          <button type="button" data-locate-rep="${log.repId}" class="hover:text-accent hover:underline text-left">${log.repName}</button>
        </td>
        <td class="px-6 py-3 text-slate-600">${log.clientName}</td>
        <td class="px-6 py-3 text-slate-500">${log.address || '—'}</td>
        <td class="px-6 py-3 font-mono text-slate-500">${formatTime(log.checkInTime)}</td>
        <td class="px-6 py-3 font-mono text-slate-500">${formatDuration(log.durationMinutes)}</td>
        <td class="px-6 py-3">${verifiedBadge(log)}</td>
      </tr>
    `).join('');
    // Only reps currently on the map can be located; the rest stay plain text.
    tbody.querySelectorAll('button[data-locate-rep]').forEach((btn) => {
      const id = Number(btn.dataset.locateRep);
      if (markers[id]) {
        btn.addEventListener('click', () => focusRep(id));
      } else {
        btn.className = 'text-left cursor-default';
        btn.title = 'Not on shift right now';
      }
    });
  } catch (err) {
    tbody.innerHTML = '<tr><td colspan="6" class="px-6 py-6 text-center text-red-500">Failed to load logs.</td></tr>';
  }
}

function touchLastSynced() {
  const el = document.getElementById('last-synced');
  if (el) el.textContent = new Date().toLocaleTimeString();
}

async function refreshAll() {
  await Promise.all([loadLiveLocations(), loadLatestLogs()]);
  touchLastSynced();
}

// EventSource reconnects on its own after a transient drop; the error handler only
// needs to surface the state, not re-open the connection.
function connectStream() {
  const source = new EventSource('/api/stream');

  source.addEventListener('position', (e) => {
    upsertMarker(JSON.parse(e.data));
    renderRepList();
    touchLastSynced();
  });

  source.addEventListener('rep-offline', (e) => {
    removeMarker(JSON.parse(e.data).repId);
    touchLastSynced();
  });

  // A visit starting or ending changes the log table, so pull the fresh rows.
  source.addEventListener('visit', () => {
    loadLatestLogs();
    touchLastSynced();
  });

  source.addEventListener('fatal', (e) => {
    console.error('Live stream unavailable:', JSON.parse(e.data).error);
    source.close();
  });

  source.onerror = () => console.warn('Live stream interrupted; reconnecting…');
  return source;
}

document.addEventListener('DOMContentLoaded', () => {
  initMap();
  refreshAll();
  connectStream();
  document.getElementById('refresh-btn')?.addEventListener('click', refreshAll);
  setInterval(refreshAll, FALLBACK_REFRESH_MS);
  // Fix ages are relative, so redraw the panel on a timer even when no event arrives —
  // otherwise "2 min ago" would still read "2 min ago" an hour later.
  setInterval(() => renderRepList(), 30000);
});
