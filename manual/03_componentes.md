# 3. Componentes y responsabilidades

## 3.1 Nginx (reverse proxy)

Responsabilidades principales:

- Terminación TLS (certificados Let's Encrypt en el droplet).
- Enrutado por path hacia frontend, APIs y WebSockets.
- Soporte WebSocket (`Upgrade`, `Connection`), timeouts largos.
- CORS, rate limiting y security headers.

Referencia de rutas (Fase 2):

- `/` → `react-frontend`
- `/api/auth/*` → `auth-service`
- `/api/events/*` → `event-service`
- `/api/live/*` → `live-service`
- `/ws/live/*` → `live-service` (WebSocket)

## 3.2 React Frontend

- UI para managers/speakers/listeners.
- Configuración de endpoints de ASR/MT (p. ej. HuggingFace) desde el navegador.
- Conexión a REST (`/api/live`) y WebSocket (`/ws/live`).

Variables típicas en producción:

- `VITE_BACKEND_URL=https://<dominio>/api/live`
- `VITE_WS_URL=wss://<dominio>/ws/live`

## 3.3 Live service (`live-service` / `live-event-service`)

- Orquestación de la sesión en vivo.
- Recepción de audio del speaker (vía WebSocket) y generación de transcripción.
- Traducción a canales/idiomas objetivo.
- Publicación de captions a listeners.
- Runtime de audio y streaming (STT/MT/TTS) + distribución de captions.
- En Fase 2, **no es la fuente de verdad** del CRUD de eventos: consume la configuración desde `event-service`.
- En fase transitoria, puede seguir soportando CRUD con persistencia JSON hasta completar la migración.

## 3.4 Redis

Uso (Fase 2):

- Estado efímero de sesión (presencia, contadores, canales activos).
- Caché de captions y datos efímeros.
- Persistencia AOF habilitada mediante volumen Docker.

## 3.5 auth-service / event-service / PostgreSQL

Diseño (Fase 2):

- `auth-service` para emisión/validación de tokens (roles/permisos).
- `event-service` + PostgreSQL local como fuente de verdad para eventos y canales.
- `live-service` consume configuración desde `event-service` y usa Redis como caché/estado runtime.
