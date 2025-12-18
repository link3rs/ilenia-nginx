# 8. Operación Fase 2 (Auth + Redis + Event-Service + PostgreSQL local)

Este capítulo define la **fase operativa objetivo** del sistema (según el diagrama):

- `nginx` como punto de entrada (TLS, reverse proxy)
- `react-frontend` como UI
- `auth-service` para autenticación y autorización
- `event-service` para CRUD de eventos, persistiendo en PostgreSQL
- `live-event-service` para el runtime de audio/transcripción/traducción y WebSockets
- `redis` para estado efímero de sesión/cachés
- `postgres` **en local** (contenedor) para persistencia (Fase 2)

## 8.1 Rutas públicas (vía Nginx)

- `/` → `react-frontend`
- `/api/auth/*` → `auth-service:8081`
- `/api/events/*` → `event-service:8083`
- `/api/live/*` → `live-event-service:8082`
- `/ws/live/*` → `live-event-service:8082` (WebSocket)

## 8.2 Roles y seguridad

- El frontend obtiene un **JWT** desde `auth-service`.
- El frontend envía el JWT:
  - En REST: `Authorization: Bearer <token>`
  - En WebSocket manager: `?access_token=<JWT>` (según implementación actual del endpoint `/v2/manager/{session_id}`)

## 8.3 Separación de responsabilidades (Fase 2)

- `event-service`:
  - Es la **fuente de verdad** de eventos.
  - Expone CRUD de eventos y canales.
  - Persiste en `postgres`.

- `live-event-service`:
  - Orquesta STT/MT/TTS + WebSockets.
  - Consume la configuración del evento desde `event-service` (y opcionalmente cachea en Redis).
  - Mantiene **estado en vivo** (presencia, contadores, canales activos) en Redis.

## 8.4 PostgreSQL local (contenedor) y persistencia

En Fase 2, el almacenamiento de eventos deja de ser un `events.json` y pasa a:

- `postgres` (contenedor) con volumen persistente (p. ej. `postgres-data`).

Recomendación mínima de persistencia:

- `postgres-data` → `/var/lib/postgresql/data`

## 8.5 Redis (estado efímero)

Redis se levanta con `docker compose up` y se utiliza para:

- estado efímero de sesiones
- caché de captions / últimas traducciones por canal
- coordinación (si se evoluciona a múltiples instancias)

Volumen recomendado:

- `redis-data` → `/data`

## 8.6 Volúmenes recomendados (Fase 2)

Además de los de Nginx:

- `nginx-logs` → `/var/log/nginx`
- `certbot-webroot` → `/var/www/certbot`

Se recomienda persistir:

- `live-recordings` → `/app/recordings` (`live-event-service`)
- `live-logs` → `/app/logs` (`live-event-service`)
- `redis-data` → `/data` (`redis`)
- `postgres-data` → `/var/lib/postgresql/data` (`postgres`)

## 8.7 Operación (arranque / verificación)

- `docker compose pull`
- `docker compose up -d`

Checks:

- `https://<dominio>/health` (nginx)
- `https://<dominio>/api/live/health` (live-event-service)
- `https://<dominio>/api/auth/...` (auth-service)
- `https://<dominio>/api/events/...` (event-service)

## 8.8 Migración desde Fase 1 (events.json → PostgreSQL)

Estado actual:

- `live-event-service` persiste eventos en JSON (Fase 1) y el frontend consume `/api/live/events`.

Objetivo Fase 2:

- CRUD en `event-service` (`/api/events/...`) con PostgreSQL.
- `live-event-service` deja de ser el dueño del CRUD y pasa a consumir configuración.

Puntos de migración a contemplar:

- Copiar eventos existentes desde `events.json` a tablas de PostgreSQL.
- Actualizar el frontend para usar `VITE_EVENTS_API_URL` apuntando a `/api/events` (o adaptar el routing en Nginx).
- Mantener durante transición un modo de compatibilidad (lectura en `event-service` y/o proxy temporal).

## 8.9 Nota sobre event-service en este workspace

En este workspace se documenta `event-service` como componente de Fase 2 según el diseño/diagrama y la configuración de rutas en `ilenia-nginx/README.md`.

Los detalles internos (schema SQL exacto, endpoints completos, healthcheck, etc.) deben alinearse con el repositorio/código real de `event-service` cuando esté disponible en el entorno de desarrollo.
