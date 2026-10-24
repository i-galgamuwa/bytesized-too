package com.bytesized.tracker.report;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalDouble;
import java.util.TreeSet;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.client.ClientRepository;
import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.location.LocationPing;
import com.bytesized.tracker.location.LocationPingRepository;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.shift.ShiftRepository;
import com.bytesized.tracker.user.Role;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;
import com.bytesized.tracker.visit.ClientLastVisit;
import com.bytesized.tracker.visit.Visit;
import com.bytesized.tracker.visit.VisitRepository;
import com.bytesized.tracker.visit.VisitStatus;

/**
 * All reporting aggregation. Every report endpoint delegates here so that a metric such as
 * "verified percent" has exactly one definition, rather than drifting between the daily summary,
 * the weekly report and the CSV export.
 */
@Service
public class ReportService {

    private final UserRepository users;
    private final VisitRepository visits;
    private final LocationPingRepository pings;
    private final ShiftRepository shifts;
    private final ClientRepository clients;
    private final ZoneId zone;

    public ReportService(UserRepository users, VisitRepository visits, LocationPingRepository pings,
            ShiftRepository shifts, ClientRepository clients, @Value("${app.timezone}") String timezone) {
        this.users = users;
        this.visits = visits;
        this.pings = pings;
        this.shifts = shifts;
        this.clients = clients;
        this.zone = ZoneId.of(timezone);
    }

    public ZoneId zone() {
        return zone;
    }

    // --- shapes --------------------------------------------------------------

    public record RepSummary(
            Long repId,
            String repName,
            int visits,
            int verified,
            int unverified,
            int inProgress,
            Double verifiedPercent,
            Double avgVisitMin,
            double distanceKm,
            double shiftHours) {
    }

    public record DayCount(LocalDate date, int count) {
    }

    public record DayRow(
            LocalDate date,
            int visits,
            int verified,
            int unverified,
            int inProgress,
            double distanceKm,
            double shiftHours) {
    }

    public record ClientVisits(Long clientId, String clientName, int visits, int verified, Instant lastVisitAt) {
    }

    public record RepDetail(
            Long repId,
            String repName,
            LocalDate from,
            LocalDate to,
            String label,
            RepSummary totals,
            List<DayRow> days,
            List<ClientVisits> clients) {
    }

    public record Totals(
            int visits,
            int verified,
            int unverified,
            int inProgress,
            Double verifiedPercent,
            Double avgVisitMin,
            double distanceKm,
            double shiftHours,
            int activeReps) {
    }

    public record PeriodReport(
            ReportPeriod period,
            LocalDate from,
            LocalDate to,
            String label,
            Totals totals,
            List<RepSummary> reps,
            List<DayCount> visitsByDay) {
    }

    public record ClientCoverage(
            Long clientId,
            String clientName,
            String address,
            int visits,
            int verified,
            Instant lastVisitAt,
            Long daysSinceLastVisit,
            List<String> reps) {
    }

    public record CoverageReport(
            LocalDate from,
            LocalDate to,
            String label,
            int totalClients,
            int visitedClients,
            int neverVisitedClients,
            List<ClientCoverage> clients) {
    }

    // --- reports -------------------------------------------------------------

    /** Per-rep rows for a range. Visits are fetched once and grouped, rather than once per rep. */
    @Transactional(readOnly = true)
    public List<RepSummary> repSummaries(ReportRange range) {
        Instant start = range.startInstant(zone);
        Instant end = range.endInstant(zone);
        Map<Long, List<Visit>> byRep = visitsByRep(start, end);

        List<RepSummary> rows = new ArrayList<>();
        for (User rep : users.findByRoleOrderByFullName(Role.REP)) {
            rows.add(summaryFor(rep, byRep.getOrDefault(rep.getId(), List.of()), start, end));
        }
        return rows;
    }

    @Transactional(readOnly = true)
    public PeriodReport periodReport(ReportPeriod period, ReportRange range) {
        List<RepSummary> reps = repSummaries(range);
        Instant start = range.startInstant(zone);
        Instant end = range.endInstant(zone);
        List<Visit> all = visits.search(null, null, start, end);

        int verified = (int) all.stream().filter(v -> v.getStatus() == VisitStatus.VERIFIED).count();
        int unverified = (int) all.stream().filter(v -> v.getStatus() == VisitStatus.UNVERIFIED).count();
        int inProgress = (int) all.stream().filter(v -> v.getStatus() == VisitStatus.IN_PROGRESS).count();
        int completed = verified + unverified;

        OptionalDouble avg = all.stream()
                .filter(v -> v.getEndedAt() != null)
                .mapToLong(v -> Duration.between(v.getStartedAt(), v.getEndedAt()).toMinutes())
                .average();

        Totals totals = new Totals(
                all.size(), verified, unverified, inProgress,
                completed == 0 ? null : round1(100.0 * verified / completed),
                avg.isPresent() ? round1(avg.getAsDouble()) : null,
                round1(reps.stream().mapToDouble(RepSummary::distanceKm).sum()),
                round1(reps.stream().mapToDouble(RepSummary::shiftHours).sum()),
                (int) reps.stream().filter(r -> r.visits() > 0 || r.shiftHours() > 0).count());

        return new PeriodReport(period, range.from(), range.to(), range.label(), totals, reps,
                visitsByDay(all, range));
    }

    /** One rep in depth: totals, a row per day, and which clients they actually reached. */
    @Transactional(readOnly = true)
    public RepDetail repDetail(Long repId, ReportRange range) {
        User rep = users.findById(repId)
                .filter(u -> u.getRole() == Role.REP)
                .orElseThrow(() -> ApiException.notFound("Representative"));

        Instant start = range.startInstant(zone);
        Instant end = range.endInstant(zone);
        List<Visit> repVisits = visits.search(repId, null, start, end);
        List<LocationPing> repPings = pings.findByRepIdAndRecordedAtBetweenOrderByRecordedAtAsc(repId, start, end);
        List<Shift> repShifts = shifts.findOverlapping(repId, start, end);

        // Group once, then slice per day in memory: a 31-day report stays at three queries.
        Map<LocalDate, List<Visit>> visitsPerDay = groupByDay(repVisits, v -> v.getStartedAt());
        Map<LocalDate, List<LocationPing>> pingsPerDay = groupByDay(repPings, LocationPing::getRecordedAt);

        List<DayRow> days = new ArrayList<>(range.days());
        for (LocalDate d = range.from(); !d.isAfter(range.to()); d = d.plusDays(1)) {
            List<Visit> dv = visitsPerDay.getOrDefault(d, List.of());
            Instant dayStart = d.atStartOfDay(zone).toInstant();
            Instant dayEnd = d.plusDays(1).atStartOfDay(zone).toInstant();
            days.add(new DayRow(d,
                    dv.size(),
                    count(dv, VisitStatus.VERIFIED),
                    count(dv, VisitStatus.UNVERIFIED),
                    count(dv, VisitStatus.IN_PROGRESS),
                    round1(distanceKm(pingsPerDay.getOrDefault(d, List.of()))),
                    round1(shiftHours(repShifts, dayStart, dayEnd))));
        }

        Map<Long, List<Visit>> byClient = repVisits.stream()
                .collect(Collectors.groupingBy(v -> v.getClient().getId(), LinkedHashMap::new, Collectors.toList()));
        List<ClientVisits> clientRows = byClient.values().stream()
                .map(list -> new ClientVisits(
                        list.get(0).getClient().getId(),
                        list.get(0).getClient().getName(),
                        list.size(),
                        count(list, VisitStatus.VERIFIED),
                        list.stream().map(Visit::getStartedAt).max(Instant::compareTo).orElse(null)))
                .sorted(Comparator.comparingInt(ClientVisits::visits).reversed())
                .toList();

        return new RepDetail(rep.getId(), rep.getFullName(), range.from(), range.to(), range.label(),
                summaryFor(rep, repVisits, start, end), days, clientRows);
    }

    /**
     * Which accounts were reached in the window and which were not. Never-visited and long-neglected
     * clients are the point of this report, so inactive-free clients are listed even with zero visits.
     */
    @Transactional(readOnly = true)
    public CoverageReport clientCoverage(ReportRange range) {
        Instant start = range.startInstant(zone);
        Instant end = range.endInstant(zone);
        List<Visit> windowVisits = visits.search(null, null, start, end);

        Map<Long, List<Visit>> byClient = windowVisits.stream()
                .collect(Collectors.groupingBy(v -> v.getClient().getId()));
        Map<Long, Instant> lastEver = visits.lastVisitPerClient().stream()
                .filter(l -> l.lastVisitAt() != null)
                .collect(Collectors.toMap(ClientLastVisit::clientId, ClientLastVisit::lastVisitAt));

        Instant now = Instant.now();
        List<ClientCoverage> rows = new ArrayList<>();
        for (Client c : clients.findByActiveTrueOrderByName()) {
            List<Visit> list = byClient.getOrDefault(c.getId(), List.of());
            Instant last = lastEver.get(c.getId());
            rows.add(new ClientCoverage(
                    c.getId(),
                    c.getName(),
                    c.getAddress(),
                    list.size(),
                    count(list, VisitStatus.VERIFIED),
                    last,
                    last == null ? null : Duration.between(last, now).toDays(),
                    list.stream().map(v -> v.getRep().getFullName())
                            .collect(Collectors.toCollection(TreeSet::new)).stream().toList()));
        }
        // Least-covered first: that is the list a manager needs to act on.
        rows.sort(Comparator.comparingInt(ClientCoverage::visits)
                .thenComparing(c -> c.lastVisitAt() == null ? Instant.EPOCH : c.lastVisitAt()));

        return new CoverageReport(range.from(), range.to(), range.label(), rows.size(),
                (int) rows.stream().filter(r -> r.visits() > 0).count(),
                (int) rows.stream().filter(r -> r.lastVisitAt() == null).count(),
                rows);
    }

    // --- CSV -----------------------------------------------------------------

    public String summaryCsv(ReportRange range) {
        StringBuilder csv = new StringBuilder("Representative,Visits,Verified,Unverified,In progress,"
                + "Verified %,Avg visit (min),Distance (km),Shift hours\n");
        for (RepSummary r : repSummaries(range)) {
            csv.append(escape(r.repName())).append(',')
                    .append(r.visits()).append(',')
                    .append(r.verified()).append(',')
                    .append(r.unverified()).append(',')
                    .append(r.inProgress()).append(',')
                    .append(r.verifiedPercent() == null ? "" : r.verifiedPercent()).append(',')
                    .append(r.avgVisitMin() == null ? "" : r.avgVisitMin()).append(',')
                    .append(r.distanceKm()).append(',')
                    .append(r.shiftHours()).append('\n');
        }
        return csv.toString();
    }

    /**
     * CSV quoting, plus a guard against formula injection: a field starting with = + - or @ is
     * executed by Excel on open, so it is prefixed to force it to be read as text.
     */
    public static String escape(String s) {
        if (s == null) {
            return "";
        }
        String safe = s.matches("^[=+\\-@].*") ? "'" + s : s;
        return "\"" + safe.replace("\"", "\"\"") + "\"";
    }

    // --- internals -----------------------------------------------------------

    private Map<Long, List<Visit>> visitsByRep(Instant start, Instant end) {
        return visits.search(null, null, start, end).stream()
                .collect(Collectors.groupingBy(v -> v.getRep().getId()));
    }

    private RepSummary summaryFor(User rep, List<Visit> repVisits, Instant start, Instant end) {
        int verified = count(repVisits, VisitStatus.VERIFIED);
        int unverified = count(repVisits, VisitStatus.UNVERIFIED);
        int completed = verified + unverified;
        OptionalDouble avg = repVisits.stream()
                .filter(v -> v.getEndedAt() != null)
                .mapToLong(v -> Duration.between(v.getStartedAt(), v.getEndedAt()).toMinutes())
                .average();

        return new RepSummary(
                rep.getId(),
                rep.getFullName(),
                repVisits.size(),
                verified,
                unverified,
                count(repVisits, VisitStatus.IN_PROGRESS),
                completed == 0 ? null : round1(100.0 * verified / completed),
                avg.isPresent() ? round1(avg.getAsDouble()) : null,
                round1(distanceKm(pings.findByRepIdAndRecordedAtBetweenOrderByRecordedAtAsc(rep.getId(), start, end))),
                round1(shiftHours(shifts.findOverlapping(rep.getId(), start, end), start, end)));
    }

    private List<DayCount> visitsByDay(List<Visit> list, ReportRange range) {
        Map<LocalDate, Integer> counts = new LinkedHashMap<>();
        for (LocalDate d = range.from(); !d.isAfter(range.to()); d = d.plusDays(1)) {
            counts.put(d, 0);
        }
        for (Visit v : list) {
            counts.computeIfPresent(v.getStartedAt().atZone(zone).toLocalDate(), (k, c) -> c + 1);
        }
        List<DayCount> out = new ArrayList<>(counts.size());
        counts.forEach((date, count) -> out.add(new DayCount(date, count)));
        return out;
    }

    private <T> Map<LocalDate, List<T>> groupByDay(List<T> items, java.util.function.Function<T, Instant> at) {
        Map<LocalDate, List<T>> map = new HashMap<>();
        for (T item : items) {
            map.computeIfAbsent(at.apply(item).atZone(zone).toLocalDate(), k -> new ArrayList<>()).add(item);
        }
        return map;
    }

    private static int count(List<Visit> list, VisitStatus status) {
        return (int) list.stream().filter(v -> v.getStatus() == status).count();
    }

    private static double distanceKm(List<LocationPing> list) {
        double metres = 0;
        for (int i = 1; i < list.size(); i++) {
            LocationPing a = list.get(i - 1);
            LocationPing b = list.get(i);
            metres += GeoUtils.distanceMeters(a.getLatitude(), a.getLongitude(), b.getLatitude(), b.getLongitude());
        }
        return metres / 1000;
    }

    /** Shift time clipped to the window, so a shift spanning midnight counts toward both days. */
    private static double shiftHours(List<Shift> list, Instant from, Instant to) {
        long seconds = 0;
        for (Shift s : list) {
            Instant a = s.getStartedAt().isBefore(from) ? from : s.getStartedAt();
            Instant end = s.getEndedAt() == null ? Instant.now() : s.getEndedAt();
            Instant b = end.isAfter(to) ? to : end;
            if (b.isAfter(a)) {
                seconds += Duration.between(a, b).toSeconds();
            }
        }
        return seconds / 3600.0;
    }

    private static double round1(double v) {
        return Math.round(v * 10) / 10.0;
    }
}
