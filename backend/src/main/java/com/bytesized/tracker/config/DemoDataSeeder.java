package com.bytesized.tracker.config;

import java.time.ZoneId;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.client.Client;
import com.bytesized.tracker.client.ClientRepository;
import com.bytesized.tracker.user.Role;
import com.bytesized.tracker.user.User;
import com.bytesized.tracker.user.UserRepository;

/**
 * Creates demo accounts and Colombo-area clients on an empty database. Disable with app.seed-demo-data=false.
 * Demo passwords are listed in README.md; change them before any real use.
 */
@Component
@ConditionalOnProperty(name = "app.seed-demo-data", havingValue = "true")
public class DemoDataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final UserRepository users;
    private final ClientRepository clients;
    private final PasswordEncoder passwordEncoder;
    private final DemoActivityGenerator activity;
    private final int activityDays;
    private final ZoneId zone;

    public DemoDataSeeder(UserRepository users, ClientRepository clients, PasswordEncoder passwordEncoder,
            DemoActivityGenerator activity,
            @Value("${app.seed-demo-activity-days:21}") int activityDays,
            @Value("${app.timezone}") String timezone) {
        this.users = users;
        this.clients = clients;
        this.passwordEncoder = passwordEncoder;
        this.activity = activity;
        this.activityDays = activityDays;
        this.zone = ZoneId.of(timezone);
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (users.count() > 0) {
            return;
        }
        user("admin", "System Admin", "admin123", Role.ADMIN);
        user("manager", "Nimali Perera", "manager123", Role.MANAGER);
        user("rep1", "Kasun Silva", "rep123", Role.REP);
        user("rep2", "Tharindu Fernando", "rep123", Role.REP);
        user("rep3", "Dilini Jayawardena", "rep123", Role.REP);

        clients.save(new Client("Lanka Hardware - Fort", "Colombo Fort, Colombo 01", 6.9335, 79.8500, 100));
        clients.save(new Client("City Pharmacy - Kollupitiya", "Galle Road, Colombo 03", 6.9110, 79.8505, 80));
        clients.save(new Client("Ceylon Traders - Bambalapitiya", "Galle Road, Colombo 04", 6.8935, 79.8555, 100));
        clients.save(new Client("Green Mart - Rajagiriya", "Kotte Road, Rajagiriya", 6.9090, 79.8945, 120));
        clients.save(new Client("Sunrise Distributors - Nugegoda", "High Level Road, Nugegoda", 6.8650, 79.8995, 150));
        clients.save(new Client("Island Motors - Dehiwala", "Galle Road, Dehiwala", 6.8510, 79.8650, 100));
        log.info("Seeded demo users and clients");
        if (activityDays > 0) {
            activity.generate(activityDays, zone);
        }
    }

    private void user(String username, String name, String password, Role role) {
        users.save(new User(username, name, passwordEncoder.encode(password), role));
    }
}
