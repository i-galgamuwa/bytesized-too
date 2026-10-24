package com.bytesized.tracker.auth;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserDto;
import com.bytesized.tracker.user.UserRepository;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;

    public AuthController(UserRepository users, PasswordEncoder passwordEncoder, TokenService tokens) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
    }

    public record LoginRequest(@NotBlank String username, @NotBlank String password) {
    }

    public record LoginResponse(String token, long expiresInSeconds, UserDto user) {
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        User user = users.findByUsername(req.username())
                .filter(User::isActive)
                .filter(u -> passwordEncoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Invalid username or password"));
        return new LoginResponse(tokens.issue(user), tokens.ttlSeconds(), UserDto.of(user));
    }
}
