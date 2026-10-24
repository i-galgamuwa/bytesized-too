package com.bytesized.tracker.visit;

import java.time.Instant;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.user.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/** A Start/End visit logged by a rep at a client. */
@Entity
@Table(name = "visits")
public class Visit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "rep_id")
    private User rep;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id")
    private Client client;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "shift_id")
    private Shift shift;

    @Column(nullable = false)
    private Instant startedAt;
    private double startLat;
    private double startLng;
    private Double startAccuracyM;
    /** Distance from the client location when the visit started, in metres. */
    private double startDistanceM;

    private Instant endedAt;
    private Double endLat;
    private Double endLng;
    private Double endAccuracyM;
    private Double endDistanceM;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private VisitStatus status = VisitStatus.IN_PROGRESS;

    @Column(length = 1000)
    private String notes;

    protected Visit() {
    }

    public Visit(User rep, Client client, Shift shift, Instant startedAt, double startLat, double startLng,
            Double startAccuracyM, double startDistanceM) {
        this.rep = rep;
        this.client = client;
        this.shift = shift;
        this.startedAt = startedAt;
        this.startLat = startLat;
        this.startLng = startLng;
        this.startAccuracyM = startAccuracyM;
        this.startDistanceM = startDistanceM;
    }

    public void end(Instant endedAt, double lat, double lng, Double accuracyM, double distanceM, VisitStatus status,
            String notes) {
        this.endedAt = endedAt;
        this.endLat = lat;
        this.endLng = lng;
        this.endAccuracyM = accuracyM;
        this.endDistanceM = distanceM;
        this.status = status;
        this.notes = notes;
    }

    public Long getId() { return id; }
    public User getRep() { return rep; }
    public Client getClient() { return client; }
    public Shift getShift() { return shift; }
    public Instant getStartedAt() { return startedAt; }
    public double getStartLat() { return startLat; }
    public double getStartLng() { return startLng; }
    public Double getStartAccuracyM() { return startAccuracyM; }
    public double getStartDistanceM() { return startDistanceM; }
    public Instant getEndedAt() { return endedAt; }
    public Double getEndLat() { return endLat; }
    public Double getEndLng() { return endLng; }
    public Double getEndAccuracyM() { return endAccuracyM; }
    public Double getEndDistanceM() { return endDistanceM; }
    public VisitStatus getStatus() { return status; }
    public String getNotes() { return notes; }
}
