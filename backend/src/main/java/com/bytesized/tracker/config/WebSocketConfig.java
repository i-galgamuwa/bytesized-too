package com.bytesized.tracker.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * STOMP over WebSocket. Managers connect to /ws with an "Authorization: Bearer <jwt>" STOMP header
 * and subscribe to /topic/locations (live rep positions) and /topic/visits (visit start/end events).
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final JwtDecoder jwtDecoder;
    private final Converter<Jwt, AbstractAuthenticationToken> jwtAuthenticationConverter;

    public WebSocketConfig(JwtDecoder jwtDecoder, Converter<Jwt, AbstractAuthenticationToken> jwtAuthenticationConverter) {
        this.jwtDecoder = jwtDecoder;
        this.jwtAuthenticationConverter = jwtAuthenticationConverter;
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws").setAllowedOriginPatterns("*");
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        // /topic is the managers' broadcast feed; /queue carries per-user messages, which the
        // broker addresses by principal name once prefixed with /user.
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) {
                    return message;
                }
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    accessor.setUser(authenticate(accessor.getFirstNativeHeader("Authorization")));
                } else if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
                    if (!(accessor.getUser() instanceof Authentication auth)) {
                        throw new IllegalArgumentException("Not authenticated");
                    }
                    String destination = accessor.getDestination();
                    // Per-user queues are safe for anyone: Spring rewrites /user/** to the
                    // subscriber's own principal, so a rep can only ever receive their own.
                    // The broadcast topics expose the whole team, so those stay manager-only.
                    boolean personal = destination != null && destination.startsWith("/user/");
                    if (!personal && !isManager(auth)) {
                        throw new IllegalArgumentException("Only managers can subscribe to live tracking");
                    }
                }
                return message;
            }
        });
    }

    private Authentication authenticate(String header) {
        if (header == null || !header.startsWith("Bearer ")) {
            throw new IllegalArgumentException("Missing bearer token");
        }
        try {
            Jwt jwt = jwtDecoder.decode(header.substring(7));
            return jwtAuthenticationConverter.convert(jwt);
        } catch (JwtException e) {
            throw new IllegalArgumentException("Invalid token");
        }
    }

    private static boolean isManager(Authentication auth) {
        return auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .anyMatch(a -> a.equals("ROLE_MANAGER") || a.equals("ROLE_ADMIN"));
    }
}
