package com.bytesized.tracker.location;

import java.time.Duration;
import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.common.TrackingProperties;

/** Privacy safeguard: raw GPS points are deleted after the retention period. Visits are kept. */
@Component
public class RetentionJob {

    private static final Logger log = LoggerFactory.getLogger(RetentionJob.class);

    private final LocationPingRepository pings;
    private final TrackingProperties props;

    public RetentionJob(LocationPingRepository pings, TrackingProperties props) {
        this.pings = pings;
        this.props = props;
    }

    @Scheduled(cron = "0 30 2 * * *", zone = "${app.timezone}")
    @Transactional
    public void purgeOldPings() {
        Instant cutoff = Instant.now().minus(Duration.ofDays(props.retentionDays()));
        int deleted = pings.deleteOlderThan(cutoff);
        log.info("Retention: deleted {} location pings older than {} days", deleted, props.retentionDays());
    }
}
