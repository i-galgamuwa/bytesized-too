package com.bytesized.tracker.admin;

import java.nio.charset.StandardCharsets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.support.AbstractSubscribableChannel;
import org.springframework.messaging.support.ChannelInterceptor;

import com.bytesized.tracker.location.LiveTrackingService;
import com.bytesized.tracker.visit.VisitService;

import jakarta.annotation.PostConstruct;
import tools.jackson.databind.ObjectMapper;

/**
 * Mirrors everything the server publishes to the STOMP topics onto the dashboard SSE stream.
 *
 * <p>Intercepting the broker channel rather than calling {@link SseHub} from the services keeps this
 * bridge entirely additive: {@code LiveTrackingService} and {@code VisitService} are untouched and
 * stay unaware that a second transport exists. Every {@code convertAndSend} the application makes
 * passes through this channel, whether or not a STOMP client is currently connected.
 */
@Configuration
public class SseBridgeConfig {

    private static final Logger log = LoggerFactory.getLogger(SseBridgeConfig.class);

    private final SseHub hub;
    private final ObjectMapper objectMapper;
    private final AbstractSubscribableChannel brokerChannel;

    public SseBridgeConfig(SseHub hub, ObjectMapper objectMapper,
            @Qualifier("brokerChannel") AbstractSubscribableChannel brokerChannel) {
        this.hub = hub;
        this.objectMapper = objectMapper;
        this.brokerChannel = brokerChannel;
    }

    @PostConstruct
    void bridge() {
        brokerChannel.addInterceptor(new ChannelInterceptor() {
            @Override
            public void postSend(Message<?> message, MessageChannel channel, boolean sent) {
                if (!sent) {
                    return;
                }
                try {
                    relay(message);
                } catch (Exception e) {
                    // The STOMP push already succeeded; a broken mirror must not break it.
                    log.warn("Could not relay message to the dashboard stream: {}", e.getMessage());
                }
            }
        });
        log.info("Dashboard SSE bridge attached to the STOMP broker channel");
    }

    private void relay(Message<?> message) {
        String destination = SimpMessageHeaderAccessor.getDestination(message.getHeaders());
        if (destination == null) {
            return;
        }
        String event = switch (destination) {
            case LiveTrackingService.LOCATIONS_TOPIC -> "position";
            case VisitService.VISITS_TOPIC -> "visit";
            default -> null;
        };
        if (event != null) {
            hub.publish(event, asJson(message.getPayload()));
        }
    }

    /** The broker converts payloads to JSON bytes before this point, so normally no work is needed. */
    private String asJson(Object payload) {
        if (payload instanceof byte[] bytes) {
            return new String(bytes, StandardCharsets.UTF_8);
        }
        if (payload instanceof String s) {
            return s;
        }
        return objectMapper.writeValueAsString(payload);
    }
}
