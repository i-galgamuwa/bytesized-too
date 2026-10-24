package com.bytesized.tracker.report;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.report.ReportService.CoverageReport;
import com.bytesized.tracker.report.ReportService.PeriodReport;
import com.bytesized.tracker.report.ReportService.RepDetail;
import com.bytesized.tracker.report.ReportService.RepSummary;
import com.bytesized.tracker.visit.Visit;
import com.bytesized.tracker.visit.VisitRepository;

/**
 * Manager reporting.
 *
 * <p>Every endpoint accepts a window in one of two ways: a named {@code period} (DAY, WEEK, MONTH)
 * with an {@code offset} counting backwards from the current one, or an explicit {@code from}/{@code to}
 * pair. A named period wins when both are supplied. Dates are inclusive and in the company timezone.
 */
@RestController
@RequestMapping("/api/v1/reports")
@PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
public class ReportController {

    private static final DateTimeFormatter CSV_TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    private final ReportService reports;
    private final VisitRepository visits;
    private final ZoneId zone;

    public ReportController(ReportService reports, VisitRepository visits) {
        this.reports = reports;
        this.visits = visits;
        this.zone = reports.zone();
    }

    public record Summary(LocalDate from, LocalDate to, List<RepSummary> reps) {
    }

    /** Per-rep metrics for the date range (inclusive, company timezone). Defaults to today. */
    @GetMapping("/summary")
    public Summary summary(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        ReportRange range = ReportRange.resolve(null, 0, from, to, zone);
        return new Summary(range.from(), range.to(), reports.repSummaries(range));
    }

    /**
     * A whole reporting period in one call: team totals, a row per rep, and a daily visit series.
     * {@code GET /reports/period?period=WEEK&offset=1} is "last week".
     */
    @GetMapping("/period")
    public PeriodReport period(
            @RequestParam(defaultValue = "WEEK") ReportPeriod period,
            @RequestParam(defaultValue = "0") int offset) {
        return reports.periodReport(period, ReportRange.resolve(period, offset, null, null, zone));
    }

    /** One rep in depth: totals, a row per day, and the clients they actually reached. */
    @GetMapping("/reps/{repId}")
    public RepDetail rep(
            @PathVariable Long repId,
            @RequestParam(required = false) ReportPeriod period,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return reports.repDetail(repId, ReportRange.resolve(period, offset, from, to, zone));
    }

    /** Account coverage: who was visited, who was missed, and how long since each was last seen. */
    @GetMapping("/clients")
    public CoverageReport clients(
            @RequestParam(required = false) ReportPeriod period,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return reports.clientCoverage(ReportRange.resolve(period, offset, from, to, zone));
    }

    /** Per-rep summary as CSV, for the same windows the JSON reports accept. */
    @GetMapping(value = "/summary.csv", produces = "text/csv")
    public ResponseEntity<String> summaryCsv(
            @RequestParam(required = false) ReportPeriod period,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        ReportRange range = ReportRange.resolve(period, offset, from, to, zone);
        return csv(reports.summaryCsv(range), "team-summary-" + range.from() + "-to-" + range.to() + ".csv");
    }

    /** Visit log as CSV for Excel. */
    @GetMapping(value = "/visits.csv", produces = "text/csv")
    @Transactional(readOnly = true)
    public ResponseEntity<String> visitsCsv(
            @RequestParam(required = false) ReportPeriod period,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        ReportRange range = ReportRange.resolve(period, offset, from, to, zone);
        List<Visit> list = visits.search(null, null, range.startInstant(zone), range.endInstant(zone));

        StringBuilder csv = new StringBuilder(
                "Visit ID,Rep,Client,Started,Ended,Duration (min),Start distance (m),End distance (m),Status,Notes\n");
        for (Visit v : list) {
            csv.append(v.getId()).append(',')
                    .append(ReportService.escape(v.getRep().getFullName())).append(',')
                    .append(ReportService.escape(v.getClient().getName())).append(',')
                    .append(format(v.getStartedAt())).append(',')
                    .append(format(v.getEndedAt())).append(',')
                    .append(v.getEndedAt() == null ? "" : Duration.between(v.getStartedAt(), v.getEndedAt()).toMinutes()).append(',')
                    .append(Math.round(v.getStartDistanceM())).append(',')
                    .append(v.getEndDistanceM() == null ? "" : Math.round(v.getEndDistanceM())).append(',')
                    .append(v.getStatus()).append(',')
                    .append(ReportService.escape(v.getNotes())).append('\n');
        }
        return csv(csv.toString(), "visits-" + range.from() + "-to-" + range.to() + ".csv");
    }

    private static ResponseEntity<String> csv(String body, String filename) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(body);
    }

    private String format(java.time.Instant instant) {
        return instant == null ? "" : CSV_TIME.format(instant.atZone(zone));
    }
}
