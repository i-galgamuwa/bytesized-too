# API Contract: Mobile App to Backend

## Overview
This document specifies the REST API contract between the `app` Flutter application and the `web/backend` Spring Boot server.

### Base URL
- Production: `https://<domain>/api/v1`
- Local testing: `http://10.0.2.2:8080/api/v1` (Android Emulator) / `http://localhost:8080/api/v1` (iOS Simulator)

### Authentication
All endpoints except `/auth/login` require an `Authorization` header:
`Authorization: Bearer <jwt_token>`

## 1. Authentication (`AuthController`)

### `POST /auth/login`
**Request Body:**
```json
{
  "username": "rep1",
  "password": "password"
}
```
**Response (200 OK):**
```json
{
  "token": "ey...",
  "expiresInSeconds": 86400,
  "user": {
    "id": 1,
    "username": "rep1",
    "fullName": "Alice Anderson",
    "role": "REP",
    "active": true
  }
}
```

## 2. User Profile (`UserController`)

### `GET /users/me`
**Response (200 OK):**
```json
{
  "id": 1,
  "username": "rep1",
  "fullName": "Alice Anderson",
  "role": "REP",
  "active": true
}
```

## 3. Shift Management (`ShiftController`)

### `GET /shifts/current`
Returns the active shift, or `204 No Content` if none is active.
**Response (200 OK):**
```json
{
  "id": 100,
  "repId": 1,
  "startedAt": "2023-10-27T08:00:00Z",
  "endedAt": null
}
```

### `POST /shifts/start`
Starts a new shift (or returns the current one).
**Response (200 OK):**
```json
{
  "id": 100,
  "repId": 1,
  "startedAt": "2023-10-27T08:00:00Z",
  "endedAt": null
}
```

### `POST /shifts/end`
Ends the current shift.
**Response (200 OK):**
```json
{
  "id": 100,
  "repId": 1,
  "startedAt": "2023-10-27T08:00:00Z",
  "endedAt": "2023-10-27T17:00:00Z"
}
```

## 4. Location Tracking (`LocationController`)

### `POST /locations/batch`
Uploads batched location points during an active shift.
**Request Body (`BatchRequest`):**
```json
{
  "pings": [
    {
      "lat": 37.7749,
      "lng": -122.4194,
      "accuracyM": 5.2,
      "speedMps": 12.5,
      "battery": 85,
      "recordedAt": "2023-10-27T10:15:30Z"
    }
  ]
}
```
**Response (200 OK - `IngestResult`):**
```json
{
  "accepted": 1,
  "rejected": 0,
  "reasons": []
}
```

## 5. Clients and Visits (`ClientController`, `VisitController`)

### `GET /clients`
Fetches all available clients.
**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "Acme Corp",
    "address": "123 Main St",
    "lat": 37.7749,
    "lng": -122.4194,
    "radiusM": 100,
    "distanceM": null
  }
]
```

### `POST /visits/start`
Starts a visit.
**Request Body (`StartVisitRequest`):**
```json
{
  "clientId": 1,
  "lat": 37.7749,
  "lng": -122.4194,
  "accuracyM": 5.0
}
```
**Response (200 OK - `VisitDto`):**
```json
{
  "id": 50,
  "repId": 1,
  "clientId": 1,
  "shiftId": 100,
  "status": "IN_PROGRESS",
  "startedAt": "2023-10-27T10:20:00Z",
  "endedAt": null,
  "startLat": 37.7749,
  "startLng": -122.4194,
  "endLat": null,
  "endLng": null,
  "startAccuracyM": 5.0,
  "endAccuracyM": null,
  "startDistanceM": 10.5,
  "endDistanceM": null,
  "notes": null
}
```

### `POST /visits/{id}/end`
Ends an ongoing visit.
**Request Body (`EndVisitRequest`):**
```json
{
  "lat": 37.7750,
  "lng": -122.4195,
  "accuracyM": 6.0,
  "notes": "Met with John. Signed contract."
}
```
**Response (200 OK - `VisitDto`):**
```json
{
  "id": 50,
  "repId": 1,
  "clientId": 1,
  "shiftId": 100,
  "status": "VERIFIED",
  "startedAt": "2023-10-27T10:20:00Z",
  "endedAt": "2023-10-27T11:00:00Z",
  "startLat": 37.7749,
  "startLng": -122.4194,
  "endLat": 37.7750,
  "endLng": -122.4195,
  "startAccuracyM": 5.0,
  "endAccuracyM": 6.0,
  "startDistanceM": 10.5,
  "endDistanceM": 12.0,
  "notes": "Met with John. Signed contract."
}
```

### `GET /visits/current`
Fetches the currently active visit, or `204 No Content` if none.

### `GET /visits/mine`
Fetches today's visits for the current rep.

## 6. Schedule (`AssignmentController`)

### `GET /assignments/mine`
Fetches the current rep's assigned schedule for today.
**Response (200 OK):**
```json
[
  {
    "id": 10,
    "repId": 1,
    "repName": "Alice Anderson",
    "clientId": 1,
    "clientName": "Acme Corp",
    "clientAddress": "123 Main St",
    "clientLat": 37.7749,
    "clientLng": -122.4194,
    "clientRadiusM": 100,
    "scheduledDate": "2023-10-27",
    "scheduledTime": "10:00:00",
    "priority": "HIGH",
    "note": "Quarterly review",
    "status": "PENDING",
    "visitId": null,
    "completedAt": null,
    "assignedBy": "Manager Mike"
  }
]
```
