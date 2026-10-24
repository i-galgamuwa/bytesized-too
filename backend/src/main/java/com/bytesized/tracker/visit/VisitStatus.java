package com.bytesized.tracker.visit;

public enum VisitStatus {
    /** Started, not yet ended. */
    IN_PROGRESS,
    /** Start and end positions were both inside the client's geofence. */
    VERIFIED,
    /** Start or end position was outside the geofence. */
    UNVERIFIED
}
