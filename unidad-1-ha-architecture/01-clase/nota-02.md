# Metodología 12-Factor: Principios para Aplicaciones Cloud-Native

## Introducción

La **metodología 12-Factor** es un conjunto de prácticas y principios desarrollado por los creadores de Heroku para construir aplicaciones modernas entregadas como servicio (_Software as a Service_ - SaaS). Aunque fue formalizado en 2011, sigue siendo la base arquitectónica de cualquier aplicación **cloud-native**, **resiliente** y **escalable**.

### ¿Por qué es relevante para Alta Disponibilidad?

En el contexto de esta unidad sobre **alta disponibilidad y resiliencia**, la metodología 12-Factor proporciona los **cimientos arquitectónicos** necesarios para que los patrones de resiliencia (timeout, retry, circuit breaker, fallback) implementados a nivel de aplicación puedan funcionar correctamente en entornos distribuidos como Kubernetes.

---

## Los 12 Factores

| # | Factor | Principio | Relevancia para HA |
|---|--------|-----------|-------------------|
| **I** | **Codebase** | Un repositorio de código único rastreado en control de versiones, múltiples despliegues | Garantiza consistencia entre entornos (dev, staging, prod) |
| **II** | **Dependencies** | Declarar y aislar explícitamente todas las dependencias | Reduce sorpresas en producción; facilita reproducibilidad |
| **III** | **Config** | Almacenar configuración en variables de entorno, no en código | Permite cambiar comportamiento (timeouts, retries) sin recompilar |
| **IV** | **Backing Services** | Tratar bases de datos, colas y cachés como recursos conectables | Simplifica failover y replicación (multi-AZ databases) |
| **V** | **Build, Release, Run** | Separar estrictamente las fases de construcción, lanzamiento y ejecución | Reduce el riesgo de despliegues defectuosos |
| **VI** | **Processes** | Ejecutar la aplicación como procesos **stateless** | Facilita escalado horizontal y recuperación automática |
| **VII** | **Port Binding** | Exportar servicios mediante binding a puertos (sin servidor web externo) | Permite contenedores autónomos y portables |
| **VIII** | **Concurrency** | Escalar por modelo de procesos (múltiples instancias paralelas) | Distribuye carga entre nodos; base para alta disponibilidad |
| **IX** | **Disposability** | Maximizar robustez con inicio rápido y cierre elegante | Crítico para self-healing en Kubernetes (pod reinicios) |
| **X** | **Dev/Prod Parity** | Mantener dev, staging y producción lo más similares posible | Evita sorpresas en despliegues; mejora predictibilidad |
| **XI** | **Logs** | Tratar logs como flujos de eventos (enviar a stdout) | Facilita monitoreo centralizado y detección de fallos |
| **XII** | **Admin Processes** | Ejecutar tareas administrativas como procesos ephemeral | Evita punto único de falla en mantenimiento |

---

## Conexión con Alta Disponibilidad

### Factor VI (Processes) - El corazón de la HA

La **aplicación debe ser stateless** (sin estado local). Esto significa:

- ❌ NO guardar sesiones, datos cacheados ni estado en memoria local
- ✅ SÍ usar cachés centralizados (Redis), sesiones en bases de datos
- ✅ SÍ almacenar estado **fuera** de la aplicación

**Por qué importa:** Si el Pod se reinicia (por autohealingde Kubernetes), no se pierden datos. El siguiente Pod que atienda la solicitud puede acceder al estado desde la caché/BD centralizada.

### Factor IX (Disposability) - Recuperación Automática

Startup y shutdown rápidos permiten a Kubernetes:

- Balancear carga dinámicamente
- Reemplazar Pods defectuosos en segundos
- Realizar despliegues sin interrupción (rolling updates)

**Ejemplo:** Si un Pod entra en estado `CrashLoopBackOff`, Kubernetes puede reemplazarlo en < 30 segundos si sigue Factor IX.

### Factor III (Config) - Patrones de Resiliencia Dinámicos

Los timeouts, reintentos y circuit breakers no deben estar hardcodeados:

```properties
# application.properties (o variables de entorno)
microprofile.fault.tolerance.timeout=800
microprofile.fault.tolerance.retry.max-retries=2
microprofile.fault.tolerance.circuit-breaker.delay=5000
```

Esto permite ajustar resiliencia **sin recompilar**, crítico en producción.

### Factor X (Dev/Prod Parity) - Coherencia Ambiental

Usar la misma versión de:

- Docker base images (Java 21, Quarkus 3.38.0)
- Drivers de BD
- Sistemas operativos

Evita errores como: "funciona en mi máquina pero no en Kubernetes".

---

## Checklist: ¿Tu aplicación es 12-Factor?

- [ ] Código en un único repositorio Git
- [ ] Dependencias declaradas en `pom.xml` (Maven) o `package.json` (Node)
- [ ] Configuración en variables de entorno, no hardcodeada
- [ ] BD tratada como recurso externo (connection string desde config)
- [ ] Build → Release → Run como pasos separados (Docker build → push → kubectl apply)
- [ ] Procesos sin estado (stateless)
- [ ] Aplicación escucha en puerto configurado
- [ ] Múltiples procesos en paralelo (réplicas en Kubernetes)
- [ ] Startup < 10 segundos, shutdown elegante (SIGTERM handling)
- [ ] Entornos consistentes (mismo Dockerfile para dev y prod)
- [ ] Logs a stdout (stdout → agregador centralizado como ELK/Loki)
- [ ] Admin tasks como Pods ephemeral (ej. migraciones de BD)

---

## Aplicabilidad a Unidad 1

En esta unidad construimos un `catalog-service` que sigue la metodología 12-Factor:

| Elemento | Implementación |
|----------|-----------------|
| **Codebase** | Repositorio Git único con `src/`, `pom.xml`, `Dockerfile`, `k8s/` |
| **Dependencies** | `pom.xml` con Quarkus, MicroProfile Fault Tolerance |
| **Config** | `application.properties` para timeout, retry, circuit-breaker |
| **Backing Services** | BD accedida via JDBC (tratable como recurso externo) |
| **Processes** | Stateless: `@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback` devuelven valores sin almacenar en memoria |
| **Port Binding** | Quarkus escucha en puerto 8080 (configurable) |
| **Disposability** | Health checks (`ReadinessHealthCheck.java`) permitenautohealingde Kubernetes |
| **Logs** | Quarkus logea a stdout (capturable por Kubernetes) |

---

## Referencias

- Documentación oficial: [https://12factor.net/](https://12factor.net/)
- Aplicable a: Java, Python, Node.js, Go, Ruby, etc.
- Adoptado por: Heroku, AWS, Azure, Google Cloud, Kubernetes

---

**Próximas unidades:** En Unidad 2 (Kubernetes) y Unidad 3 (Networks) profundizaremos en cómo cada factor interactúa con orquestación, service discovery y load balancing en entornos cloud-native.
