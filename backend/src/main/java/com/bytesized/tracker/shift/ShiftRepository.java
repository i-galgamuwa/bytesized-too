package com.bytesized.tracker.shift;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ShiftRepository extends JpaRepository<Shift, Long> {

    Optional<Shift> findFirstByRepIdAndEndedAtIsNull(Long repId);

    @Query("select s from Shift s join fetch s.rep where s.endedAt is null")
    List<Shift> findAllOpen();

    @Query("""
            select s from Shift s
            where s.rep.id = :repId and s.startedAt < :to and (s.endedAt is null or s.endedAt > :from)
            """)
    List<Shift> findOverlapping(Long repId, Instant from, Instant to);
}
