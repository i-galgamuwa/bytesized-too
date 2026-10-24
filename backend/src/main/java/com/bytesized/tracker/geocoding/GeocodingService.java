package com.bytesized.tracker.geocoding;

import java.util.List;

/** Address to coordinates lookup. Swap the implementation to change provider (e.g. Google Geocoding). */
public interface GeocodingService {

    List<GeocodeResult> search(String query);
}
