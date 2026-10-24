package com.bytesized.tracker.location;

import java.time.Instant;

/** Payload for GET /tracking/live and the /topic/locations WebSocket topic. lat/lng are null before the first fix. */
public record LivePosition(
        Long repId,
        String repName,
        LiveStatus status,
        Double lat,
        Double lng,
        Double accuracyM,
        Double speedMps,
        Integer battery,
        Instant recordedAt,
        Instant shiftStartedAt,
        Long activeVisitId,
        String activeClientName) {

    public enum LiveStatus {
        /** On shift, recent fix. */
        ACTIVE,
        /** On shift, inside a started visit. */
        ON_VISIT,
        /** On shift but no fix within the stale threshold (app killed, no signal, no data). */
        STALE,
        /** Shift ended; the dashboard should remove the marker. */
        OFF_SHIFT
    }
}
