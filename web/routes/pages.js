const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const backend = require('../services/backendClient');

// Kept in front of the backend's own login. The backend does not rate limit /auth/login,
// so this is the only brake on credential stuffing against the dashboard.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please try again in a few minutes.' }
});

// Only these roles may see other people's positions, and the backend enforces the
// same rule on every call — this check just fails early with a clearer message.
const DASHBOARD_ROLES = new Set(['MANAGER', 'ADMIN']);

router.get('/', (req, res) => {
  res.redirect(req.session.user ? '/dashboard' : '/login');
});

router.get('/login', (req, res) => {
  if (req.session.user) return res.redirect('/dashboard');
  res.render('login', { error: null });
});

router.post('/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body;

  try {
    const auth = await backend.login(username, password);

    if (!DASHBOARD_ROLES.has(auth.user.role)) {
      return res.status(403).render('login', {
        error: 'This account is not a manager account. Ask an administrator for access.'
      });
    }

    // The JWT lives in the server-side session only; it is never sent to the browser.
    req.session.user = {
      id: auth.user.id,
      username: auth.user.username,
      fullName: auth.user.fullName,
      role: auth.user.role
    };
    req.session.jwt = auth.token;
    req.session.jwtExpiresAt = Date.now() + auth.expiresInSeconds * 1000;

    return res.redirect('/dashboard');
  } catch (err) {
    if (err.status === 401) {
      return res.status(401).render('login', { error: 'Invalid username or password.' });
    }
    if (err.status === 503 || err.status === 504) {
      return res.status(503).render('login', {
        error: 'The tracking backend is unavailable. Please try again shortly.'
      });
    }
    console.error('Login failed:', err.message);
    return res.status(500).render('login', { error: 'Something went wrong. Please try again.' });
  }
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login'));
});

router.get('/dashboard', requireAuth, (req, res) => {
  res.render('dashboard', { active: 'live-map' });
});

router.get('/activity-logs', requireAuth, (req, res) => {
  res.render('activity-logs', { active: 'activity-logs' });
});

router.get('/team-metrics', requireAuth, (req, res) => {
  res.render('team-metrics', { active: 'team-metrics' });
});

router.get('/reports', requireAuth, (req, res) => {
  res.render('reports', { active: 'reports' });
});

router.get('/schedule', requireAuth, (req, res) => {
  res.render('schedule', { active: 'schedule' });
});

router.get('/customers', requireAuth, (req, res) => {
  res.render('customers', { active: 'customers' });
});

module.exports = router;
