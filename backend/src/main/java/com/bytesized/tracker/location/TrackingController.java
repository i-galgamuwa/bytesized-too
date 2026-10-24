package com.bytesized.tracker.location;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.visit.VisitDto;
import com.bytesized.tracker.visit.VisitRepository;

@RestController
@RequestMapping("/api/v1/tracking")
@PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
public class TrackingController {

    private final LiveTrackingService live;
    private final LocationPingRepository pings;
    private final VisitRepository visits;
    private final ZoneId zone;

    public TrackingController(LiveTrackingService live, LocationPingRepository pings, VisitRepository visits,
            @Value("${app.timezone}") String timezone) {
        this.live = live;
        this.pings = pings;
        this.visits = visits;
        this.zone = ZoneId.of(timezone);
    }

    public record RoutePoint(double lat, double lng, Double accuracyM, java.time.Instant recordedAt) {
    }

    public record Route(Long repId, LocalDate date, double distanceKm, List<RoutePoint> points, List<VisitDto> visits) {
    }

    /** Initial snapshot for the dashboard; afterwards it listens on /topic/locations. */
    @GetMapping("/live")
    public List<LivePosition> live() {
        return live.current();
    }

    /** The rep's path for one day (in the company timezone), for drawing a polyline. */
    @GetMapping("/reps/{repId}/route")
    public Route route(@PathVariable Long repId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate day = date != null ? date : LocalDate.now(zone);
        var from = day.atStartOfDay(zone).toInstant();
        var to = day.plusDays(1).atStartOfDay(zone).toInstant();
        List<LocationPing> list = pings.findByRepIdAndRecordedAtBetweenOrderByRecordedAtAsc(repId, from, to);
        double metres = 0;
        for (int i = 1; i < list.size(); i++) {
            LocationPing a = list.get(i - 1);
            LocationPing b = list.get(i);
            metres += GeoUtils.distanceMeters(a.getLatitude(), a.getLongitude(), b.getLatitude(), b.getLongitude());
        }
        List<RoutePoint> points = list.stream()
                .map(p -> new RoutePoint(p.getLatitude(), p.getLongitude(), p.getAccuracyM(), p.getRecordedAt()))
                .toList();
        List<VisitDto> dayVisits = visits.search(repId, null, from, to).stream().map(VisitDto::of).toList();
        return new Route(repId, day, Math.round(metres / 10) / 100.0, points, dayVisits);
    }
}
