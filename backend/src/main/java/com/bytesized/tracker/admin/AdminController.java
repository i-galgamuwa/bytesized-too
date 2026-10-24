package com.bytesized.tracker.admin;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.location.LivePosition;
import com.bytesized.tracker.location.LiveTrackingService;
import com.bytesized.tracker.visit.Visit;
import com.bytesized.tracker.visit.VisitDto;
import com.bytesized.tracker.visit.VisitRepository;
import com.bytesized.tracker.visit.VisitStatus;

/**
 * Single read endpoint for the web dashboard. It returns live positions, recent visits and team
 * metrics in one payload so the dashboard does not fan out across four separate API calls per
 * refresh. Live updates afterwards arrive on /api/v1/admin/stream.
 */
@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
public class AdminController {

    private static final int MAX_WINDOW_DAYS = 90;
    private static final int MAX_RECENT = 200;

    private final LiveTrackingService live;
    private final VisitRepository visits;
    private final ZoneId zone;

    public AdminController(LiveTrackingService live, VisitRepository visits,
            @Value("${app.timezone}") String timezone) {
        this.live = live;
        this.visits = visits;
        this.zone = ZoneId.of(timezone);
    }

    public record RepCount(Long repId, String repName, int count) {
    }

    public record DayCount(LocalDate date, int count) {
    }

    /** Verified, unverified and in-progress are kept separate so the caller decides what counts as pending. */
    public record Metrics(
            int totalVisits,
            int verified,
            int unverified,
            int inProgress,
            int avgDurationMinutes,
            List<RepCount> visitsPerRep,
            List<DayCount> visitsByDay) {
    }

    public record Overview(
            Instant generatedAt,
            LocalDate from,
            LocalDate to,
            List<LivePosition> liveReps,
            List<VisitDto> recentVisits,
            Metrics metrics) {
    }

    /**
     * @param days        size of the metrics window ending today, in the company timezone
     * @param recentLimit how many of the most recent visits to include
     */
    @GetMapping("/overview")
    @Transactional(readOnly = true)
    public Overview overview(
            @RequestParam(defaultValue = "7") int days,
            @RequestParam(defaultValue = "25") int recentLimit) {

        int window = Math.clamp(days, 1, MAX_WINDOW_DAYS);
        int limit = Math.clamp(recentLimit, 1, MAX_RECENT);

        LocalDate today = LocalDate.now(zone);
        LocalDate from = today.minusDays(window - 1L);
        Instant start = from.atStartOfDay(zone).toInstant();
        Instant end = today.plusDays(1).atStartOfDay(zone).toInstant();

        // search() already orders by startedAt desc, so the first n are the most recent.
        List<Visit> windowVisits = visits.search(null, null, start, end);
        List<VisitDto> recent = windowVisits.stream().limit(limit).map(VisitDto::of).toList();

        return new Overview(Instant.now(), from, today, live.current(), recent,
                metrics(windowVisits, from, today));
    }

    private Metrics metrics(List<Visit> list, LocalDate from, LocalDate to) {
        int verified = count(list, VisitStatus.VERIFIED);
        int unverified = count(list, VisitStatus.UNVERIFIED);
        int inProgress = count(list, VisitStatus.IN_PROGRESS);

        long endedCount = list.stream().filter(v -> v.getEndedAt() != null).count();
        long totalMinutes = list.stream()
                .filter(v -> v.getEndedAt() != null)
                .mapToLong(v -> Duration.between(v.getStartedAt(), v.getEndedAt()).toMinutes())
                .sum();
        int avgDuration = endedCount == 0 ? 0 : (int) Math.round((double) totalMinutes / endedCount);

        return new Metrics(list.size(), verified, unverified, inProgress, avgDuration,
                perRep(list), perDay(list, from, to));
    }

    private static List<RepCount> perRep(List<Visit> list) {
        Map<Long, RepCount> byRep = new LinkedHashMap<>();
        for (Visit v : list) {
            byRep.merge(v.getRep().getId(),
                    new RepCount(v.getRep().getId(), v.getRep().getFullName(), 1),
                    (a, b) -> new RepCount(a.repId(), a.repName(), a.count() + 1));
        }
        return byRep.values().stream()
                .sorted(Comparator.comparingInt(RepCount::count).reversed())
                .toList();
    }

    /** Every day in the window is present, including days with no visits, so the trend chart has no gaps. */
    private List<DayCount> perDay(List<Visit> list, LocalDate from, LocalDate to) {
        Map<LocalDate, Integer> counts = new LinkedHashMap<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            counts.put(d, 0);
        }
        for (Visit v : list) {
            LocalDate day = v.getStartedAt().atZone(zone).toLocalDate();
            counts.computeIfPresent(day, (k, c) -> c + 1);
        }
        List<DayCount> result = new ArrayList<>(counts.size());
        counts.forEach((date, count) -> result.add(new DayCount(date, count)));
        return result;
    }

    private static int count(List<Visit> list, VisitStatus status) {
        return (int) list.stream().filter(v -> v.getStatus() == status).count();
    }
}
