package com.bytesized.tracker.visit;

import java.time.Duration;
import java.time.Instant;

public record VisitDto(
        Long id,
        Long repId,
        String repName,
        Long clientId,
        String clientName,
        double clientLat,
        double clientLng,
        int clientRadiusM,
        Instant startedAt,
        double startLat,
        double startLng,
        long startDistanceM,
        Instant endedAt,
        Double endLat,
        Double endLng,
        Long endDistanceM,
        Long durationMin,
        VisitStatus status,
        String notes) {

    public static VisitDto of(Visit v) {
        return new VisitDto(
                v.getId(),
                v.getRep().getId(),
                v.getRep().getFullName(),
                v.getClient().getId(),
                v.getClient().getName(),
                v.getClient().getLatitude(),
                v.getClient().getLongitude(),
                v.getClient().getRadiusM(),
                v.getStartedAt(),
                v.getStartLat(),
                v.getStartLng(),
                Math.round(v.getStartDistanceM()),
                v.getEndedAt(),
                v.getEndLat(),
                v.getEndLng(),
                v.getEndDistanceM() == null ? null : Math.round(v.getEndDistanceM()),
                v.getEndedAt() == null ? null : Duration.between(v.getStartedAt(), v.getEndedAt()).toMinutes(),
                v.getStatus(),
                v.getNotes());
    }
}
