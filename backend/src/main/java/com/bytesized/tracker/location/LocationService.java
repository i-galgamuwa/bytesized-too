package com.bytesized.tracker.location;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.common.TrackingProperties;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.shift.ShiftRepository;

@Service
public class LocationService {

    private final LocationPingRepository pings;
    private final ShiftRepository shifts;
    private final LiveTrackingService live;
    private final TrackingProperties props;

    public LocationService(LocationPingRepository pings, ShiftRepository shifts, LiveTrackingService live,
            TrackingProperties props) {
        this.pings = pings;
        this.shifts = shifts;
        this.live = live;
        this.props = props;
    }

    /** One GPS fix from the phone. recordedAt defaults to now if the client omits it. */
    public record PingRequest(Double lat, Double lng, Double accuracyM, Double speedMps, Integer battery,
            Instant recordedAt) {
    }

    public record IngestResult(int accepted, int rejected, List<String> reasons) {
    }

    /**
     * Stores a batch of pings for the rep's open shift, dropping inaccurate, out-of-shift or impossible
     * (teleporting) fixes, then pushes the newest position to the live dashboard.
     */
    @Transactional
    public IngestResult ingest(Long repId, List<PingRequest> batch) {
        Shift shift = shifts.findFirstByRepIdAndEndedAtIsNull(repId)
                .orElseThrow(() -> ApiException.conflict("No active shift. Start a shift before sending locations."));
        Instant now = Instant.now();

        List<PingRequest> sorted = new ArrayList<>(batch);
        sorted.replaceAll(p -> p.recordedAt() == null
                ? new PingRequest(p.lat(), p.lng(), p.accuracyM(), p.speedMps(), p.battery(), now)
                : p);
        sorted.sort(Comparator.comparing(PingRequest::recordedAt));

        LocationPing previous = pings.findFirstByRepIdOrderByRecordedAtDesc(repId).orElse(null);
        int accepted = 0;
        List<String> reasons = new ArrayList<>();
        for (PingRequest p : sorted) {
            String problem = validate(p, previous, shift, now);
            if (problem != null) {
                reasons.add(problem);
                continue;
            }
            previous = pings.save(new LocationPing(shift.getRep(), shift, p.lat(), p.lng(), p.accuracyM(),
                    p.speedMps(), p.battery(), p.recordedAt(), now));
            accepted++;
        }
        if (accepted > 0) {
            live.broadcast(repId);
        }
        return new IngestResult(accepted, reasons.size(), reasons);
    }

    /** Records a single fix outside the batch flow (e.g. at visit start/end). Invalid fixes are ignored. */
    @Transactional
    public void recordSingle(Shift shift, double lat, double lng, Double accuracyM) {
        Instant now = Instant.now();
        PingRequest p = new PingRequest(lat, lng, accuracyM, null, null, now);
        LocationPing previous = pings.findFirstByRepIdOrderByRecordedAtDesc(shift.getRep().getId()).orElse(null);
        if (validate(p, previous, shift, now) == null) {
            pings.save(new LocationPing(shift.getRep(), shift, lat, lng, accuracyM, null, null, now, now));
        }
    }

    private String validate(PingRequest p, LocationPing previous, Shift shift, Instant now) {
        if (!GeoUtils.isValid(p.lat(), p.lng())) {
            return "invalid coordinates";
        }
        if (p.accuracyM() != null && p.accuracyM() > props.maxAccuracyM()) {
            return "accuracy " + Math.round(p.accuracyM()) + " m is worse than " + Math.round(props.maxAccuracyM()) + " m";
        }
        if (p.recordedAt().isAfter(now.plus(Duration.ofMinutes(2)))) {
            return "timestamp in the future";
        }
        if (p.recordedAt().isBefore(shift.getStartedAt().minus(Duration.ofMinutes(1)))) {
            return "recorded before the shift started";
        }
        if (previous != null) {
            long millis = Duration.between(previous.getRecordedAt(), p.recordedAt()).toMillis();
            if (millis < 0) {
                return "older than the last stored fix";
            }
            // At least 1 s, so two fixes with the same timestamp far apart still count as a jump.
            double seconds = Math.max(1.0, millis / 1000.0);
            double metres = GeoUtils.distanceMeters(previous.getLatitude(), previous.getLongitude(), p.lat(), p.lng());
            if (metres / seconds > props.maxSpeedMps()) {
                return "impossible jump (" + Math.round(metres / seconds * 3.6) + " km/h)";
            }
        }
        return null;
    }
}
