package com.bytesized.tracker.client;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.bytesized.tracker.client.ClientService.ClientRequest;

@RestController
@RequestMapping("/api/v1/clients")
public class ClientController {

    private final ClientService service;

    public ClientController(ClientService service) {
        this.service = service;
    }

    @GetMapping
    public List<ClientDto> list() {
        return service.list();
    }

    @GetMapping("/nearby")
    public List<ClientDto> nearby(@RequestParam double lat, @RequestParam double lng,
            @RequestParam(defaultValue = "10") int limit) {
        return service.nearby(lat, lng, Math.min(limit, 50));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public ClientDto create(@RequestBody ClientRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public ClientDto update(@PathVariable Long id, @RequestBody ClientRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('MANAGER','ADMIN')")
    public void delete(@PathVariable Long id) {
        service.deactivate(id);
    }
}
