package com.bytesized.tracker.assignment;

public enum AssignmentStatus {
    /** Planned, not yet fulfilled. */
    PENDING,
    /** A real visit was logged at this client on the scheduled day. */
    COMPLETED,
    /** The scheduled day passed with no visit. */
    MISSED,
    /** Withdrawn by a manager before it was due. */
    CANCELLED
}
