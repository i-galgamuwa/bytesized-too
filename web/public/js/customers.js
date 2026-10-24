// Customers page: add, edit and retire the locations reps visit.
//
// The pin is the important part. A client's coordinates and radius are what every visit is
// verified against, so the map shows the geofence circle live as the radius changes — a
// manager should see the area they are committing to before saving it.

const DEFAULT_CENTER = [6.9271, 79.8612]; // Colombo
const TILES = {
  url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  attribution: 'Tiles &copy; Esri — Esri, HERE, Garmin, USGS, NGA',
  maxZoom: 19
};

const el = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let map;
let pin = null;        // the draggable marker being edited
let fence = null;      // the circle showing its geofence
let existing = [];     // markers for saved customers

function initMap() {
  map = L.map('client-map').setView(DEFAULT_CENTER, 12);
  L.tileLayer(TILES.url, { maxZoom: TILES.maxZoom, attribution: TILES.attribution }).addTo(map);
  map.on('click', (e) => placePin(e.latlng.lat, e.latlng.lng));
}

function currentRadius() {
  const r = Number(el('f-radius').value);
  return Number.isFinite(r) && r > 0 ? r : 100;
}

function placePin(lat, lng, zoom) {
  el('f-lat').value = lat.toFixed(6);
  el('f-lng').value = lng.toFixed(6);

  if (!pin) {
    pin = L.marker([lat, lng], { draggable: true }).addTo(map);
    pin.on('drag', (e) => {
      const p = e.target.getLatLng();
      el('f-lat').value = p.lat.toFixed(6);
      el('f-lng').value = p.lng.toFixed(6);
      fence.setLatLng(p);
    });
    fence = L.circle([lat, lng], {
      radius: currentRadius(), color: '#2563EB', weight: 1.5, fillColor: '#2563EB', fillOpacity: 0.12
    }).addTo(map);
  } else {
    pin.setLatLng([lat, lng]);
    fence.setLatLng([lat, lng]);
  }
  fence.setRadius(currentRadius());
  if (zoom) map.setView([lat, lng], zoom);
}

function clearPin() {
  if (pin) { map.removeLayer(pin); pin = null; }
  if (fence) { map.removeLayer(fence); fence = null; }
  el('f-lat').value = '';
  el('f-lng').value = '';
}

function message(text, ok) {
  const p = el('form-msg');
  p.textContent = text;
  p.className = `text-xs ${ok ? 'text-verified' : 'text-red-600'}`;
  p.classList.remove('hidden');
  if (ok) setTimeout(() => p.classList.add('hidden'), 4000);
}

// --- address lookup --------------------------------------------------------

async function searchAddress() {
  const q = el('f-address').value.trim();
  const list = el('geo-results');
  if (!q) return;

  list.innerHTML = '<li class="px-3 py-2 text-xs text-slate-400">Searching…</li>';
  list.classList.remove('hidden');

  try {
    const res = await fetch(`/api/geocode?q=${encodeURIComponent(q)}`);
    const json = await res.json();
    if (!json.success) throw new Error(json.error);

    if (!json.data.length) {
      list.innerHTML = '<li class="px-3 py-2 text-xs text-slate-500">No match. Click the map to place the pin yourself.</li>';
      return;
    }
    list.innerHTML = json.data.map((r, i) => `
      <li><button type="button" data-i="${i}" class="w-full text-left px-3 py-2 text-xs hover:bg-slate-50">
        ${esc(r.displayName)}
      </button></li>`).join('');

    list.querySelectorAll('button[data-i]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const r = json.data[Number(btn.dataset.i)];
        placePin(r.lat, r.lng, 16);
        list.classList.add('hidden');
      });
    });
  } catch (err) {
    list.innerHTML = `<li class="px-3 py-2 text-xs text-red-600">${esc(err.message || 'Lookup failed.')}</li>`;
  }
}

// --- list ------------------------------------------------------------------

function renderClients(clients) {
  el('client-count').textContent = `${clients.length} active`;
  const body = el('clients-body');

  if (!clients.length) {
    body.innerHTML = '<tr><td colspan="5" class="px-6 py-6 text-center text-slate-400">No customers yet.</td></tr>';
    return;
  }

  body.innerHTML = clients.map((c) => `
    <tr class="hover:bg-slate-50">
      <td class="px-6 py-3 font-medium text-ink">${esc(c.name)}</td>
      <td class="px-6 py-3 text-slate-500">${esc(c.address) || '—'}</td>
      <td class="px-6 py-3 text-right font-mono text-slate-600">${c.radiusM} m</td>
      <td class="px-6 py-3 font-mono text-xs text-slate-400">${c.lat.toFixed(4)}, ${c.lng.toFixed(4)}</td>
      <td class="px-6 py-3 text-right whitespace-nowrap">
        <button data-locate="${c.id}" class="text-xs text-slate-500 hover:text-ink mr-3">Show</button>
        <button data-edit="${c.id}" class="text-xs text-accent hover:underline mr-3">Edit</button>
        <button data-remove="${c.id}" class="text-xs text-slate-400 hover:text-red-600">Remove</button>
      </td>
    </tr>`).join('');

  body.querySelectorAll('button[data-locate]').forEach((b) =>
    b.addEventListener('click', () => showClient(clients.find((c) => c.id === Number(b.dataset.locate)))));
  body.querySelectorAll('button[data-edit]').forEach((b) =>
    b.addEventListener('click', () => startEdit(clients.find((c) => c.id === Number(b.dataset.edit)))));
  body.querySelectorAll('button[data-remove]').forEach((b) =>
    b.addEventListener('click', () => removeClient(clients.find((c) => c.id === Number(b.dataset.remove)))));
}

function drawExisting(clients) {
  existing.forEach((m) => map.removeLayer(m));
  existing = [];
  clients.forEach((c) => {
    const circle = L.circle([c.lat, c.lng], {
      radius: c.radiusM, color: '#94A3B8', weight: 1, fillColor: '#94A3B8', fillOpacity: 0.08
    }).addTo(map).bindPopup(`<b>${esc(c.name)}</b><br>${esc(c.address) || ''}<br>${c.radiusM} m geofence`);
    existing.push(circle);
  });
}

function showClient(c) {
  if (!c) return;
  map.setView([c.lat, c.lng], 16);
  const match = existing.find((m) => {
    const p = m.getLatLng();
    return Math.abs(p.lat - c.lat) < 1e-9 && Math.abs(p.lng - c.lng) < 1e-9;
  });
  if (match) match.openPopup();
}

async function load() {
  try {
    const res = await fetch('/api/clients');
    const json = await res.json();
    if (!json.success) throw new Error(json.error);
    renderClients(json.data);
    drawExisting(json.data);
    const synced = el('last-synced');
    if (synced) synced.textContent = new Date().toLocaleTimeString();
  } catch (err) {
    el('clients-body').innerHTML =
      `<tr><td colspan="5" class="px-6 py-6 text-center text-red-500">${esc(err.message || 'Failed to load customers.')}</td></tr>`;
  }
}

// --- create / edit / remove ------------------------------------------------

function startEdit(c) {
  if (!c) return;
  el('f-id').value = c.id;
  el('f-name').value = c.name;
  el('f-address').value = c.address || '';
  el('f-radius').value = c.radiusM;
  el('form-title').textContent = 'Edit customer';
  el('f-submit').textContent = 'Save changes';
  el('cancel-edit').classList.remove('hidden');
  placePin(c.lat, c.lng, 16);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function resetForm() {
  el('client-form').reset();
  el('f-id').value = '';
  el('f-radius').value = 100;
  el('form-title').textContent = 'Add a customer';
  el('f-submit').textContent = 'Add customer';
  el('cancel-edit').classList.add('hidden');
  el('geo-results').classList.add('hidden');
  el('form-msg').classList.add('hidden');
  clearPin();
}

async function removeClient(c) {
  if (!c) return;
  // Soft delete upstream, so existing visits keep resolving this customer.
  if (!window.confirm(`Remove ${c.name}? Past visits will still show it, but it can no longer be scheduled.`)) return;
  try {
    const res = await fetch(`/api/clients/${c.id}`, { method: 'DELETE' });
    const json = await res.json();
    if (!json.success) throw new Error(json.error);
    if (String(el('f-id').value) === String(c.id)) resetForm();
    load();
  } catch (err) {
    message(err.message || 'Could not remove that customer.', false);
  }
}

async function submitForm(event) {
  event.preventDefault();
  const id = el('f-id').value;
  const name = el('f-name').value.trim();
  const address = el('f-address').value.trim();
  const lat = el('f-lat').value ? Number(el('f-lat').value) : null;
  const lng = el('f-lng').value ? Number(el('f-lng').value) : null;
  const radiusM = Number(el('f-radius').value);

  if (!name) return message('Give the customer a name.', false);
  if (lat === null && !address) {
    return message('Place a pin on the map, or enter an address to look up.', false);
  }
  if (!Number.isFinite(radiusM) || radiusM < 20 || radiusM > 2000) {
    return message('Radius must be between 20 and 2000 metres.', false);
  }

  const button = el('f-submit');
  button.disabled = true;
  const original = button.textContent;
  button.textContent = 'Saving…';

  try {
    const res = await fetch(id ? `/api/clients/${id}` : '/api/clients', {
      method: id ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, address: address || null, lat, lng, radiusM })
    });
    const json = await res.json();
    if (!json.success) throw new Error(json.error);

    const saved = json.data;
    message(id ? `Updated ${saved.name}.` : `Added ${saved.name}.`, true);
    resetForm();
    await load();
    map.setView([saved.lat, saved.lng], 15);
  } catch (err) {
    message(err.message || 'Could not save that customer.', false);
  } finally {
    button.disabled = false;
    button.textContent = el('f-id').value ? 'Save changes' : original;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initMap();
  load();

  el('client-form').addEventListener('submit', submitForm);
  el('cancel-edit').addEventListener('click', resetForm);
  el('f-search').addEventListener('click', searchAddress);
  el('f-radius').addEventListener('input', () => { if (fence) fence.setRadius(currentRadius()); });

  // Enter in the address box should look it up, not submit a half-filled form.
  el('f-address').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); searchAddress(); }
  });

  el('refresh-btn')?.addEventListener('click', load);
});
