package com.bytesized.tracker.location;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.common.TrackingProperties;
import com.bytesized.tracker.location.LivePosition.LiveStatus;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.shift.ShiftRepository;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;
import com.bytesized.tracker.visit.Visit;
import com.bytesized.tracker.visit.VisitRepository;
import com.bytesized.tracker.visit.VisitStatus;

/** Builds the live view of reps on shift and pushes changes to managers over WebSocket. */
@Service
public class LiveTrackingService {

    public static final String LOCATIONS_TOPIC = "/topic/locations";

    private final ShiftRepository shifts;
    private final LocationPingRepository pings;
    private final VisitRepository visits;
    private final UserRepository users;
    private final SimpMessagingTemplate messaging;
    private final TrackingProperties props;

    public LiveTrackingService(ShiftRepository shifts, LocationPingRepository pings, VisitRepository visits,
            UserRepository users, SimpMessagingTemplate messaging, TrackingProperties props) {
        this.shifts = shifts;
        this.pings = pings;
        this.visits = visits;
        this.users = users;
        this.messaging = messaging;
        this.props = props;
    }

    /** Snapshot of every rep currently on shift. */
    @Transactional(readOnly = true)
    public List<LivePosition> current() {
        return shifts.findAllOpen().stream()
                .map(s -> build(s.getRep(), Optional.of(s)))
                .sorted(Comparator.comparing(LivePosition::repName))
                .toList();
    }

    /** Pushes the rep's current state (position, visit, or OFF_SHIFT) to all subscribed dashboards. */
    @Transactional(readOnly = true)
    public void broadcast(Long repId) {
        User rep = users.findById(repId).orElseThrow();
        messaging.convertAndSend(LOCATIONS_TOPIC, build(rep, shifts.findFirstByRepIdAndEndedAtIsNull(repId)));
    }

    private LivePosition build(User rep, Optional<Shift> shift) {
        LocationPing last = pings.findFirstByRepIdOrderByRecordedAtDesc(rep.getId()).orElse(null);
        Visit visit = visits.findFirstByRepIdAndStatus(rep.getId(), VisitStatus.IN_PROGRESS).orElse(null);

        LiveStatus status;
        if (shift.isEmpty()) {
            status = LiveStatus.OFF_SHIFT;
        } else if (visit != null) {
            status = LiveStatus.ON_VISIT;
        } else if (last == null || last.getRecordedAt().isBefore(shift.get().getStartedAt())
                || Duration.between(last.getRecordedAt(), Instant.now()).toMinutes() >= props.staleAfterMinutes()) {
            status = LiveStatus.STALE;
        } else {
            status = LiveStatus.ACTIVE;
        }
        // Only expose positions captured during the current shift.
        boolean showPosition = last != null && shift.isPresent()
                && !last.getRecordedAt().isBefore(shift.get().getStartedAt());
        return new LivePosition(
                rep.getId(),
                rep.getFullName(),
                status,
                showPosition ? last.getLatitude() : null,
                showPosition ? last.getLongitude() : null,
                showPosition ? last.getAccuracyM() : null,
                showPosition ? last.getSpeedMps() : null,
                showPosition ? last.getBattery() : null,
                showPosition ? last.getRecordedAt() : null,
                shift.map(Shift::getStartedAt).orElse(null),
                visit == null ? null : visit.getId(),
                visit == null ? null : visit.getClient().getName());
    }
}
