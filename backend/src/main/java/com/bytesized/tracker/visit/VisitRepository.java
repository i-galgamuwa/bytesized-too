package com.bytesized.tracker.visit;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface VisitRepository extends JpaRepository<Visit, Long> {

    @Query("select v from Visit v join fetch v.client where v.rep.id = :repId and v.status = :status")
    Optional<Visit> findFirstByRepIdAndStatus(Long repId, VisitStatus status);

    /** Visits started in [from, to). repId and status are optional filters. */
    @Query("""
            select v from Visit v join fetch v.rep join fetch v.client
            where v.startedAt >= :from and v.startedAt < :to
              and (:repId is null or v.rep.id = :repId)
              and (:status is null or v.status = :status)
            order by v.startedAt desc
            """)
    List<Visit> search(Long repId, VisitStatus status, Instant from, Instant to);

    /** Latest visit per client across all time, so coverage reports can age never-visited accounts. */
    @Query("""
            select new com.bytesized.tracker.visit.ClientLastVisit(v.client.id, max(v.startedAt))
            from Visit v group by v.client.id
            """)
    List<ClientLastVisit> lastVisitPerClient();
}
