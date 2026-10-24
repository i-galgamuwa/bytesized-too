package com.bytesized.tracker.common;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.tracking")
public record TrackingProperties(
        int staleAfterMinutes,
        double maxAccuracyM,
        double maxSpeedMps,
        double accuracyToleranceM,
        int defaultRadiusM,
        int retentionDays) {
}
