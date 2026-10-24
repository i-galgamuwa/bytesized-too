package com.bytesized.tracker.assignment;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AssignmentRepository extends JpaRepository<Assignment, Long> {

    /** A rep's plan for one day, ordered so untimed items fall after timed ones. */
    @Query("""
            select a from Assignment a join fetch a.client join fetch a.rep
            where a.rep.id = :repId and a.scheduledDate = :date and a.status <> 'CANCELLED'
            order by case when a.scheduledTime is null then 1 else 0 end, a.scheduledTime, a.id
            """)
    List<Assignment> findForRepOn(Long repId, LocalDate date);

    /** Manager view. repId and status are optional filters. */
    @Query("""
            select a from Assignment a join fetch a.client join fetch a.rep
            where a.scheduledDate between :from and :to
              and (:repId is null or a.rep.id = :repId)
              and (:status is null or a.status = :status)
            order by a.scheduledDate,
                     case when a.scheduledTime is null then 1 else 0 end, a.scheduledTime, a.id
            """)
    List<Assignment> search(Long repId, AssignmentStatus status, LocalDate from, LocalDate to);

    /** The assignment a visit should close, if the rep was scheduled to be there that day. */
    @Query("""
            select a from Assignment a
            where a.rep.id = :repId and a.client.id = :clientId
              and a.scheduledDate = :date and a.status = 'PENDING'
            order by a.id
            """)
    List<Assignment> findPendingFor(Long repId, Long clientId, LocalDate date);

    /** Guards against assigning the same rep to the same client twice on one day. */
    @Query("""
            select a from Assignment a
            where a.rep.id = :repId and a.client.id = :clientId
              and a.scheduledDate = :date and a.status in ('PENDING', 'COMPLETED')
            """)
    Optional<Assignment> findExisting(Long repId, Long clientId, LocalDate date);

    @Query("select a from Assignment a join fetch a.client join fetch a.rep "
            + "where a.status = 'PENDING' and a.scheduledDate < :before")
    List<Assignment> findOverdue(LocalDate before);
}
