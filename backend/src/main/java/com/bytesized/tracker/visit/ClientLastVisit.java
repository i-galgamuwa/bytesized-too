package com.bytesized.tracker.visit;

import java.time.Instant;

/** Projection for "when was each client last visited", across all time. */
public record ClientLastVisit(Long clientId, Instant lastVisitAt) {
}
