package com.bytesized.tracker.user;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.CurrentUser;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;

    public UserController(UserRepository users, PasswordEncoder passwordEncoder) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
    }

    public record CreateUserRequest(
            @NotBlank @Size(max = 50) String username,
            @NotBlank @Size(max = 100) String fullName,
            @NotBlank @Size(min = 6) String password,
            @NotNull Role role) {
    }

    @GetMapping("/me")
    public UserDto me(@AuthenticationPrincipal Jwt jwt) {
        return users.findById(CurrentUser.id(jwt)).map(UserDto::of).orElseThrow(() -> ApiException.notFound("User"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public List<UserDto> list(@RequestParam(defaultValue = "REP") Role role) {
        return users.findByRoleOrderByFullName(role).stream().map(UserDto::of).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    public UserDto create(@Valid @RequestBody CreateUserRequest req) {
        if (users.existsByUsername(req.username())) {
            throw ApiException.conflict("Username already exists");
        }
        User user = new User(req.username(), req.fullName(), passwordEncoder.encode(req.password()), req.role());
        return UserDto.of(users.save(user));
    }
}
