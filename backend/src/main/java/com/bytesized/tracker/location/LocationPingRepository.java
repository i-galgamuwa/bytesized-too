package com.bytesized.tracker.location;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface LocationPingRepository extends JpaRepository<LocationPing, Long> {

    Optional<LocationPing> findFirstByRepIdOrderByRecordedAtDesc(Long repId);

    List<LocationPing> findByRepIdAndRecordedAtBetweenOrderByRecordedAtAsc(Long repId, Instant from, Instant to);

    @Modifying
    @Query("delete from LocationPing p where p.recordedAt < :cutoff")
    int deleteOlderThan(Instant cutoff);
}
