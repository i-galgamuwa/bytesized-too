package com.bytesized.tracker.geocoding;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.bytesized.tracker.common.ApiException;

/**
 * OpenStreetMap Nominatim geocoder. Usage policy: max 1 request/second and an identifying User-Agent,
 * so calls are serialised and throttled here.
 */
@Service
public class NominatimGeocodingService implements GeocodingService {

    private static final Logger log = LoggerFactory.getLogger(NominatimGeocodingService.class);
    private static final long MIN_INTERVAL_MS = 1100;

    private final RestClient http;
    private final String countryCodes;
    private long lastCallAt;

    public NominatimGeocodingService(
            @Value("${app.geocoding.nominatim-url}") String baseUrl,
            @Value("${app.geocoding.country-codes}") String countryCodes,
            @Value("${app.geocoding.user-agent}") String userAgent) {
        this.http = RestClient.builder().baseUrl(baseUrl).defaultHeader(HttpHeaders.USER_AGENT, userAgent).build();
        this.countryCodes = countryCodes;
    }

    record NominatimPlace(String display_name, String lat, String lon) {
    }

    @Override
    public synchronized List<GeocodeResult> search(String query) {
        if (query == null || query.isBlank()) {
            return List.of();
        }
        throttle();
        try {
            List<NominatimPlace> places = http.get()
                    .uri(u -> u.path("/search")
                            .queryParam("q", query)
                            .queryParam("format", "jsonv2")
                            .queryParam("limit", 5)
                            .queryParam("countrycodes", countryCodes)
                            .build())
                    .retrieve()
                    .body(new ParameterizedTypeReference<List<NominatimPlace>>() {
                    });
            if (places == null) {
                return List.of();
            }
            return places.stream()
                    .map(p -> new GeocodeResult(p.display_name(), Double.parseDouble(p.lat()), Double.parseDouble(p.lon())))
                    .toList();
        } catch (RestClientException e) {
            log.warn("Nominatim lookup failed for '{}': {}", query, e.getMessage());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Geocoding service unavailable, try again or drop a pin");
        }
    }

    private void throttle() {
        long wait = lastCallAt + MIN_INTERVAL_MS - System.currentTimeMillis();
        if (wait > 0) {
            try {
                Thread.sleep(wait);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        lastCallAt = System.currentTimeMillis();
    }
}
