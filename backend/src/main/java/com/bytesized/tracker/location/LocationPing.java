package com.bytesized.tracker.location;

import java.time.Instant;

import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.user.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "location_pings", indexes = {
        @Index(name = "idx_ping_rep_time", columnList = "rep_id, recorded_at"),
        @Index(name = "idx_ping_time", columnList = "recorded_at") })
public class LocationPing {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "rep_id")
    private User rep;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "shift_id")
    private Shift shift;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    private Double accuracyM;

    private Double speedMps;

    private Integer battery;

    /** When the phone captured the fix. */
    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    /** When the server received it (differs when the phone was offline and uploaded a buffer). */
    @Column(nullable = false)
    private Instant receivedAt;

    protected LocationPing() {
    }

    public LocationPing(User rep, Shift shift, double latitude, double longitude, Double accuracyM, Double speedMps,
            Integer battery, Instant recordedAt, Instant receivedAt) {
        this.rep = rep;
        this.shift = shift;
        this.latitude = latitude;
        this.longitude = longitude;
        this.accuracyM = accuracyM;
        this.speedMps = speedMps;
        this.battery = battery;
        this.recordedAt = recordedAt;
        this.receivedAt = receivedAt;
    }

    public Long getId() { return id; }
    public User getRep() { return rep; }
    public Shift getShift() { return shift; }
    public double getLatitude() { return latitude; }
    public double getLongitude() { return longitude; }
    public Double getAccuracyM() { return accuracyM; }
    public Double getSpeedMps() { return speedMps; }
    public Integer getBattery() { return battery; }
    public Instant getRecordedAt() { return recordedAt; }
    public Instant getReceivedAt() { return receivedAt; }
}
