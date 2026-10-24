package com.bytesized.tracker.user;

public record UserDto(Long id, String username, String fullName, Role role, boolean active) {

    public static UserDto of(User u) {
        return new UserDto(u.getId(), u.getUsername(), u.getFullName(), u.getRole(), u.isActive());
    }
}
