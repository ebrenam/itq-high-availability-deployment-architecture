# Catalog Service - Unidad 1

**Servicio de catálogo** para la plataforma e-commerce - Parte del proyecto integrador de **Arquitectura de despliegue de alta disponibilidad**.

## 📋 Descripción

Microservicio base que simula latencia, fallas y health checks. Los patrones de resiliencia (Timeout, Retry, Circuit Breaker, Fallback) se implementan progresivamente en los laboratorios.

## 🛠️ Stack

- **Java**: OpenJDK 25
- **Framework**: Quarkus 3.38.0
- **Build**: Maven 3.9.6


## 🚀 Ejecución Rápida

```bash
./mvnw quarkus:dev
```

Endpoints:
- `http://localhost:8080/v1/products` — Catálogo con simulación
- `http://localhost:8080/health` — Health check
- `http://localhost:8080/ready` — Readiness probe
- `http://localhost:8080/live` — Liveness probe

## 📚 Laboratorios

Consulta los detalles de ejecución, troubleshooting y despliegue en los archivos de laboratorio:

- [Laboratorio 1.1](../laboratorio-clase-1-1.md) — Línea base de disponibilidad
- [Laboratorio 1.2](../laboratorio-clase-1-2.md) — Patrones de resiliencia básicos
- [Laboratorio 1.3](../laboratorio-clase-1-3.md) — Despliegue en Kubernetes
- **Unidad 5**: Integrar observabilidad con Prometheus, Grafana y OpenTelemetry

## 🤝 Contribución

Este proyecto es parte del material educativo de la asignatura. Para sugerencias o mejoras, contacta al instructor.

## 📄 Licencia

Material educativo - Instituto Tecnológico de Querétaro © 2026
