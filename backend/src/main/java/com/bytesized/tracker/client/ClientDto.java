package com.bytesized.tracker.client;

public record ClientDto(Long id, String name, String address, double lat, double lng, int radiusM, Double distanceM) {

    public static ClientDto of(Client c) {
        return of(c, null);
    }

    public static ClientDto of(Client c, Double distanceM) {
        return new ClientDto(c.getId(), c.getName(), c.getAddress(), c.getLatitude(), c.getLongitude(), c.getRadiusM(),
                distanceM == null ? null : (double) Math.round(distanceM));
    }
}
