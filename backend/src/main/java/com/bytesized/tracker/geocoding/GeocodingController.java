package com.bytesized.tracker.geocoding;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/geocode")
public class GeocodingController {

    private final GeocodingService geocoding;

    public GeocodingController(GeocodingService geocoding) {
        this.geocoding = geocoding;
    }

    @GetMapping("/search")
    public List<GeocodeResult> search(@RequestParam String q) {
        return geocoding.search(q);
    }
}
