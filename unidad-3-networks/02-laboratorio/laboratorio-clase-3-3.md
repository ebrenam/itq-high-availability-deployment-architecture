# **Laboratorio 3.3:** Endurecimiento con RBAC y Pod Security Admission

Aplicar una identidad de aplicación con permisos acotados, endurecer `payment-service` con `SecurityContext` y validar el perfil `Restricted` de Pod Security Admission (PSA).

> **Alcance:** El servicio de este laboratorio es el endpoint estático de demostración creado en el Laboratorio 3.1. No necesita consultar el API Server; por eso el token de ServiceAccount se desactiva en el Pod. El Role se usa para aprender y comprobar autorización mediante impersonación con `kubectl auth can-i`, no para habilitar llamadas innecesarias de la aplicación.

## Requisitos previos

- Laboratorios 3.1 y 3.2 completados.
- `payment-service` ejecutándose en `production` y con dos réplicas.
- Permisos administrativos para crear Roles y RoleBindings, configurar etiquetas de namespace y probar impersonación.
- El mismo clúster compatible con Envoy Gateway del Laboratorio 3.1 y `kubectl` compatible con el API Server.

## Paso 1: Revisar el alcance de Pod Security Admission

El modo `enforce` afecta a los Pods nuevos que se creen en el namespace, incluidos los recreados por actualizaciones o reprogramaciones. Comprueba qué workloads existen y confirma que puedes prepararlos todos para `Restricted` antes de activar la exigencia:

```bash
kubectl get deployments,statefulsets,daemonsets -n production
kubectl get pods -n production
```

En esta secuencia, el Deployment de aplicación creado en el Laboratorio 3.1 es `payment-service`. Si desplegaste otros workloads en `production`, audítalos y endurécelos también antes de activar `enforce`.

Primero activa advertencias y auditoría para detectar incumplimientos sin bloquear Pods:

```bash
kubectl label namespace production \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest \
  --overwrite
```

En producción, fija la versión del perfil a una versión de Kubernetes probada en lugar de dejar `latest`.

## Paso 2: Crear identidad y permisos RBAC mínimos

La aplicación de demostración no consume la API de Kubernetes. Se crea un permiso acotado a un solo ConfigMap únicamente para inspeccionar RBAC. No se concede acceso a Secrets.

Guarda como `06-rbac-payment-service.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-service-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payment-service-reader
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["payment-config"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payment-service-reader
  namespace: production
subjects:
  - kind: ServiceAccount
    name: payment-service-sa
    namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: payment-service-reader
```

Aplica y verifica la autorización. `--as` requiere que el usuario que ejecuta `kubectl` tenga permiso para impersonar ServiceAccounts:

```bash
kubectl apply -f 06-rbac-payment-service.yaml

kubectl auth can-i get configmaps/payment-config \
  --as=system:serviceaccount:production:payment-service-sa -n production
# Esperado: yes

kubectl auth can-i list configmaps \
  --as=system:serviceaccount:production:payment-service-sa -n production
# Esperado: no

kubectl auth can-i get secrets \
  --as=system:serviceaccount:production:payment-service-sa -n production
# Esperado: no

kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:payment-service-sa -n production
# Esperado: no
```

## Paso 3: Endurecer el Pod sin eliminar el Deployment

No elimines el Deployment: una actualización de su Pod template inicia un RollingUpdate y conserva el Service. Guarda el siguiente parche como `07-payment-security-patch.yaml`:

```yaml
spec:
  template:
    spec:
      serviceAccountName: payment-service-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: payment-service
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

Aplica el parche estratégico y espera el rollout:

```bash
kubectl patch deployment payment-service -n production \
  --type=strategic \
  --patch-file=07-payment-security-patch.yaml

kubectl rollout status deployment/payment-service -n production --timeout=120s
kubectl get pods -n production -l app=payment-service
```

El puerto de escucha es `8080`, por lo que `NET_BIND_SERVICE` no es necesario. `readOnlyRootFilesystem` es una medida de endurecimiento adicional; no es un requisito de PSS `Restricted`.

Comprueba que PSA en modo `warn` no notificó incumplimientos para el Pod nuevo. La imagen `hashicorp/http-echo` es distroless y no incluye shell ni utilidades como `id` o `touch`; valida la configuración efectiva del Pod con `jsonpath`:

```bash
kubectl get pods -n production -l app=payment-service \
  -o jsonpath='{range .items[*]}{.metadata.name}{" runAsNonRoot="}{.spec.securityContext.runAsNonRoot}{" runAsUser="}{.spec.securityContext.runAsUser}{" readOnlyRootFilesystem="}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}{end}'
```

Esperado: cada Pod muestra `runAsNonRoot=true`, `runAsUser=1000` y `readOnlyRootFilesystem=true`. La imagen no permite comprobar una escritura interactiva con `touch`; el endpoint HTTPS del final valida que la aplicación sigue respondiendo con estas restricciones.

## Paso 4: Aplicar `enforce=restricted`

Activa `enforce` solo cuando todos los workloads del namespace estén preparados. La etiqueta de versión `latest` facilita el ejercicio; para entornos estables fija el minor version apropiado:

```bash
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

kubectl get namespace production --show-labels
kubectl rollout status deployment/payment-service -n production
```

PSA evalúa los Pods al admitirlos; no reescribe ni remedia Pods ya existentes. Si una nueva revisión no cumple, el API Server la rechazará y el Deployment no progresará.

## Paso 5: Verificar servicio y controles

```bash
kubectl get pods,svc -n production
kubectl get role,rolebinding,serviceaccount -n production
kubectl auth can-i get configmaps/payment-config \
  --as=system:serviceaccount:production:payment-service-sa -n production
kubectl auth can-i get secrets \
  --as=system:serviceaccount:production:payment-service-sa -n production
```

Si el endpoint sigue respondiendo tras el cambio, el Service y la estrategia de actualización continúan operativos:

```bash
kubectl port-forward -n envoy-gateway-system \
  service/"$(kubectl get svc -n envoy-gateway-system \
    -l gateway.envoyproxy.io/owning-gateway-namespace=production,gateway.envoyproxy.io/owning-gateway-name=checkout-gateway \
    -o jsonpath='{.items[0].metadata.name}')" 8443:443
```

En otra terminal, desde el directorio donde está `checkout.crt`:

```bash
curl --cacert checkout.crt \
  --resolve checkout.local:8443:127.0.0.1 \
  https://checkout.local:8443/v1/payment
```

## Troubleshooting

- **El Pod es rechazado por `enforce`:** revisa el mensaje de admisión y los requisitos Restricted en Pod Security Standards. Verifica no-root, `allowPrivilegeEscalation: false`, `seccompProfile` permitido y `capabilities.drop: ["ALL"]`; confirma también que no se use un volumen prohibido.
- **El Deployment no completa el rollout:** usa `kubectl describe deployment` y `kubectl describe pod` para distinguir rechazo de PSA, error de imagen o fallo de readiness. No borres el Deployment como solución.
- **`kubectl auth can-i` falla aunque el RoleBinding exista:** confirma el namespace y el nombre exacto de la ServiceAccount; además, el usuario operador puede necesitar permiso para impersonar (`--as`).
- **La app no necesita hablar con el API Server:** conserva `automountServiceAccountToken: false` y no agregues permisos RBAC a la aplicación. Si un requerimiento real cambia, concede solo los recursos y verbos estrictamente necesarios.

## Evidencia y reflexión

Documenta el estado del Deployment, el Pod `Running`, los valores efectivos de seguridad, el resultado del rollout y las verificaciones `can-i`.

1. ¿Qué diferencia hay entre `runAsNonRoot` y `readOnlyRootFilesystem`?
2. ¿Por qué una ServiceAccount no necesita un Role si la aplicación no consulta el API Server?
3. ¿Por qué `pods/exec` se modela como subrecurso en RBAC y no como verbo `exec`?
4. ¿Qué diferencia existe entre los modos PSA `warn`, `audit` y `enforce`?

## Continuidad

Al completar este laboratorio se han practicado entrada HTTPS (3.1), aislamiento L3/L4 (3.2) y autorización/admisión/endurecimiento de Pods (3.3). Estos controles son capas distintas; ninguno sustituye por sí solo a los demás.

## Fuentes primarias

- Kubernetes Authors. _Pod Security Standards_. <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
- Kubernetes Authors. _Pod Security Admission_. <https://kubernetes.io/docs/concepts/security/pod-security-admission/>
- Kubernetes Authors. _Security Context_. <https://kubernetes.io/docs/tasks/configure-pod-container/security-context/>
- Kubernetes Authors. _RBAC Authorization_. <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>
- Kubernetes Authors. _RBAC good practices_. <https://kubernetes.io/docs/concepts/security/rbac-good-practices/>
- Kubernetes Authors. _Service Accounts_. <https://kubernetes.io/docs/concepts/security/service-accounts/>
