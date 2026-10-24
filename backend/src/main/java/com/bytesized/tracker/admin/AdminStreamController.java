package com.bytesized.tracker.admin;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Live event stream for the web dashboard. Emits two named events, mirroring the STOMP topics the
 * mobile-facing side already publishes:
 *
 * <pre>
 * event: position   data: LivePosition   (shift start/end, accepted ping batch, visit start/end)
 * event: visit      data: VisitDto       (visit start and end)
 * </pre>
 */
@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
public class AdminStreamController {

    /** Clients are expected to reconnect; a bounded stream stops dead connections living forever. */
    private static final long STREAM_TIMEOUT_MS = 30 * 60 * 1000L;

    private final SseHub hub;

    public AdminStreamController(SseHub hub) {
        this.hub = hub;
    }

    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        return hub.register(STREAM_TIMEOUT_MS);
    }
}
