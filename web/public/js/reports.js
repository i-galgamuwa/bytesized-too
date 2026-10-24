// Reports page: a period switcher driving the team summary, the daily trend,
// a per-rep table with drill-down, and account coverage.
Chart.defaults.font.family = "'IBM Plex Sans', sans-serif";
Chart.defaults.color = '#64748B';

let current = { period: 'WEEK', offset: 0 };
let trendChart = null;
let openRepId = null;

const el = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// A null percent means nothing has completed yet, which is not the same as 0%.
const pct = (v) => (v === null || v === undefined ? '—' : `${v}%`);
const mins = (v) => (v === null || v === undefined ? '—' : `${v} min`);
const num = (v) => (v === null || v === undefined ? '—' : v);

function shortDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function weekday(iso) {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'short' });
}

function setActiveButton() {
  document.querySelectorAll('.period-btn').forEach((b) => {
    const on = b.dataset.period === current.period && Number(b.dataset.offset) === current.offset;
    b.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  const qs = `period=${current.period}&offset=${current.offset}`;
  el('dl-summary').href = `/api/reports/download/summary?${qs}`;
  el('dl-visits').href = `/api/reports/download/visits?${qs}`;
}

function renderTrend(byDay) {
  // Label by weekday for short spans, by date once a month is in view.
  const labels = byDay.map((d) => (byDay.length > 10 ? shortDate(d.date) : weekday(d.date)));
  if (trendChart) trendChart.destroy();
  trendChart = new Chart(el('chart-trend'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{ data: byDay.map((d) => d.count), backgroundColor: '#2563EB', borderRadius: 4, maxBarThickness: 28 }]
    },
    options: {
      plugins: { legend: { display: false } },
      scales: { y: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: '#F1F5F9' } }, x: { grid: { display: false } } }
    }
  });
}

function renderTotals(t) {
  el('stat-visits').textContent = t.visits;
  el('stat-verified').textContent = pct(t.verifiedPercent);
  el('stat-duration').textContent = mins(t.avgVisitMin);
  el('stat-distance').textContent = `${t.distanceKm} km`;
  el('stat-hours').textContent = `${t.shiftHours} h`;
  el('stat-reps').textContent = t.activeReps;
}

function renderReps(reps) {
  const body = el('reps-body');
  if (!reps.length) {
    body.innerHTML = '<tr><td colspan="9" class="px-6 py-6 text-center text-slate-400">No representatives.</td></tr>';
    return;
  }
  body.innerHTML = reps.map((r) => `
    <tr class="hover:bg-slate-50 cursor-pointer" data-rep-id="${r.repId}">
      <td class="px-6 py-3 font-medium text-ink">${esc(r.repName)}</td>
      <td class="px-6 py-3 text-right font-mono">${r.visits}</td>
      <td class="px-6 py-3 text-right font-mono text-verified">${r.verified}</td>
      <td class="px-6 py-3 text-right font-mono text-pending">${r.unverified}</td>
      <td class="px-6 py-3 text-right font-mono text-slate-500">${r.inProgress}</td>
      <td class="px-6 py-3 text-right font-mono">${pct(r.verifiedPercent)}</td>
      <td class="px-6 py-3 text-right font-mono">${mins(r.avgVisitMin)}</td>
      <td class="px-6 py-3 text-right font-mono">${r.distanceKm} km</td>
      <td class="px-6 py-3 text-right font-mono">${r.shiftHours}</td>
    </tr>
  `).join('');

  body.querySelectorAll('tr[data-rep-id]').forEach((row) => {
    row.addEventListener('click', () => loadRepDetail(Number(row.dataset.repId)));
  });
}

function renderCoverage(data) {
  el('coverage-summary').textContent =
    `${data.visitedClients} of ${data.totalClients} visited · ${data.neverVisitedClients} never visited`;

  const body = el('coverage-body');
  if (!data.clients.length) {
    body.innerHTML = '<tr><td colspan="6" class="px-6 py-6 text-center text-slate-400">No active clients.</td></tr>';
    return;
  }
  body.innerHTML = data.clients.map((c) => {
    let last;
    if (c.lastVisitAt === null) {
      last = '<span class="text-pending font-medium">Never</span>';
    } else if (c.daysSinceLastVisit === 0) {
      last = 'Today';
    } else {
      last = `${c.daysSinceLastVisit} day${c.daysSinceLastVisit === 1 ? '' : 's'} ago`;
    }
    const zero = c.visits === 0 ? ' bg-amber-50/40' : '';
    return `
      <tr class="hover:bg-slate-50${zero}">
        <td class="px-6 py-3 font-medium text-ink">${esc(c.clientName)}</td>
        <td class="px-6 py-3 text-slate-500">${esc(c.address) || '—'}</td>
        <td class="px-6 py-3 text-right font-mono ${c.visits === 0 ? 'text-pending font-semibold' : ''}">${c.visits}</td>
        <td class="px-6 py-3 text-right font-mono text-verified">${c.verified}</td>
        <td class="px-6 py-3 text-slate-500">${last}</td>
        <td class="px-6 py-3 text-slate-500">${esc(c.reps.join(', ')) || '—'}</td>
      </tr>`;
  }).join('');
}

async function loadRepDetail(repId) {
  openRepId = repId;
  const panel = el('rep-detail');
  panel.classList.remove('hidden');
  el('rep-days').innerHTML = '<tr><td colspan="5" class="py-4 text-center text-slate-400">Loading…</td></tr>';
  el('rep-clients').innerHTML = '';

  try {
    const res = await fetch(`/api/reports/reps/${repId}?period=${current.period}&offset=${current.offset}`);
    const json = await res.json();
    if (!json.success) throw new Error(json.error);
    const d = json.data;

    el('rep-detail-title').textContent = `${d.repName} — ${d.label}`;

    // Days with no shift and no visits are noise in a drill-down; hide them.
    const active = d.days.filter((x) => x.visits > 0 || x.shiftHours > 0);
    el('rep-days').innerHTML = active.length
      ? active.map((x) => `
        <tr>
          <td class="py-2 text-slate-600">${shortDate(x.date)}</td>
          <td class="py-2 text-right font-mono">${x.visits}</td>
          <td class="py-2 text-right font-mono text-verified">${x.verified}</td>
          <td class="py-2 text-right font-mono">${x.distanceKm}</td>
          <td class="py-2 text-right font-mono">${x.shiftHours}</td>
        </tr>`).join('')
      : '<tr><td colspan="5" class="py-4 text-center text-slate-400">No activity in this period.</td></tr>';

    el('rep-clients').innerHTML = d.clients.length
      ? d.clients.map((c) => `
        <tr>
          <td class="py-2 text-slate-600">${esc(c.clientName)}</td>
          <td class="py-2 text-right font-mono">${c.visits}</td>
          <td class="py-2 text-right font-mono text-verified">${c.verified}</td>
          <td class="py-2 text-right text-slate-500">${c.lastVisitAt ? shortDate(c.lastVisitAt) : '—'}</td>
        </tr>`).join('')
      : '<tr><td colspan="4" class="py-4 text-center text-slate-400">No clients visited.</td></tr>';

    panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  } catch (err) {
    el('rep-days').innerHTML = `<tr><td colspan="5" class="py-4 text-center text-red-500">${esc(err.message || 'Failed to load.')}</td></tr>`;
  }
}

async function load() {
  setActiveButton();
  el('range-label').textContent = 'Loading…';

  try {
    const qs = `period=${current.period}&offset=${current.offset}`;
    const [periodRes, coverageRes] = await Promise.all([
      fetch(`/api/reports/period?${qs}`).then((r) => r.json()),
      fetch(`/api/reports/clients?${qs}`).then((r) => r.json())
    ]);

    if (!periodRes.success) throw new Error(periodRes.error);
    const report = periodRes.data;

    el('range-label').textContent = report.label;
    renderTotals(report.totals);
    renderTrend(report.visitsByDay);
    renderReps(report.reps);

    if (coverageRes.success) renderCoverage(coverageRes.data);

    // Keep an open drill-down in sync with the newly selected period.
    if (openRepId !== null) loadRepDetail(openRepId);

    const synced = el('last-synced');
    if (synced) synced.textContent = new Date().toLocaleTimeString();
  } catch (err) {
    el('range-label').textContent = err.message || 'Failed to load the report.';
    el('reps-body').innerHTML = `<tr><td colspan="9" class="px-6 py-6 text-center text-red-500">${esc(err.message || 'Failed to load.')}</td></tr>`;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.period-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      current = { period: btn.dataset.period, offset: Number(btn.dataset.offset) };
      load();
    });
  });

  el('rep-detail-close').addEventListener('click', () => {
    openRepId = null;
    el('rep-detail').classList.add('hidden');
  });

  el('refresh-btn')?.addEventListener('click', load);
  load();
});
