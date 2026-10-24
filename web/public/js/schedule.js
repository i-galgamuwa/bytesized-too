// Schedule page: assign planned visits to reps and review what is already booked.
// Creating an assignment pushes it to that rep over STOMP, so no "notify" step exists here.

const el = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const iso = (d) => d.toISOString().slice(0, 10);
const today = () => iso(new Date());
const addDays = (n) => { const d = new Date(); d.setDate(d.getDate() + n); return iso(d); };

const RANGES = {
  today: () => ({ from: today(), to: today(), label: 'Today' }),
  upcoming: () => ({ from: today(), to: addDays(7), label: 'Today to ' + addDays(7) }),
  past: () => ({ from: addDays(-7), to: addDays(-1), label: addDays(-7) + ' to ' + addDays(-1) })
};

const STATUS_BADGE = {
  PENDING: 'bg-blue-50 text-accent',
  COMPLETED: 'bg-teal-50 text-verified',
  MISSED: 'bg-amber-50 text-pending',
  CANCELLED: 'bg-slate-100 text-slate-500'
};

function fmtDate(d) {
  return new Date(d + 'T00:00:00').toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

// The backend sends a LocalTime, which serialises as HH:mm:ss.
function fmtTime(t) {
  if (!t) return null;
  const [h, m] = t.split(':');
  const hour = Number(h);
  return `${((hour + 11) % 12) + 1}:${m} ${hour < 12 ? 'am' : 'pm'}`;
}

function message(text, ok) {
  const p = el('form-msg');
  p.textContent = text;
  p.className = `text-xs ${ok ? 'text-verified' : 'text-red-600'}`;
  p.classList.remove('hidden');
  if (ok) setTimeout(() => p.classList.add('hidden'), 4000);
}

async function loadReps() {
  const res = await fetch('/api/reps');
  const json = await res.json();
  if (!json.success) return;
  for (const select of [el('f-rep'), el('filter-rep')]) {
    json.data.forEach((rep) => {
      const opt = document.createElement('option');
      opt.value = rep.id;
      opt.textContent = rep.name;
      select.appendChild(opt);
    });
  }
}

async function loadClients() {
  const res = await fetch('/api/clients');
  const json = await res.json();
  const box = el('f-clients');
  if (!json.success || !json.data.length) {
    box.innerHTML = '<p class="px-3 py-3 text-sm text-slate-400">No clients available.</p>';
    return;
  }
  box.innerHTML = json.data.map((c) => `
    <label class="flex items-start gap-2.5 px-3 py-2 hover:bg-slate-50 cursor-pointer">
      <input type="checkbox" value="${c.id}" class="mt-0.5 rounded border-slate-300 text-accent focus:ring-accent/40">
      <span class="min-w-0">
        <span class="block text-sm text-ink truncate">${esc(c.name)}</span>
        <span class="block text-xs text-slate-400 truncate">${esc(c.address) || '—'}</span>
      </span>
    </label>`).join('');
}

function renderBoard(assignments) {
  const board = el('board');
  if (!assignments.length) {
    board.innerHTML = '<p class="px-6 py-8 text-center text-sm text-slate-400">No visits planned for this period.</p>';
    return;
  }

  // Group by date, then by rep: a manager reads the schedule a day at a time.
  const byDate = new Map();
  assignments.forEach((a) => {
    if (!byDate.has(a.scheduledDate)) byDate.set(a.scheduledDate, new Map());
    const reps = byDate.get(a.scheduledDate);
    if (!reps.has(a.repId)) reps.set(a.repId, { name: a.repName, items: [] });
    reps.get(a.repId).items.push(a);
  });

  board.innerHTML = [...byDate.entries()].map(([date, reps]) => `
    <div class="px-6 py-4">
      <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-3">${fmtDate(date)}</h3>
      <div class="space-y-4">
        ${[...reps.values()].map((rep) => `
          <div>
            <p class="text-sm font-medium text-ink mb-1.5">${esc(rep.name)}
              <span class="text-xs font-normal text-slate-400">· ${rep.items.length} stop${rep.items.length === 1 ? '' : 's'}</span>
            </p>
            <ul class="space-y-1.5">
              ${rep.items.map((a) => `
                <li class="flex items-start gap-3 bg-slate-50 rounded-md px-3 py-2">
                  <span class="text-xs font-mono text-slate-500 w-16 flex-shrink-0 pt-0.5">${fmtTime(a.scheduledTime) || '—'}</span>
                  <span class="min-w-0 flex-1">
                    <span class="block text-sm text-ink truncate">
                      ${esc(a.clientName)}
                      ${a.priority === 'HIGH' ? '<span class="ml-1.5 text-xs font-medium text-pending">High</span>' : ''}
                    </span>
                    ${a.note ? `<span class="block text-xs text-slate-500 truncate">${esc(a.note)}</span>` : ''}
                  </span>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0 ${STATUS_BADGE[a.status] || ''}">
                    ${a.status.charAt(0) + a.status.slice(1).toLowerCase()}
                  </span>
                  ${a.status === 'PENDING'
                    ? `<button data-cancel="${a.id}" class="text-xs text-slate-400 hover:text-red-600 flex-shrink-0">Cancel</button>`
                    : '<span class="w-10 flex-shrink-0"></span>'}
                </li>`).join('')}
            </ul>
          </div>`).join('')}
      </div>
    </div>`).join('');

  board.querySelectorAll('button[data-cancel]').forEach((btn) => {
    btn.addEventListener('click', () => cancelAssignment(btn.dataset.cancel));
  });
}

async function loadBoard() {
  const range = RANGES[el('filter-range').value]();
  el('range-label').textContent = range.label;

  const params = new URLSearchParams({ from: range.from, to: range.to });
  const repId = el('filter-rep').value;
  if (repId) params.set('repId', repId);

  try {
    const res = await fetch(`/api/assignments?${params}`);
    const json = await res.json();
    if (!json.success) throw new Error(json.error);
    renderBoard(json.data);
    const synced = el('last-synced');
    if (synced) synced.textContent = new Date().toLocaleTimeString();
  } catch (err) {
    el('board').innerHTML = `<p class="px-6 py-8 text-center text-sm text-red-500">${esc(err.message || 'Failed to load the schedule.')}</p>`;
  }
}

async function cancelAssignment(id) {
  try {
    const res = await fetch(`/api/assignments/${id}`, { method: 'DELETE' });
    const json = await res.json();
    if (!json.success) throw new Error(json.error);
    loadBoard();
  } catch (err) {
    message(err.message || 'Could not cancel that visit.', false);
  }
}

async function submitAssignment(event) {
  event.preventDefault();
  const button = el('f-submit');
  const repId = Number(el('f-rep').value);
  const date = el('f-date').value;
  const time = el('f-time').value || null;
  const priority = el('f-priority').value;
  const note = el('f-note').value.trim() || null;
  const clientIds = [...el('f-clients').querySelectorAll('input:checked')].map((c) => Number(c.value));

  if (!repId || !date || !clientIds.length) {
    return message('Choose a representative, a date and at least one client.', false);
  }

  button.disabled = true;
  button.textContent = 'Assigning…';
  try {
    // A time only makes sense for a single stop; a route is sent unscheduled.
    const single = clientIds.length === 1;
    const res = await fetch(single ? '/api/assignments' : '/api/assignments/bulk', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(single
        ? { repId, clientId: clientIds[0], date, time, priority, note }
        : { repId, date, clientIds, priority, note })
    });
    const json = await res.json();
    if (!json.success) throw new Error(json.error);

    message(`Sent ${clientIds.length} visit${clientIds.length === 1 ? '' : 's'} to the representative.`, true);
    el('f-clients').querySelectorAll('input:checked').forEach((c) => { c.checked = false; });
    el('f-note').value = '';
    el('f-time').value = '';
    loadBoard();
  } catch (err) {
    message(err.message || 'Could not schedule those visits.', false);
  } finally {
    button.disabled = false;
    button.textContent = 'Assign visits';
  }
}

document.addEventListener('DOMContentLoaded', () => {
  el('f-date').value = today();
  el('f-date').min = today(); // the backend rejects past dates; do not offer them
  loadReps();
  loadClients();
  loadBoard();

  el('assign-form').addEventListener('submit', submitAssignment);
  el('filter-rep').addEventListener('change', loadBoard);
  el('filter-range').addEventListener('change', loadBoard);
  el('refresh-btn')?.addEventListener('click', loadBoard);
});
