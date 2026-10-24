# TrackPoint — GPS Sales & Marketing Tracking Dashboard

Management dashboard for the ByteSized GPS tracking system. Managers see field
representatives' live GPS positions, review visit logs, and track team metrics.

This app holds **no data of its own**. It is a presentation layer over the
ByteSized backend API (`../backend`, Spring Boot) and reads everything from it.

## Architecture

```
browser ──session cookie──▶ Express (this app) ──JWT──▶ Spring Boot backend ──▶ H2 / PostgreSQL
   ▲                             │
   └────── SSE /api/stream ◀──────┘ relays the backend's /admin/stream
```

Two properties follow from the browser never talking to the backend directly:

- **The JWT never reaches the browser.** It is obtained at login and kept in the
  Express session; page JavaScript only ever calls this app's own `/api/*`.
- **The backend needs no CORS configuration**, because every cross-service call is
  server-to-server.

## Tech stack

| Layer      | Choice                                                      |
|------------|-------------------------------------------------------------|
| Server     | Node.js 18+ and Express                                      |
| Templating | EJS                                                          |
| Data       | ByteSized backend REST API (no local database)               |
| Live data  | Server-Sent Events, relayed from the backend                 |
| Styling    | Tailwind CSS (CDN build)                                     |
| Map        | Leaflet.js + OpenStreetMap tiles                             |
| Charts     | Chart.js                                                     |
| Auth       | `express-session`; credentials verified by the backend       |

## Running it

The backend must be running first:

```bash
cd ../backend && ./mvnw spring-boot:run     # Windows: mvnw.cmd spring-boot:run
```

Then:

```bash
cp .env.example .env     # set SESSION_SECRET, and BACKEND_URL if not localhost:8080
npm install
npm run dev
```

Open http://localhost:3000 and sign in with a backend account. There are no
dashboard-local accounts: credentials go to `POST /api/v1/auth/login`, and only
`MANAGER` and `ADMIN` roles are admitted. With the backend's demo seed that means
`manager` / `manager123`.

## Project structure

```
server.js                     # Express app entry point
services/backendClient.js     # HTTP client for the backend API (timeouts, errors)
services/trackingService.js   # The only place backend shapes are mapped to view shapes
middleware/auth.js            # Session guards; also expires a session with a dead JWT
routes/
  pages.js                    # /login, /dashboard, /activity-logs, /team-metrics
  api.js                      # /api/locations/live, /logs, /reps, /metrics/summary,
                              # /overview, and the /api/stream SSE relay
views/                        # EJS templates
public/js/                    # live-map (EventSource), activity-logs, team-metrics
```

## How the backend maps onto this dashboard

| This app                   | Backend endpoint                        |
|----------------------------|------------------------------------------|
| `GET /api/locations/live`  | `GET /api/v1/tracking/live`              |
| `GET /api/logs`            | `GET /api/v1/visits?from=&to=&repId=`    |
| `GET /api/reps`            | `GET /api/v1/users?role=REP`             |
| `GET /api/metrics/summary` | `GET /api/v1/admin/overview`             |
| `GET /api/overview`        | `GET /api/v1/admin/overview`             |
| `GET /api/stream`          | `GET /api/v1/admin/stream` (SSE)         |

Three translation rules live in `services/trackingService.js`:

- **Status.** The backend has four live states (`ACTIVE`, `ON_VISIT`, `STALE`,
  `OFF_SHIFT`); the map only needs `active` or `idle`. `ON_VISIT` counts as active.
- **Positions without a fix.** `lat`/`lng` are `null` until the first GPS fix of a
  shift lands. Those are dropped rather than plotted at `(null, null)`.
- **Visit status.** The backend distinguishes `VERIFIED`, `UNVERIFIED` and
  `IN_PROGRESS`. An open visit is shown as "In progress", not as a failed
  verification, and its duration renders as a dash rather than `0 min`.

Two columns have no backend equivalent and are rendered as an em dash:
**Activity type** (the backend models visits, not visit categories). **Address**
is not on `VisitDto`, so it is resolved from `GET /api/v1/clients` and cached for
five minutes.
