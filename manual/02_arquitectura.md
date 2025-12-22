# 2. Arquitectura y diagrama del sistema

## Visión general

En producción, los clientes (workstation, smartphone, laptop) acceden a un único dominio (por ejemplo `https://ilenia.link3rs.com`). **Nginx** enruta las peticiones a los contenedores internos.

### Fase 2 (operativa objetivo)

- `nginx` (80/443): reverse proxy
- `react-frontend` (80 interno): interfaz web
- `auth-service` (8081): autenticación/autorización
- `event-service` (8083): CRUD de eventos y canales (persistencia en PostgreSQL local)
- `live-service` (8082): runtime de audio, STT/MT/TTS y WebSockets
- `redis` (6379 interno): estado efímero de sesión/caché

### Fase 1 (transitoria)

- `nginx` (80/443): reverse proxy
- `react-frontend` (80 interno): interfaz web
- `live-service` (8082): orquestación de sesión en vivo, WebSockets, CRUD de eventos (persistencia JSON) hasta migración
- `redis` (6379 interno): estado de sesión, caché de captions y datos efímeros

## Mapeo de URLs (Fase 2)

### Frontend

- `/` → `react-frontend`

### APIs REST (Fase 2)

- `/api/auth/*` → `auth-service`
- `/api/events/*` → `event-service`
- `/api/live/*` → `live-service`

### WebSockets (Fase 2)

- `/ws/live/v2/manager/{session_id}` → manager
- `/ws/live/v2/speaker/{event_id}/{channel_id}` → speaker
- `/ws/live/v2/captions/{event_id}/{lang_code}` → listeners captions

## Redes y contenedores

Los contenedores corren en una red Docker compartida (por ejemplo `ilenia-net`).

- Desde internet se expone **solo Nginx**.
- Los servicios internos se comunican por nombre de servicio dentro de la red Docker.

## Dependencias principales

- `nginx` depende de `react-frontend`, `live-service`, `auth-service` y `event-service`.
- `live-service` depende de `redis` (healthcheck OK).
- `event-service` depende de `postgres`.
