package com.bytesized.tracker.assignment;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.client.ClientService;
import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.user.Role;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;
import com.bytesized.tracker.visit.Visit;

/**
 * Planning visits and delivering them to reps.
 *
 * <p>Assignments are pushed to the owning rep over STOMP as soon as they change, so a phone that
 * is already online does not wait for its next poll. The push is best-effort: {@code /assignments/mine}
 * remains the source of truth, because a rep may be offline exactly when the manager plans their day.
 */
@Service
public class AssignmentService {

    private static final Logger log = LoggerFactory.getLogger(AssignmentService.class);

    /** Per-rep destination; subscribers receive only their own assignments. */
    public static final String ASSIGNMENTS_QUEUE = "/queue/assignments";

    private final AssignmentRepository assignments;
    private final UserRepository users;
    private final ClientService clients;
    private final SimpMessagingTemplate messaging;
    private final ZoneId zone;

    public AssignmentService(AssignmentRepository assignments, UserRepository users, ClientService clients,
            SimpMessagingTemplate messaging, @Value("${app.timezone}") String timezone) {
        this.assignments = assignments;
        this.users = users;
        this.clients = clients;
        this.messaging = messaging;
        this.zone = ZoneId.of(timezone);
    }

    public record CreateRequest(
            Long repId,
            Long clientId,
            LocalDate date,
            LocalTime time,
            AssignmentPriority priority,
            String note) {
    }

    /** Assign several clients to one rep for one day in a single call, as a route is planned. */
    public record BulkCreateRequest(
            Long repId,
            LocalDate date,
            List<Long> clientIds,
            AssignmentPriority priority,
            String note) {
    }

    public record RescheduleRequest(LocalDate date, LocalTime time, AssignmentPriority priority, String note) {
    }

    @Transactional
    public AssignmentDto create(CreateRequest req, Long managerId) {
        Assignment saved = createOne(req.repId(), req.clientId(), req.date(), req.time(),
                req.priority(), req.note(), manager(managerId));
        return publish(saved, "assigned");
    }

    @Transactional
    public List<AssignmentDto> createBulk(BulkCreateRequest req, Long managerId) {
        if (req.clientIds() == null || req.clientIds().isEmpty()) {
            throw ApiException.badRequest("Select at least one client");
        }
        User creator = manager(managerId);
        List<AssignmentDto> created = new ArrayList<>();
        for (Long clientId : req.clientIds()) {
            created.add(AssignmentDto.of(createOne(req.repId(), clientId, req.date(), null,
                    req.priority(), req.note(), creator)));
        }
        // One push for the whole route rather than one per stop.
        pushDay(req.repId(), req.date(), "assigned");
        return created;
    }

    private Assignment createOne(Long repId, Long clientId, LocalDate date, LocalTime time,
            AssignmentPriority priority, String note, User creator) {
        if (repId == null || clientId == null) {
            throw ApiException.badRequest("repId and clientId are required");
        }
        LocalDate day = date != null ? date : LocalDate.now(zone);
        if (day.isBefore(LocalDate.now(zone))) {
            throw ApiException.badRequest("Cannot schedule a visit in the past");
        }
        User rep = users.findById(repId)
                .filter(u -> u.getRole() == Role.REP)
                .orElseThrow(() -> ApiException.notFound("Representative"));
        if (!rep.isActive()) {
            throw ApiException.badRequest("That representative's account is inactive");
        }
        Client client = clients.get(clientId);

        assignments.findExisting(repId, clientId, day).ifPresent(a -> {
            throw ApiException.conflict(rep.getFullName() + " is already scheduled to visit "
                    + client.getName() + " on " + day);
        });

        return assignments.save(new Assignment(rep, client, day, time, priority, note, creator));
    }

    @Transactional
    public AssignmentDto reschedule(Long id, RescheduleRequest req) {
        Assignment a = get(id);
        if (a.getStatus() == AssignmentStatus.COMPLETED) {
            throw ApiException.conflict("That visit has already been completed");
        }
        if (req.date() != null) {
            if (req.date().isBefore(LocalDate.now(zone))) {
                throw ApiException.badRequest("Cannot schedule a visit in the past");
            }
            a.reschedule(req.date(), req.time());
        }
        if (req.priority() != null) {
            a.setPriority(req.priority());
        }
        if (req.note() != null) {
            a.setNote(req.note());
        }
        return publish(a, "updated");
    }

    @Transactional
    public void cancel(Long id) {
        Assignment a = get(id);
        if (a.getStatus() == AssignmentStatus.COMPLETED) {
            throw ApiException.conflict("That visit has already been completed");
        }
        a.cancel();
        assignments.flush();
        publish(a, "cancelled");
    }

    @Transactional(readOnly = true)
    public List<AssignmentDto> forRepOn(Long repId, LocalDate date) {
        return assignments.findForRepOn(repId, date != null ? date : LocalDate.now(zone))
                .stream().map(AssignmentDto::of).toList();
    }

    /**
     * Manager view of the schedule. Cancelled work is withdrawn, not history, so it is left out
     * unless explicitly asked for with {@code status=CANCELLED} — the row is kept either way, so
     * nothing is lost and an audit can still reach it.
     */
    @Transactional(readOnly = true)
    public List<AssignmentDto> search(Long repId, AssignmentStatus status, LocalDate from, LocalDate to) {
        LocalDate today = LocalDate.now(zone);
        LocalDate start = from != null ? from : today;
        LocalDate end = to != null ? to : start;
        if (end.isBefore(start)) {
            throw ApiException.badRequest("'from' must not be after 'to'");
        }
        return assignments.search(repId, status, start, end).stream()
                .filter(a -> status != null || a.getStatus() != AssignmentStatus.CANCELLED)
                .map(AssignmentDto::of)
                .toList();
    }

    /**
     * Closes the matching assignment when a rep starts a visit. Called from the visit flow, so an
     * assignment can only be completed by physically logging a visit at that client.
     *
     * <p>Never throws: a scheduling mismatch must not stop a rep recording real work.
     */
    @Transactional
    public void linkVisit(Visit visit) {
        try {
            LocalDate day = visit.getStartedAt().atZone(zone).toLocalDate();
            List<Assignment> pending = assignments.findPendingFor(
                    visit.getRep().getId(), visit.getClient().getId(), day);
            if (pending.isEmpty()) {
                return;
            }
            Assignment a = pending.get(0);
            a.completeWith(visit);
            assignments.flush();
            publish(a, "completed");
        } catch (Exception e) {
            log.warn("Could not link visit {} to an assignment: {}", visit.getId(), e.getMessage());
        }
    }

    /** Anything still pending once its day has passed was not done. */
    @Scheduled(cron = "0 15 2 * * *", zone = "${app.timezone}")
    @Transactional
    public void markOverdueMissed() {
        List<Assignment> overdue = assignments.findOverdue(LocalDate.now(zone));
        overdue.forEach(Assignment::markMissed);
        if (!overdue.isEmpty()) {
            log.info("Marked {} overdue assignment(s) as missed", overdue.size());
        }
    }

    private Assignment get(Long id) {
        return assignments.findById(id).orElseThrow(() -> ApiException.notFound("Assignment"));
    }

    private User manager(Long managerId) {
        return managerId == null ? null : users.findById(managerId).orElse(null);
    }

    /** Pushes one assignment to its rep, then returns it for the HTTP response. */
    private AssignmentDto publish(Assignment a, String event) {
        AssignmentDto dto = AssignmentDto.of(a);
        send(a.getRep().getId(), new Notification(event, dto, null));
        return dto;
    }

    private void pushDay(Long repId, LocalDate date, String event) {
        send(repId, new Notification(event, null, forRepOn(repId, date)));
    }

    /**
     * STOMP user destinations are addressed by principal name, which for this app is the JWT
     * subject, i.e. the user id.
     */
    private void send(Long repId, Notification payload) {
        try {
            messaging.convertAndSendToUser(String.valueOf(repId), ASSIGNMENTS_QUEUE, payload);
        } catch (Exception e) {
            // Delivery is a convenience; the rep will still see it on their next fetch.
            log.warn("Could not push assignment to rep {}: {}", repId, e.getMessage());
        }
    }

    /** Either a single changed assignment, or the rep's whole day after a bulk change. */
    public record Notification(String event, AssignmentDto assignment, List<AssignmentDto> day) {
    }
}
