// Team Metrics page: stat cards + three Chart.js charts fed by
// GET /api/metrics/summary.
Chart.defaults.font.family = "'IBM Plex Sans', sans-serif";
Chart.defaults.color = '#64748B';

function fmtMinutes(mins) {
  return `${mins} min`;
}

function renderPerRepChart(data) {
  new Chart(document.getElementById('chart-per-rep'), {
    type: 'bar',
    data: {
      labels: data.map((d) => d.name),
      datasets: [{ data: data.map((d) => d.count), backgroundColor: '#2563EB', borderRadius: 4, maxBarThickness: 36 }]
    },
    options: {
      plugins: { legend: { display: false } },
      scales: {
        y: { beginAtZero: true, grid: { color: '#F1F5F9' } },
        x: { grid: { display: false } }
      }
    }
  });
}

function renderVerifiedChart(verified, unverified) {
  new Chart(document.getElementById('chart-verified'), {
    type: 'doughnut',
    data: {
      labels: ['Verified', 'Pending'],
      datasets: [{ data: [verified, unverified], backgroundColor: ['#0D9488', '#D97706'], borderWidth: 0 }]
    },
    options: { cutout: '65%', plugins: { legend: { position: 'bottom' } } }
  });
}

function renderTrendChart(data) {
  new Chart(document.getElementById('chart-trend'), {
    type: 'line',
    data: {
      labels: data.map((d) => new Date(d.date).toLocaleDateString('en-US', { weekday: 'short' })),
      datasets: [{
        data: data.map((d) => d.count),
        borderColor: '#2563EB',
        backgroundColor: 'rgba(37, 99, 235, 0.08)',
        fill: true,
        tension: 0.3,
        pointRadius: 3
      }]
    },
    options: {
      plugins: { legend: { display: false } },
      scales: {
        y: { beginAtZero: true, grid: { color: '#F1F5F9' } },
        x: { grid: { display: false } }
      }
    }
  });
}

async function loadMetrics() {
  try {
    const res = await fetch('/api/metrics/summary');
    const json = await res.json();
    if (!json.success) throw new Error('Request failed');
    const s = json.data;

    document.getElementById('stat-total').textContent = s.totalVisits;
    document.getElementById('stat-duration').textContent = fmtMinutes(s.avgDurationMinutes);
    const rate = s.totalVisits ? Math.round((s.verifiedCount / s.totalVisits) * 100) : 0;
    document.getElementById('stat-verified').textContent = `${rate}%`;
    document.getElementById('stat-reps').textContent = s.visitsPerRep.length;

    renderPerRepChart(s.visitsPerRep);
    renderVerifiedChart(s.verifiedCount, s.unverifiedCount);
    renderTrendChart(s.visitsByDay);
  } catch (err) {
    console.error('Failed to load metrics', err);
  }
}

document.addEventListener('DOMContentLoaded', loadMetrics);
