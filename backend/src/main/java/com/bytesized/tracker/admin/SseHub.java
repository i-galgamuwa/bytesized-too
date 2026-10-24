package com.bytesized.tracker.admin;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Fans live tracking events out to dashboard clients over Server-Sent Events. SSE is used rather than
 * STOMP here because the dashboard server consumes this from Node, where an event stream needs no
 * client library, and because this direction is read-only.
 */
@Component
public class SseHub {

    private static final Logger log = LoggerFactory.getLogger(SseHub.class);

    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    public SseEmitter register(long timeoutMillis) {
        SseEmitter emitter = new SseEmitter(timeoutMillis);
        emitters.add(emitter);
        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onError(e -> emitters.remove(emitter));
        emitter.onTimeout(() -> {
            emitters.remove(emitter);
            emitter.complete();
        });
        // An immediate event so the client knows the stream is open rather than merely connecting.
        if (!send(emitter, SseEmitter.event().name("ready").data("{}", MediaType.APPLICATION_JSON))) {
            return emitter;
        }
        log.debug("Dashboard stream opened, {} subscriber(s)", emitters.size());
        return emitter;
    }

    /** @param json a payload that is already serialised, forwarded verbatim. */
    public void publish(String event, String json) {
        if (emitters.isEmpty()) {
            return;
        }
        SseEmitter.SseEventBuilder built = SseEmitter.event().name(event).data(json, MediaType.APPLICATION_JSON);
        emitters.forEach(emitter -> send(emitter, built));
    }

    /** Keeps idle streams open through proxies that drop quiet connections. */
    @Scheduled(fixedRate = 20_000)
    public void heartbeat() {
        if (emitters.isEmpty()) {
            return;
        }
        SseEmitter.SseEventBuilder ping = SseEmitter.event().comment("ping");
        emitters.forEach(emitter -> send(emitter, ping));
    }

    public int subscriberCount() {
        return emitters.size();
    }

    /** A failed send means the client is gone; drop it rather than letting it accumulate. */
    private boolean send(SseEmitter emitter, SseEmitter.SseEventBuilder event) {
        try {
            emitter.send(event);
            return true;
        } catch (Exception e) {
            emitters.remove(emitter);
            emitter.completeWithError(e);
            return false;
        }
    }
}
