package com.bytesized.tracker.shift;

import java.time.Instant;

public record ShiftDto(Long id, Long repId, Instant startedAt, Instant endedAt) {

    public static ShiftDto of(Shift s) {
        return new ShiftDto(s.getId(), s.getRep().getId(), s.getStartedAt(), s.getEndedAt());
    }
}
