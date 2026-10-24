package com.bytesized.tracker.assignment;

import java.time.LocalDate;
import java.util.List;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.assignment.AssignmentService.BulkCreateRequest;
import com.bytesized.tracker.assignment.AssignmentService.CreateRequest;
import com.bytesized.tracker.assignment.AssignmentService.RescheduleRequest;
import com.bytesized.tracker.common.CurrentUser;

/**
 * Scheduling visits. Managers plan them; reps read their own and fulfil them by logging a real
 * visit, which closes the assignment automatically.
 */
@RestController
@RequestMapping("/api/v1/assignments")
public class AssignmentController {

    private final AssignmentService service;

    public AssignmentController(AssignmentService service) {
        this.service = service;
    }

    // --- rep -----------------------------------------------------------------

    /** The signed-in rep's schedule for a day, defaulting to today. */
    @GetMapping("/mine")
    @PreAuthorize("hasRole('REP')")
    public List<AssignmentDto> mine(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.forRepOn(CurrentUser.id(jwt), date);
    }

    // --- manager -------------------------------------------------------------

    @GetMapping
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public List<AssignmentDto> list(
            @RequestParam(required = false) Long repId,
            @RequestParam(required = false) AssignmentStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return service.search(repId, status, from, to);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public AssignmentDto create(@AuthenticationPrincipal Jwt jwt, @RequestBody CreateRequest req) {
        return service.create(req, CurrentUser.id(jwt));
    }

    /** Assigns a whole route to one rep for one day. */
    @PostMapping("/bulk")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public List<AssignmentDto> createBulk(@AuthenticationPrincipal Jwt jwt, @RequestBody BulkCreateRequest req) {
        return service.createBulk(req, CurrentUser.id(jwt));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public AssignmentDto reschedule(@PathVariable Long id, @RequestBody RescheduleRequest req) {
        return service.reschedule(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public void cancel(@PathVariable Long id) {
        service.cancel(id);
    }
}
