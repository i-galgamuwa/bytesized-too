package com.bytesized.tracker.common;

public final class GeoUtils {

    private static final double EARTH_RADIUS_M = 6_371_000;

    private GeoUtils() {
    }

    /** Great-circle distance in metres (haversine formula). */
    public static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
    }

    public static boolean isValid(Double lat, Double lng) {
        return lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }
}
