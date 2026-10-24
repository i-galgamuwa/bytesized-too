package com.bytesized.tracker.client;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A customer or supplier location that field reps visit. Visits are verified against its geofence. */
@Entity
@Table(name = "clients")
public class Client {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(length = 300)
    private String address;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    /** Geofence radius in metres around the client location. */
    @Column(nullable = false)
    private int radiusM;

    private boolean active = true;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    protected Client() {
    }

    public Client(String name, String address, double latitude, double longitude, int radiusM) {
        this.name = name;
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
        this.radiusM = radiusM;
    }

    public Long getId() { return id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }
    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }
    public int getRadiusM() { return radiusM; }
    public void setRadiusM(int radiusM) { this.radiusM = radiusM; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public Instant getCreatedAt() { return createdAt; }
}
