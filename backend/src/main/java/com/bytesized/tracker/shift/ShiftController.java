package com.bytesized.tracker.shift;

import java.time.Instant;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.CurrentUser;
import com.bytesized.tracker.location.LiveTrackingService;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;
import com.bytesized.tracker.visit.VisitRepository;
import com.bytesized.tracker.visit.VisitStatus;

@RestController
@RequestMapping("/api/v1/shifts")
@PreAuthorize("hasRole('REP')")
public class ShiftController {

    private final ShiftRepository shifts;
    private final UserRepository users;
    private final VisitRepository visits;
    private final LiveTrackingService live;

    public ShiftController(ShiftRepository shifts, UserRepository users, VisitRepository visits, LiveTrackingService live) {
        this.shifts = shifts;
        this.users = users;
        this.visits = visits;
        this.live = live;
    }

    @GetMapping("/current")
    public ResponseEntity<ShiftDto> current(@AuthenticationPrincipal Jwt jwt) {
        return shifts.findFirstByRepIdAndEndedAtIsNull(CurrentUser.id(jwt))
                .map(s -> ResponseEntity.ok(ShiftDto.of(s)))
                .orElse(ResponseEntity.noContent().build());
    }

    /** Starts tracking. Idempotent: returns the open shift if one exists. */
    @PostMapping("/start")
    @Transactional
    public ShiftDto start(@AuthenticationPrincipal Jwt jwt) {
        Long repId = CurrentUser.id(jwt);
        Shift shift = shifts.findFirstByRepIdAndEndedAtIsNull(repId).orElseGet(() -> {
            User rep = users.getReferenceById(repId);
            return shifts.save(new Shift(rep, Instant.now()));
        });
        live.broadcast(repId);
        return ShiftDto.of(shift);
    }

    /** Stops tracking. The rep must end any in-progress visit first. */
    @PostMapping("/end")
    @Transactional
    public ShiftDto end(@AuthenticationPrincipal Jwt jwt) {
        Long repId = CurrentUser.id(jwt);
        Shift shift = shifts.findFirstByRepIdAndEndedAtIsNull(repId)
                .orElseThrow(() -> ApiException.conflict("No active shift"));
        if (visits.findFirstByRepIdAndStatus(repId, VisitStatus.IN_PROGRESS).isPresent()) {
            throw ApiException.conflict("End the current visit before ending the shift");
        }
        shift.setEndedAt(Instant.now());
        shifts.flush();
        live.broadcast(repId);
        return ShiftDto.of(shift);
    }
}
