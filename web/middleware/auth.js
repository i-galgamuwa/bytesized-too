// Guards dashboard pages (redirect to /login) and JSON API routes (401) behind a
// server-side session, so activity/location data is never served to an
// unauthenticated request.
//
// A session is only usable while it still holds an unexpired backend JWT: without
// one every downstream call would fail at the backend anyway, so it is cheaper and
// clearer to send the manager back to the login page here.
function hasLiveSession(req) {
  if (!req.session || !req.session.user || !req.session.jwt) return false;
  // Treat a token inside its last minute as already gone, to avoid handing out a
  // token that expires mid-request.
  return !req.session.jwtExpiresAt || req.session.jwtExpiresAt - 60_000 > Date.now();
}

function requireAuth(req, res, next) {
  if (hasLiveSession(req)) return next();
  return req.session ? req.session.destroy(() => res.redirect('/login')) : res.redirect('/login');
}

function requireAuthApi(req, res, next) {
  if (hasLiveSession(req)) return next();
  return res.status(401).json({ success: false, error: 'Session expired. Please log in again.' });
}

module.exports = { requireAuth, requireAuthApi };
