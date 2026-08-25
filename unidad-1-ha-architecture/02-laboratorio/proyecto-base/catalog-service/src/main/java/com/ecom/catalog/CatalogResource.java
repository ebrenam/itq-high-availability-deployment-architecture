package com.ecom.catalog;

import org.eclipse.microprofile.faulttolerance.CircuitBreaker;
import org.eclipse.microprofile.faulttolerance.Fallback;
import org.eclipse.microprofile.faulttolerance.Retry;
import org.eclipse.microprofile.faulttolerance.Timeout;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Random;
import java.util.logging.Logger;

/**
 * Catalog Resource - Endpoint principal del servicio de catálogo.
 * Implementa patrones de resiliencia: Circuit Breaker, Retry, Timeout y
 * Fallback.
 * 
 * Este servicio simula consultas a una base de datos con latencia variable y
 * fallos
 * aleatorios para demostrar los mecanismos de tolerancia a fallos en acción.
 */
@Path("/v1/products")
public class CatalogResource {

    private static final Logger LOG = Logger.getLogger(CatalogResource.class.getName());
    private final Random random = new Random();

    /**
     * Endpoint principal que retorna el catálogo de productos.
     * 
     * Patrones de resiliencia configurados:
     * - Timeout: 800ms máximo de espera
     * - Retry: 2 reintentos con 150ms de pausa entre cada uno
     * - Circuit Breaker: Se abre si falla el 50% de las últimas 4 peticiones
     * - Fallback: Retorna datos en caché si el circuito está abierto o se agota el
     * timeout
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
    @Timeout(800) // Cancela la solicitud si toma más de 800ms
    @Retry(maxRetries = 2, delay = 150) // Reintenta máximo 2 veces con 150ms de pausa
    @CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5, delay = 5000) // Abre circuito si falla el 50%
    @Fallback(fallbackMethod = "getCatalogFallback") // Invoca respuesta degradada si falla o se abre el circuito
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
     * Método de fallback que se invoca cuando:
     * - El circuito está abierto (demasiadas fallas recientes)
     * - Se agota el timeout configurado
     * - Se agotan los reintentos sin éxito
     * 
     * Este método retorna datos en caché o degradados para mantener el servicio
     * parcialmente funcional durante incidentes de la base de datos.
     * 
     * @return Response con datos en caché y estado degradado
     */
    public Response getCatalogFallback() {
        LOG.info("Fallback activado: Sirviendo datos desde la memoria caché local.");
        return Response.ok("{\"status\":\"DEGRADED_CACHE\",\"data\":[\"Cached Product A\",\"Cached Product B\"]}")
                .build();
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
