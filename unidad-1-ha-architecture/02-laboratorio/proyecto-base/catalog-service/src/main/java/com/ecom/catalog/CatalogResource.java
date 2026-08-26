package com.ecom.catalog;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Random;
import java.util.logging.Logger;

/**
 * Catalog Resource - Endpoint principal del servicio de catálogo.
 * Punto de partida del laboratorio. Simula consultas a una base de datos con
 * latencia variable y fallos aleatorios para que el alumno implemente los
 * patrones de tolerancia a fallos durante la Unidad 1.
 */
@Path("/v1/products")
public class CatalogResource {

    private static final Logger LOG = Logger.getLogger(CatalogResource.class.getName());
    private final Random random = new Random();

    /**
     * Endpoint principal que retorna el catálogo de productos.
     * 
     * Simulación de escenarios:
     * - 20% de probabilidad de latencia alta (>1200ms)
     * - 30% de probabilidad de falla de conexión a base de datos
     * - 50% de probabilidad de respuesta exitosa normal
     * 
     * @return Response con el catálogo de productos o datos degradados del fallback
     * @throws InterruptedException si el thread es interrumpido durante la
     *                              simulación de latencia
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response getProducts() throws InterruptedException {
        int chance = random.nextInt(10);

        // Simular latencia degradada en la base de datos (20% de probabilidad)
        if (chance < 2) {
            LOG.warning("Simulando latencia alta en consulta de catálogo...");
            Thread.sleep(1200);
        }

        // Simular falla de conexión a la base de datos (30% de probabilidad)
        if (chance >= 2 && chance < 5) {
            LOG.severe("Falla de conexión a la base de datos primaria.");
            throw new RuntimeException("Database connection timeout");
        }

        // Respuesta exitosa (50% de probabilidad)
        LOG.info("Catálogo retornado exitosamente desde la base de datos primaria.");
        return Response.ok("{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}").build();
    }

    /**
     * Endpoint de prueba simple para verificar que el servicio está respondiendo.
     * No tiene patrones de resiliencia configurados.
     * 
     * @return Response con mensaje de bienvenida
     */
    @GET
    @Path("/hello")
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return "Catalog Service v1.0.0 - Unidad 1 - Alta Disponibilidad";
    }
}
