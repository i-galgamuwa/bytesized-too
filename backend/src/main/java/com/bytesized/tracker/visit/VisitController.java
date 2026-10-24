package com.bytesized.tracker.visit;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.CurrentUser;
import com.bytesized.tracker.visit.VisitService.EndVisitRequest;
import com.bytesized.tracker.visit.VisitService.StartVisitRequest;

@RestController
@RequestMapping("/api/v1/visits")
public class VisitController {

    private final VisitService service;
    private final VisitRepository visits;
    private final ZoneId zone;

    public VisitController(VisitService service, VisitRepository visits, @Value("${app.timezone}") String timezone) {
        this.service = service;
        this.visits = visits;
        this.zone = ZoneId.of(timezone);
    }

    @PostMapping("/start")
    @PreAuthorize("hasRole('REP')")
    public VisitDto start(@AuthenticationPrincipal Jwt jwt, @RequestBody StartVisitRequest req) {
        return service.start(CurrentUser.id(jwt), req);
    }

    @PostMapping("/{id}/end")
    @PreAuthorize("hasRole('REP')")
    public VisitDto end(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id, @RequestBody EndVisitRequest req) {
        return service.end(CurrentUser.id(jwt), id, req);
    }

    @GetMapping("/current")
    @PreAuthorize("hasRole('REP')")
    public ResponseEntity<VisitDto> current(@AuthenticationPrincipal Jwt jwt) {
        return visits.findFirstByRepIdAndStatus(CurrentUser.id(jwt), VisitStatus.IN_PROGRESS)
                .map(v -> ResponseEntity.ok(VisitDto.of(v)))
                .orElse(ResponseEntity.noContent().build());
    }

    /** The rep's own visits for a day (default today). */
    @GetMapping("/mine")
    @PreAuthorize("hasRole('REP')")
    public List<VisitDto> mine(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate day = date != null ? date : LocalDate.now(zone);
        return search(CurrentUser.id(jwt), null, day, day);
    }

    /** Manager search. from/to are inclusive dates in the company timezone (default today). */
    @GetMapping
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public List<VisitDto> list(
            @RequestParam(required = false) Long repId,
            @RequestParam(required = false) VisitStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate today = LocalDate.now(zone);
        return search(repId, status, from != null ? from : today, to != null ? to : today);
    }

    private List<VisitDto> search(Long repId, VisitStatus status, LocalDate from, LocalDate to) {
        return visits.search(repId, status, from.atStartOfDay(zone).toInstant(),
                to.plusDays(1).atStartOfDay(zone).toInstant()).stream().map(VisitDto::of).toList();
    }
}
