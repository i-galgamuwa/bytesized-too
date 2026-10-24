package com.bytesized.tracker.assignment;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.visit.Visit;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * A visit a manager has planned for a rep. It is a plan, not evidence: an assignment only
 * becomes {@code COMPLETED} when a real {@link Visit} is logged at that client, so the geofence
 * check remains the single source of truth for whether someone actually turned up.
 */
@Entity
@Table(name = "assignments", indexes = {
        @Index(name = "idx_assignment_rep_date", columnList = "rep_id, scheduled_date"),
        @Index(name = "idx_assignment_date", columnList = "scheduled_date") })
public class Assignment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "rep_id")
    private User rep;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id")
    private Client client;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    /** Optional: field work rarely keeps to the minute, so a time is a hint, not a slot. */
    private LocalTime scheduledTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AssignmentPriority priority = AssignmentPriority.NORMAL;

    @Column(length = 500)
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AssignmentStatus status = AssignmentStatus.PENDING;

    /** The visit that fulfilled this assignment, once one exists. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "visit_id")
    private Visit visit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant completedAt;

    protected Assignment() {
    }

    public Assignment(User rep, Client client, LocalDate scheduledDate, LocalTime scheduledTime,
            AssignmentPriority priority, String note, User createdBy) {
        this.rep = rep;
        this.client = client;
        this.scheduledDate = scheduledDate;
        this.scheduledTime = scheduledTime;
        this.priority = priority == null ? AssignmentPriority.NORMAL : priority;
        this.note = note;
        this.createdBy = createdBy;
    }

    /** Called when a rep logs a visit at this client on the scheduled day. */
    public void completeWith(Visit visit) {
        this.visit = visit;
        this.status = AssignmentStatus.COMPLETED;
        this.completedAt = Instant.now();
    }

    public void cancel() {
        this.status = AssignmentStatus.CANCELLED;
    }

    public void markMissed() {
        this.status = AssignmentStatus.MISSED;
    }

    public void reschedule(LocalDate date, LocalTime time) {
        this.scheduledDate = date;
        this.scheduledTime = time;
    }

    public Long getId() { return id; }
    public User getRep() { return rep; }
    public Client getClient() { return client; }
    public LocalDate getScheduledDate() { return scheduledDate; }
    public LocalTime getScheduledTime() { return scheduledTime; }
    public AssignmentPriority getPriority() { return priority; }
    public void setPriority(AssignmentPriority priority) { this.priority = priority; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
    public AssignmentStatus getStatus() { return status; }
    public Visit getVisit() { return visit; }
    public User getCreatedBy() { return createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getCompletedAt() { return completedAt; }
}
