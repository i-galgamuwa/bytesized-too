package com.bytesized.tracker.report;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.WeekFields;

/**
 * A reporting window a manager can ask for by name instead of computing dates.
 * {@code offset} counts periods backwards: 0 is the current one, 1 the previous, and so on.
 */
public enum ReportPeriod {

    DAY,
    /** ISO week, Monday to Sunday. */
    WEEK,
    MONTH;

    private static final DateTimeFormatter DAY_LABEL = DateTimeFormatter.ofPattern("d MMM yyyy");
    private static final DateTimeFormatter MONTH_LABEL = DateTimeFormatter.ofPattern("MMMM yyyy");

    public ReportRange resolve(int offset, ZoneId zone) {
        LocalDate today = LocalDate.now(zone);
        return switch (this) {
            case DAY -> {
                LocalDate day = today.minusDays(offset);
                yield new ReportRange(day, day, DAY_LABEL.format(day));
            }
            case WEEK -> {
                LocalDate start = today.minusWeeks(offset)
                        .with(WeekFields.ISO.dayOfWeek(), 1);
                LocalDate end = start.plusDays(6);
                yield new ReportRange(start, end, weekLabel(start));
            }
            case MONTH -> {
                LocalDate start = today.minusMonths(offset).withDayOfMonth(1);
                yield new ReportRange(start, start.plusMonths(1).minusDays(1), MONTH_LABEL.format(start));
            }
        };
    }

    private static String weekLabel(LocalDate start) {
        int week = start.get(WeekFields.ISO.weekOfWeekBasedYear());
        int year = start.get(WeekFields.ISO.weekBasedYear());
        return "Week %d, %d (%s – %s)".formatted(week, year,
                DAY_LABEL.format(start), DAY_LABEL.format(start.plusDays(6)));
    }
}
