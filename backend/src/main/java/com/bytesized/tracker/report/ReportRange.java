package com.bytesized.tracker.report;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

import com.bytesized.tracker.common.ApiException;

/** An inclusive date range in the company timezone, plus a human label for report headers. */
public record ReportRange(LocalDate from, LocalDate to, String label) {

    private static final DateTimeFormatter DAY_LABEL = DateTimeFormatter.ofPattern("d MMM yyyy");
    private static final int MAX_DAYS = 366;

    public static ReportRange of(LocalDate from, LocalDate to) {
        if (from.isAfter(to)) {
            throw ApiException.badRequest("'from' must not be after 'to'");
        }
        if (from.plusDays(MAX_DAYS).isBefore(to)) {
            throw ApiException.badRequest("Report range must not exceed " + MAX_DAYS + " days");
        }
        String label = from.equals(to)
                ? DAY_LABEL.format(from)
                : DAY_LABEL.format(from) + " – " + DAY_LABEL.format(to);
        return new ReportRange(from, to, label);
    }

    /**
     * Resolves whichever the caller supplied: a named period, an explicit from/to, or neither
     * (today). A named period wins, so a UI can switch between the two without clearing fields.
     */
    public static ReportRange resolve(ReportPeriod period, int offset, LocalDate from, LocalDate to, ZoneId zone) {
        if (period != null) {
            if (offset < 0) {
                throw ApiException.badRequest("'offset' must not be negative");
            }
            return period.resolve(offset, zone);
        }
        LocalDate today = LocalDate.now(zone);
        LocalDate start = from != null ? from : today;
        return of(start, to != null ? to : start);
    }

    public Instant startInstant(ZoneId zone) {
        return from.atStartOfDay(zone).toInstant();
    }

    /** Exclusive upper bound, so queries can use a half-open range. */
    public Instant endInstant(ZoneId zone) {
        return to.plusDays(1).atStartOfDay(zone).toInstant();
    }

    public int days() {
        return (int) (to.toEpochDay() - from.toEpochDay()) + 1;
    }
}
