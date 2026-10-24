package com.bytesized.tracker.assignment;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Flattened for both audiences: the rep app needs the client's coordinates and geofence to
 * navigate and to start the visit, and the dashboard needs the rep's name to lay out a schedule.
 */
public record AssignmentDto(
        Long id,
        Long repId,
        String repName,
        Long clientId,
        String clientName,
        String clientAddress,
        double clientLat,
        double clientLng,
        int clientRadiusM,
        LocalDate scheduledDate,
        LocalTime scheduledTime,
        AssignmentPriority priority,
        String note,
        AssignmentStatus status,
        Long visitId,
        Instant completedAt,
        String assignedBy) {

    public static AssignmentDto of(Assignment a) {
        return new AssignmentDto(
                a.getId(),
                a.getRep().getId(),
                a.getRep().getFullName(),
                a.getClient().getId(),
                a.getClient().getName(),
                a.getClient().getAddress(),
                a.getClient().getLatitude(),
                a.getClient().getLongitude(),
                a.getClient().getRadiusM(),
                a.getScheduledDate(),
                a.getScheduledTime(),
                a.getPriority(),
                a.getNote(),
                a.getStatus(),
                a.getVisit() == null ? null : a.getVisit().getId(),
                a.getCompletedAt(),
                a.getCreatedBy() == null ? null : a.getCreatedBy().getFullName());
    }
}
