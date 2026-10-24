package com.bytesized.tracker.client;

import java.util.Comparator;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bytesized.tracker.common.ApiException;
import com.bytesized.tracker.common.GeoUtils;
import com.bytesized.tracker.common.TrackingProperties;
import com.bytesized.tracker.geocoding.GeocodeResult;
import com.bytesized.tracker.geocoding.GeocodingService;

@Service
public class ClientService {

    private final ClientRepository clients;
    private final GeocodingService geocoding;
    private final TrackingProperties props;

    public ClientService(ClientRepository clients, GeocodingService geocoding, TrackingProperties props) {
        this.clients = clients;
        this.geocoding = geocoding;
        this.props = props;
    }

    public record ClientRequest(String name, String address, Double lat, Double lng, Integer radiusM) {
    }

    public List<ClientDto> list() {
        return clients.findByActiveTrueOrderByName().stream().map(ClientDto::of).toList();
    }

    public List<ClientDto> nearby(double lat, double lng, int limit) {
        return clients.findByActiveTrueOrderByName().stream()
                .map(c -> ClientDto.of(c, GeoUtils.distanceMeters(lat, lng, c.getLatitude(), c.getLongitude())))
                .sorted(Comparator.comparing(ClientDto::distanceM))
                .limit(limit)
                .toList();
    }

    public Client get(Long id) {
        return clients.findById(id).filter(Client::isActive).orElseThrow(() -> ApiException.notFound("Client"));
    }

    @Transactional
    public ClientDto create(ClientRequest req) {
        if (req.name() == null || req.name().isBlank()) {
            throw ApiException.badRequest("Client name is required");
        }
        double[] point = resolveLocation(req);
        Client c = new Client(req.name().trim(), req.address(), point[0], point[1], radiusOrDefault(req.radiusM()));
        return ClientDto.of(clients.save(c));
    }

    @Transactional
    public ClientDto update(Long id, ClientRequest req) {
        Client c = get(id);
        if (req.name() != null && !req.name().isBlank()) {
            c.setName(req.name().trim());
        }
        if (req.address() != null) {
            c.setAddress(req.address());
        }
        if (req.lat() != null || req.lng() != null) {
            double[] point = resolveLocation(req);
            c.setLatitude(point[0]);
            c.setLongitude(point[1]);
        }
        if (req.radiusM() != null) {
            c.setRadiusM(radiusOrDefault(req.radiusM()));
        }
        return ClientDto.of(c);
    }

    @Transactional
    public void deactivate(Long id) {
        get(id).setActive(false);
    }

    /** Uses explicit coordinates (map pin / GPS) when given, otherwise geocodes the address. */
    private double[] resolveLocation(ClientRequest req) {
        if (req.lat() != null || req.lng() != null) {
            if (!GeoUtils.isValid(req.lat(), req.lng())) {
                throw ApiException.badRequest("Invalid coordinates");
            }
            return new double[] { req.lat(), req.lng() };
        }
        if (req.address() == null || req.address().isBlank()) {
            throw ApiException.badRequest("Provide coordinates (lat/lng) or an address");
        }
        List<GeocodeResult> results = geocoding.search(req.address());
        if (results.isEmpty()) {
            throw ApiException.badRequest("Address not found on the map. Drop a pin on the map instead.");
        }
        return new double[] { results.get(0).lat(), results.get(0).lng() };
    }

    private int radiusOrDefault(Integer radiusM) {
        if (radiusM == null) {
            return props.defaultRadiusM();
        }
        if (radiusM < 20 || radiusM > 2000) {
            throw ApiException.badRequest("Radius must be between 20 and 2000 metres");
        }
        return radiusM;
    }
}
