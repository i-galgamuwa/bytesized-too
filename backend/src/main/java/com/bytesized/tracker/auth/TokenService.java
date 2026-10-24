package com.bytesized.tracker.auth;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import com.bytesized.tracker.user.User;

@Service
public class TokenService {

    private final JwtEncoder encoder;
    private final Duration ttl;

    public TokenService(JwtEncoder encoder, @Value("${app.jwt.ttl-hours}") long ttlHours) {
        this.encoder = encoder;
        this.ttl = Duration.ofHours(ttlHours);
    }

    public String issue(User user) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("bytesized-tracker")
                .issuedAt(now)
                .expiresAt(now.plus(ttl))
                .subject(user.getId().toString())
                .claim("username", user.getUsername())
                .claim("name", user.getFullName())
                .claim("roles", List.of(user.getRole().name()))
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    public long ttlSeconds() {
        return ttl.toSeconds();
    }
}
