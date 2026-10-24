# ByteSized GPS Sales & Marketing Tracking System

Java (Spring Boot 4, Java 21) backend with live GPS tracking for field agents, geofenced visit
verification, and live location updates for the web dashboard (OpenStreetMap / Leaflet on the frontend).

## Run

Requirements: Java 21. Maven, a database and Docker are **not** needed (Maven wrapper + embedded H2).

```bash
cd backend
./mvnw spring-boot:run        # Windows: mvnw.cmd spring-boot:run
```

The API is served at http://localhost:8080/api/v1. Demo data is created on first start (stored in `backend/data/`,
delete that folder to reset).

| Username | Password | Role |
|---|---|---|
| manager | manager123 | MANAGER (dashboard) |
| rep1, rep2, rep3 | rep123 | REP (agent app simulator) |
| admin | admin123 | ADMIN |

**Demo pages:** local-only test pages (`src/main/resources/static/`: login, manager dashboard, agent simulator)
are gitignored and not part of this repository. Without them, test the API with curl/Postman using the endpoints below.

H2 console: http://localhost:8080/h2-console (JDBC URL `jdbc:h2:file:./data/tracker`, user `sa`, no password).

### PostgreSQL instead of H2

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres
```
with `DB_URL`, `DB_USER`, `DB_PASSWORD` environment variables. Set `JWT_SECRET` (32+ chars) for any real deployment.

## How it works

```
Agent phone ──POST /locations/batch──▶ Spring Boot ──save──▶ DB
                                          │
                                          └──WebSocket /topic/locations──▶ Manager dashboard (Leaflet + OSM)
```

- **Shifts are the privacy boundary.** Locations are rejected unless the agent has an open shift; the
  dashboard only shows positions from the current shift. Raw GPS points are deleted after 90 days (`RetentionJob`).
- **Ping validation:** drops fixes with accuracy worse than 100 m, future timestamps, and impossible jumps (> 250 km/h).
- **Visit verification:** a visit is `VERIFIED` when both the start and end positions are inside the client's
  geofence radius (allowing up to 30 m of GPS error), otherwise `UNVERIFIED`.
- **Live status:** `ACTIVE`, `ON_VISIT`, `STALE` (no fix for 5 min), `OFF_SHIFT`.
- **Geocoding:** OpenStreetMap Nominatim, limited to Sri Lanka, throttled to 1 request/s. Address coverage in
  Sri Lanka is limited, so clients can also be placed by dropping a pin on the map.

All thresholds are in `src/main/resources/application.properties` (`app.tracking.*`).

## API (`/api/v1`, JSON, `Authorization: Bearer <token>`)

| Method & path | Role | Purpose |
|---|---|---|
| `POST /auth/login` | – | `{username, password}` → `{token, user}` |
| `GET /users/me` | any | Current user |
| `GET /users?role=REP` | MANAGER | List agents |
| `POST /users` | ADMIN | Create user |
| `POST /shifts/start`, `POST /shifts/end`, `GET /shifts/current` | REP | Shift on/off |
| `POST /locations/batch` | REP | `{pings:[{lat,lng,accuracyM,speedMps,battery,recordedAt}]}` |
| `POST /visits/start` | REP | `{clientId, lat, lng, accuracyM}` |
| `POST /visits/{id}/end` | REP | `{lat, lng, accuracyM, notes}` |
| `GET /visits/current`, `GET /visits/mine?date=` | REP | Agent's visits |
| `GET /visits?from=&to=&repId=&status=` | MANAGER | Visit log |
| `GET /clients`, `GET /clients/nearby?lat=&lng=` | any | Clients |
| `POST /clients`, `PUT /clients/{id}`, `DELETE /clients/{id}` | MANAGER | `{name, address, lat, lng, radiusM}` (address is geocoded if lat/lng omitted) |
| `GET /geocode/search?q=` | any | Address search (Nominatim) |
| `GET /tracking/live` | MANAGER | Snapshot of agents on shift |
| `GET /tracking/reps/{id}/route?date=` | MANAGER | Day's GPS path, distance, visits |
| `GET /reports/summary?from=&to=` | MANAGER | Per-agent visits, verified %, avg duration, km, shift hours |
| `GET /reports/period?period=&offset=` | MANAGER | A whole week/month: team totals, per-agent rows, daily series |
| `GET /reports/reps/{id}?period=&offset=` | MANAGER | One agent in depth: totals, a row per day, clients reached |
| `GET /reports/clients?period=&offset=` | MANAGER | Account coverage: who was visited, who was missed, days since last visit |
| `GET /reports/summary.csv?period=&offset=` | MANAGER | Per-agent summary CSV |
| `GET /reports/visits.csv?period=&offset=` | MANAGER | Visit log CSV |

### Reporting windows

Every `/reports` endpoint takes its window in one of two ways, and a named period wins if both
are given:

- `period=DAY|WEEK|MONTH` with `offset` counting backwards — `0` is the current period, `1` the
  previous one. So `?period=WEEK&offset=1` is last week and `?period=MONTH&offset=0` is this month.
- `from=YYYY-MM-DD&to=YYYY-MM-DD`, inclusive, defaulting to today.

Weeks are ISO weeks (Monday to Sunday); months are calendar months; all day boundaries use
`app.timezone`. Ranges are capped at 366 days, and `from` after `to` is rejected with 400.

`/reports/clients` lists active clients that were **never** visited as well as those missed in the
window, sorted least-covered first — that ordering is the point of the report.
| `GET /admin/overview?days=&recentLimit=` | MANAGER | Live positions, recent visits and team metrics in one payload |
| `GET /admin/stream` | MANAGER | SSE feed of `position` and `visit` events |

### Web dashboard endpoints (`/admin`)

The web dashboard reads from `/admin/overview` for its first paint and then holds
`/admin/stream` open for updates, so a refresh costs one request instead of four.

`/admin/stream` is Server-Sent Events rather than STOMP, because the dashboard server
consumes it from Node where an event stream needs no client library. It emits the same
two payloads the STOMP topics carry:

```
event: position   data: LivePosition   (shift start/end, accepted ping batch, visit start/end)
event: visit      data: VisitDto       (visit start and end)
```

Both transports stay in sync automatically: `SseBridgeConfig` intercepts the STOMP broker
channel, so anything published to `/topic/locations` or `/topic/visits` is mirrored to SSE
without `LiveTrackingService` or `VisitService` knowing a second transport exists.

**WebSocket (STOMP):** connect to `ws://host:8080/ws` with STOMP header `Authorization: Bearer <token>`
(manager/admin only), subscribe to `/topic/locations` and `/topic/visits`.

## Building the Android (Java) app against this API

- Run tracking in a **foreground service** (persistent notification) using `FusedLocationProviderClient`
  with an interval of 15–30 s; request `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION`.
- Buffer fixes in a local Room/SQLite table and upload with `POST /locations/batch`; on network errors keep
  them and retry. On HTTP 409 (no shift) stop tracking.
- Upload the buffer before calling `/visits/start` or `/visits/{id}/end`, so fixes arrive in time order.
- Show the map with **osmdroid** (OpenStreetMap), no API key needed.

## Project layout

```
src/main/java/com/bytesized/tracker/
  auth/ user/ client/ shift/ location/ visit/ report/ geocoding/ config/ common/
src/main/resources/application*.properties
```
