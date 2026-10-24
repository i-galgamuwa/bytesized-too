package com.bytesized.tracker.shift;

import java.time.Instant;

import com.bytesized.tracker.user.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/** A working period. Location is only accepted while a shift is open (privacy boundary). */
@Entity
@Table(name = "shifts")
public class Shift {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "rep_id")
    private User rep;

    @Column(nullable = false)
    private Instant startedAt;

    private Instant endedAt;

    protected Shift() {
    }

    public Shift(User rep, Instant startedAt) {
        this.rep = rep;
        this.startedAt = startedAt;
    }

    public Long getId() { return id; }
    public User getRep() { return rep; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getEndedAt() { return endedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }
}
