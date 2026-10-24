package com.bytesized.tracker.visit;

import java.time.Instant;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.assignment.AssignmentService;
import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.client.ClientService;
import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.common.TrackingProperties;
import com.bytesized.tracker.location.LiveTrackingService;
import com.bytesized.tracker.location.LocationService;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.shift.ShiftRepository;

@Service
public class VisitService {

    public static final String VISITS_TOPIC = "/topic/visits";

    private final VisitRepository visits;
    private final ShiftRepository shifts;
    private final ClientService clients;
    private final LocationService locations;
    private final LiveTrackingService live;
    private final SimpMessagingTemplate messaging;
    private final TrackingProperties props;
    private final AssignmentService assignments;

    public VisitService(VisitRepository visits, ShiftRepository shifts, ClientService clients,
            LocationService locations, LiveTrackingService live, SimpMessagingTemplate messaging,
            TrackingProperties props, AssignmentService assignments) {
        this.visits = visits;
        this.shifts = shifts;
        this.clients = clients;
        this.locations = locations;
        this.live = live;
        this.messaging = messaging;
        this.props = props;
        this.assignments = assignments;
    }

    public record StartVisitRequest(Long clientId, Double lat, Double lng, Double accuracyM) {
    }

    public record EndVisitRequest(Double lat, Double lng, Double accuracyM, String notes) {
    }

    @Transactional
    public VisitDto start(Long repId, StartVisitRequest req) {
        requireFix(req.lat(), req.lng());
        Shift shift = openShift(repId);
        if (visits.findFirstByRepIdAndStatus(repId, VisitStatus.IN_PROGRESS).isPresent()) {
            throw ApiException.conflict("A visit is already in progress. End it first.");
        }
        if (req.clientId() == null) {
            throw ApiException.badRequest("clientId is required");
        }
        Client client = clients.get(req.clientId());
        double distance = distanceTo(client, req.lat(), req.lng());
        Visit visit = visits.save(new Visit(shift.getRep(), client, shift, Instant.now(), req.lat(), req.lng(),
                req.accuracyM(), distance));
        locations.recordSingle(shift, req.lat(), req.lng(), req.accuracyM());
        // Closes the matching scheduled visit, if this rep was planned to be here today.
        assignments.linkVisit(visit);
        return publish(visit);
    }

    @Transactional
    public VisitDto end(Long repId, Long visitId, EndVisitRequest req) {
        requireFix(req.lat(), req.lng());
        Visit visit = visits.findById(visitId)
                .filter(v -> v.getRep().getId().equals(repId))
                .orElseThrow(() -> ApiException.notFound("Visit"));
        if (visit.getStatus() != VisitStatus.IN_PROGRESS) {
            throw ApiException.conflict("Visit already ended");
        }
        double endDistance = distanceTo(visit.getClient(), req.lat(), req.lng());
        boolean verified = isInside(visit.getClient(), visit.getStartDistanceM(), visit.getStartAccuracyM())
                && isInside(visit.getClient(), endDistance, req.accuracyM());
        visit.end(Instant.now(), req.lat(), req.lng(), req.accuracyM(), endDistance,
                verified ? VisitStatus.VERIFIED : VisitStatus.UNVERIFIED, req.notes());
        locations.recordSingle(visit.getShift(), req.lat(), req.lng(), req.accuracyM());
        return publish(visit);
    }

    /**
     * Inside the geofence if the distance is within the radius, allowing for GPS error up to the configured
     * tolerance (so a 25 m-accurate fix 110 m away from a 100 m fence still counts).
     */
    private boolean isInside(Client client, double distanceM, Double accuracyM) {
        double tolerance = accuracyM == null ? 0 : Math.min(accuracyM, props.accuracyToleranceM());
        return distanceM - tolerance <= client.getRadiusM();
    }

    private static double distanceTo(Client client, double lat, double lng) {
        return GeoUtils.distanceMeters(lat, lng, client.getLatitude(), client.getLongitude());
    }

    private Shift openShift(Long repId) {
        return shifts.findFirstByRepIdAndEndedAtIsNull(repId)
                .orElseThrow(() -> ApiException.conflict("Start your shift before starting a visit"));
    }

    private static void requireFix(Double lat, Double lng) {
        if (!GeoUtils.isValid(lat, lng)) {
            throw ApiException.badRequest("A valid GPS position (lat/lng) is required");
        }
    }

    private VisitDto publish(Visit visit) {
        visits.flush();
        VisitDto dto = VisitDto.of(visit);
        messaging.convertAndSend(VISITS_TOPIC, dto);
        live.broadcast(visit.getRep().getId());
        return dto;
    }
}
