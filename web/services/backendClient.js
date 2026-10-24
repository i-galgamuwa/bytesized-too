// Thin HTTP client for the ByteSized backend API.
//
// Every call is made server-side from Express carrying the signed-in manager's JWT.
// Two consequences worth keeping in mind before changing this:
//   - the browser never sees the token, so it cannot be stolen from page JS, and
//   - the backend needs no CORS configuration, because no browser talks to it directly.
const BACKEND_URL = (process.env.BACKEND_URL || 'http://localhost:8080').replace(/\/+$/, '');
const API = `${BACKEND_URL}/api/v1`;
const DEFAULT_TIMEOUT_MS = Number(process.env.BACKEND_TIMEOUT_MS) || 10000;

class BackendError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'BackendError';
    this.status = status;
  }
}

function parseBody(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return { detail: text.slice(0, 200) };
  }
}

async function request(path, { token, method = 'GET', body, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(`${API}${path}`, {
      method,
      headers: {
        Accept: 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {})
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal
    });

    if (res.status === 204) return null;
    const data = parseBody(await res.text());

    if (!res.ok) {
      // The backend returns RFC 7807 problem details, so `detail` carries the useful message.
      throw new BackendError(data?.detail || `Backend returned ${res.status}`, res.status);
    }
    return data;
  } catch (err) {
    if (err.name === 'AbortError') {
      throw new BackendError('The backend did not respond in time.', 504);
    }
    if (err instanceof BackendError) throw err;
    throw new BackendError(`Cannot reach the backend at ${BACKEND_URL}.`, 503);
  } finally {
    clearTimeout(timer);
  }
}

/** Exchanges dashboard credentials for a backend JWT. Throws BackendError(401) on bad credentials. */
function login(username, password) {
  return request('/auth/login', { method: 'POST', body: { username, password } });
}

const get = (path, token) => request(path, { token });
const post = (path, body, token) => request(path, { token, method: 'POST', body });
const put = (path, body, token) => request(path, { token, method: 'PUT', body });
const del = (path, token) => request(path, { token, method: 'DELETE' });

module.exports = {
  BackendError,
  login,
  get,
  post,
  put,
  del,
  backendUrl: BACKEND_URL,
  streamUrl: `${API}/admin/stream`
};
