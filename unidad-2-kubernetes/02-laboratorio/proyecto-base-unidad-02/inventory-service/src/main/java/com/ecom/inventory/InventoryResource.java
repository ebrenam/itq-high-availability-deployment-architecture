package com.ecom.inventory;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/v1/inventory")
public class InventoryResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public InventoryStatus getStatus() {
        return new InventoryStatus("inventory-service", "UP", System.currentTimeMillis(), "v1.1.0");
    }

    // CAMBIO: Agregamos campo 'version' al record
    public record InventoryStatus(String service, String status, long timestamp, String version) {}
}