package com.bytesized.tracker.config;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.client.ClientRepository;
import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.location.LocationPing;
import com.bytesized.tracker.location.LocationPingRepository;
import com.bytesized.tracker.shift.Shift;
import com.bytesized.tracker.shift.ShiftRepository;
import com.bytesized.tracker.user.Role;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;
import com.bytesized.tracker.visit.Visit;
import com.bytesized.tracker.visit.VisitRepository;
import com.bytesized.tracker.visit.VisitStatus;

/**
 * Generates a plausible history of field work so the reporting screens have something real to show.
 *
 * <p>Rows are written straight through the repositories with explicit timestamps, which is the only
 * way to backdate them: the REST API stamps everything {@code Instant.now()} by design. The data is
 * built to be self-consistent rather than merely non-empty — agents walk between clients at a
 * believable speed, so route distances add up, and visit status is derived with the same geofence
 * rule {@code VisitService} applies rather than being assigned arbitrarily.
 */
@Component
public class DemoActivityGenerator {

    private static final Logger log = LoggerFactory.getLogger(DemoActivityGenerator.class);

    /** Fixed seed: a demo that changes shape on every reset is hard to talk about. */
    private static final long SEED = 20261001L;
    private static final int PING_INTERVAL_MIN = 5;
    private static final double ACCURACY_TOLERANCE_M = 30;
    /** Roughly 25 km/h through Colombo traffic. */
    private static final double TRAVEL_SPEED_MPS = 7.0;

    private static final String[] NOTES = {
            "Stock levels checked, reorder placed.",
            "Discussed new product line, follow-up next week.",
            "Collected payment for last invoice.",
            "Owner unavailable, spoke with the manager.",
            "Shelf display refreshed.",
            "Price list updated for the new quarter.",
            "Return pickup arranged for damaged units."
    };
    private static final String[] OFFSITE_NOTES = {
            "Met the owner at a nearby office.",
            "Shop closed, met the manager down the road.",
            "Handover done at the warehouse instead."
    };

    private final UserRepository users;
    private final ClientRepository clients;
    private final ShiftRepository shifts;
    private final VisitRepository visits;
    private final LocationPingRepository pings;

    public DemoActivityGenerator(UserRepository users, ClientRepository clients, ShiftRepository shifts,
            VisitRepository visits, LocationPingRepository pings) {
        this.users = users;
        this.clients = clients;
        this.shifts = shifts;
        this.visits = visits;
        this.pings = pings;
    }

    @Transactional
    public void generate(int days, ZoneId zone) {
        List<User> reps = users.findByRoleOrderByFullName(Role.REP);
        List<Client> allClients = clients.findByActiveTrueOrderByName();
        if (reps.isEmpty() || allClients.isEmpty()) {
            return;
        }

        Random random = new Random(SEED);
        LocalDate today = LocalDate.now(zone);
        int visitCount = 0;

        // Past days are complete: shift opened, work done, shift closed.
        for (int ago = days; ago >= 1; ago--) {
            LocalDate day = today.minusDays(ago);
            // Sunday is a rest day, which also gives the weekly charts a realistic shape.
            if (day.getDayOfWeek().getValue() == 7) {
                continue;
            }
            for (User rep : reps) {
                visitCount += workDay(rep, allClients, day, zone, random, false);
            }
        }

        // Today is left mid-shift so the live map has something to show.
        for (User rep : reps) {
            visitCount += workDay(rep, allClients, today, zone, random, true);
        }

        log.info("Seeded demo activity: {} visits across {} days for {} agents", visitCount, days, reps.size());
    }

    /** @return number of visits created. */
    private int workDay(User rep, List<Client> allClients, LocalDate day, ZoneId zone, Random random,
            boolean inProgressDay) {

        Instant shiftStart = at(day, 8, 15 + random.nextInt(30), zone);
        Shift shift = shifts.save(new Shift(rep, shiftStart));

        List<Client> route = new ArrayList<>(allClients);
        Collections.shuffle(route, random);
        int stops = inProgressDay ? 2 + random.nextInt(2) : 3 + random.nextInt(3);
        route = route.subList(0, Math.min(stops, route.size()));

        Instant clock = shiftStart;
        double[] position = { route.get(0).getLatitude(), route.get(0).getLongitude() };
        int battery = 85 + random.nextInt(15);
        int created = 0;

        for (int i = 0; i < route.size(); i++) {
            Client client = route.get(i);

            // Travel leg: straight-line interpolation is enough to make distances and routes sensible.
            double metres = GeoUtils.distanceMeters(position[0], position[1],
                    client.getLatitude(), client.getLongitude());
            int travelMin = Math.max(8, (int) Math.round(metres / TRAVEL_SPEED_MPS / 60));
            for (int m = PING_INTERVAL_MIN; m <= travelMin; m += PING_INTERVAL_MIN) {
                double f = (double) m / travelMin;
                savePing(rep, shift,
                        position[0] + (client.getLatitude() - position[0]) * f,
                        position[1] + (client.getLongitude() - position[1]) * f,
                        8 + random.nextInt(12), TRAVEL_SPEED_MPS, battery,
                        clock.plusSeconds(m * 60L));
            }
            clock = clock.plusSeconds(travelMin * 60L);
            battery = Math.max(12, battery - random.nextInt(3));

            // One visit in six is logged away from the client, which is what UNVERIFIED is for.
            boolean offsite = random.nextInt(6) == 0;
            double accuracy = 6 + random.nextInt(14);
            double[] fix = offsite
                    ? offset(client, client.getRadiusM() + 250 + random.nextInt(400), random)
                    : offset(client, client.getRadiusM() * 0.5 * random.nextDouble(), random);

            double startDistance = GeoUtils.distanceMeters(fix[0], fix[1],
                    client.getLatitude(), client.getLongitude());
            Visit visit = visits.save(new Visit(rep, client, shift, clock, fix[0], fix[1], accuracy, startDistance));
            created++;
            savePing(rep, shift, fix[0], fix[1], accuracy, 0.0, battery, clock);

            int durationMin = 15 + random.nextInt(40);

            // The last stop of today is deliberately left open: a rep currently at a client.
            if (inProgressDay && i == route.size() - 1) {
                position = fix;
                clock = clock.plusSeconds(durationMin * 60L);
                break;
            }

            Instant endedAt = clock.plusSeconds(durationMin * 60L);
            double endAccuracy = 6 + random.nextInt(14);
            double[] endFix = offset(client, offsite
                    ? client.getRadiusM() + 200 + random.nextInt(300)
                    : client.getRadiusM() * 0.5 * random.nextDouble(), random);
            double endDistance = GeoUtils.distanceMeters(endFix[0], endFix[1],
                    client.getLatitude(), client.getLongitude());

            boolean verified = inside(startDistance, accuracy, client.getRadiusM())
                    && inside(endDistance, endAccuracy, client.getRadiusM());

            visit.end(endedAt, endFix[0], endFix[1], endAccuracy, endDistance,
                    verified ? VisitStatus.VERIFIED : VisitStatus.UNVERIFIED,
                    pick(verified ? NOTES : OFFSITE_NOTES, random));
            savePing(rep, shift, endFix[0], endFix[1], endAccuracy, 0.0, battery, endedAt);

            clock = endedAt;
            position = endFix;
        }

        if (!inProgressDay) {
            shift.setEndedAt(clock.plusSeconds((20 + random.nextInt(40)) * 60L));
        }
        return created;
    }

    /** Mirrors VisitService.isInside so seeded statuses agree with the rule the API would apply. */
    private static boolean inside(double distanceM, double accuracyM, int radiusM) {
        return distanceM - Math.min(accuracyM, ACCURACY_TOLERANCE_M) <= radiusM;
    }

    /** A point a given distance from the client, in a random direction. */
    private static double[] offset(Client c, double metres, Random random) {
        double bearing = random.nextDouble() * 2 * Math.PI;
        double dLat = metres * Math.cos(bearing) / 111_320.0;
        double dLng = metres * Math.sin(bearing)
                / (111_320.0 * Math.cos(Math.toRadians(c.getLatitude())));
        return new double[] { c.getLatitude() + dLat, c.getLongitude() + dLng };
    }

    private void savePing(User rep, Shift shift, double lat, double lng, double accuracyM, Double speed,
            int battery, Instant at) {
        pings.save(new LocationPing(rep, shift, lat, lng, accuracyM, speed, battery, at, at));
    }

    private static Instant at(LocalDate day, int hour, int minute, ZoneId zone) {
        return day.atTime(LocalTime.of(hour, Math.min(minute, 59))).atZone(zone).toInstant();
    }

    private static String pick(String[] options, Random random) {
        return options[random.nextInt(options.length)];
    }
}
