package com.bytesized.tracker.location;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.CurrentUser;
import com.bytesized.tracker.location.LocationService.IngestResult;
import com.bytesized.tracker.location.LocationService.PingRequest;

@RestController
@RequestMapping("/api/v1/locations")
@PreAuthorize("hasRole('REP')")
public class LocationController {

    private static final int MAX_BATCH = 500;

    private final LocationService service;

    public LocationController(LocationService service) {
        this.service = service;
    }

    public record BatchRequest(List<PingRequest> pings) {
    }

    /** The mobile app buffers fixes and uploads them here (every ~15-30 s, or on reconnect). */
    @PostMapping("/batch")
    public IngestResult batch(@AuthenticationPrincipal Jwt jwt, @RequestBody BatchRequest req) {
        if (req.pings() == null || req.pings().isEmpty()) {
            throw ApiException.badRequest("pings must not be empty");
        }
        if (req.pings().size() > MAX_BATCH) {
            throw ApiException.badRequest("At most " + MAX_BATCH + " pings per batch");
        }
        return service.ingest(CurrentUser.id(jwt), req.pings());
    }
}
