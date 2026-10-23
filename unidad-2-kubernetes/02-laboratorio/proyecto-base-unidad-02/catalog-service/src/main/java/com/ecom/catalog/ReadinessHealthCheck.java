package com.ecom.catalog;

import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Readiness;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Random;

/**
 * Readiness Health Check personalizado para el servicio de catálogo.
 * 
 * Este health check determina si el servicio está listo para recibir tráfico.
 * Kubernetes usa este endpoint para decidir cuándo agregar el pod al
 * balanceador de carga.
 * 
 * En producción, este check validaría conectividad real a:
 * - Base de datos primaria
 * - Base de datos de réplicas de lectura
 * - Cache (Redis/Memcached)
 * - Servicios externos críticos
 * 
 * Para esta unidad de aprendizaje, simulamos la disponibilidad con un 95% de
 * éxito.
 */
@Readiness // Este check se vincula al endpoint /ready.
@ApplicationScoped
public class ReadinessHealthCheck implements HealthCheck {

    private final Random random = new Random();

    /**
     * Método de verificación que Kubernetes invoca periódicamente en /ready
     * 
     * @return HealthCheckResponse con estado UP o DOWN
     */
    @Override
    public HealthCheckResponse call() {
        // En producción, aquí validaríamos conectividad real a DB/Redis
        boolean isReady = checkDatabaseCluster();

        if (isReady) {
            return HealthCheckResponse.up("catalog-database-check");
        } else {
            return HealthCheckResponse.down("catalog-database-check");
        }
    }

    /**
     * Simula la verificación de conectividad al cluster de base de datos.
     * 
     * En un entorno real, este método haría:
     * - SELECT 1 contra la base de datos primaria
     * - Verificar conexión a réplicas de lectura
     * - Validar latencia aceptable (<50ms)
     * 
     * Para propósitos educativos, simulamos un 95% de disponibilidad.
     * 
     * @return true si el cluster está disponible, false en caso contrario
     */
    private boolean checkDatabaseCluster() {
        // Simular 95% de disponibilidad (solo falla el 5% del tiempo)
        return random.nextInt(100) >= 5;
    }
}
