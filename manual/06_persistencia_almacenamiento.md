# 6. Persistencia y almacenamiento (estado, audios, transcripciones)

## 6.1 Estado de sesión

- En **Phase 1 (docker-compose.no-auth.yml)** el estado efímero de las sesiones en vivo se apoya en **Redis**.
- Redis usa persistencia AOF y un volumen Docker, por lo que persiste entre reinicios de contenedor.

### Volúmenes implicados

- `redis-data` → `/data` (contenedor `ilenia-redis`)

### Notas operativas

- La retención real de estado en Redis depende de:
  - la política de memoria (`--maxmemory 256mb --maxmemory-policy allkeys-lru`)
  - el uso que haga `live-service` (caché, estado de presencia, etc.).

## 6.2 Eventos (fase 1)

- El CRUD de eventos está expuesto por `live-service`.
- En **Phase 1 (docker-compose.no-auth.yml)** la persistencia actual es en un fichero JSON en un volumen Docker.

### Volúmenes implicados (Phase 1)

- `live-data` → `/app/data` (contenedor `ilenia-live-service`)

### Ruta del fichero

- `EVENTS_STORAGE_PATH=/app/data/events.json`

## 6.3 Eventos (Fase 2)

En Fase 2, el CRUD de eventos se mueve a `event-service` y se persiste en **PostgreSQL local (contenedor)**.

- `event-service` es la fuente de verdad.
- `live-service` deja de persistir eventos y pasa a consumir configuración (y, si aplica, cachear en Redis).

Volúmenes recomendados:

- `postgres-data` → `/var/lib/postgresql/data` (contenedor `postgres`)

## 6.4 Grabaciones de audio (estado actual)

- `live-service` guarda grabaciones de audio en un volumen Docker.
- Este almacenamiento reside **en local dentro del droplet** (no es un almacenamiento externo gestionado).

### Volúmenes implicados

- `live-recordings` → `/app/recordings` (contenedor `ilenia-live-service`)

### Notas

- La grabación se activa en el pipeline cuando en `SessionCreate.channels[]` existe al menos un canal con `record=true`.
- El guardado definitivo puede ocurrir al destruir la sesión (`SessionDestroy`) o en cleanup.

## 6.5 Transcripciones y SRT

- En el estado actual, lo que se persiste en disco de forma explícita en este stack es:
  - grabaciones de audio
  - logs
  - (Phase 1) fichero `events.json`

Si además se generan artefactos tipo **SRT** en el servicio, deben almacenarse dentro de un volumen (por ejemplo `live-data` o `live-recordings`) para persistir entre reinicios.

## 6.6 Logs

Este stack persiste logs por dos vías:

1. **Logs a fichero dentro del contenedor**, persistidos por volumen
   - `live-logs` → `/app/logs` (contenedor `ilenia-live-service`)
   - `nginx-logs` → `/var/log/nginx` (contenedor `ilenia-nginx`)
2. **Logs del runtime Docker** (driver `json-file`)
   - con rotación configurada (`max-size: 10m`, `max-file: 3`) en los servicios del compose.

## 6.7 Certificados (Let's Encrypt)

En `docker-compose.yml` y `docker-compose.no-auth.yml`, Nginx monta:

- `/etc/letsencrypt:/etc/letsencrypt:ro` (directorio del host; certificados gestionados fuera de Docker)
- `certbot-webroot` → `/var/www/certbot` (webroot para challenges)

## 6.8 Dónde se guardan físicamente los volúmenes en el droplet

Por defecto (Docker Engine en Linux), los volúmenes viven en:

- `/var/lib/docker/volumes/<volume_name>/_data`

### Volúmenes declarados por compose

- `docker-compose.yml` (con `auth-service`):
  - `certbot-webroot`, `nginx-logs`, `live-recordings`, `live-logs`
- `docker-compose.no-auth.yml` (Phase 1 sin auth):
  - `certbot-webroot`, `nginx-logs`, `live-recordings`, `live-logs`, `live-data`, `redis-data`

Ejemplos (según el compose):

- `/var/lib/docker/volumes/nginx-logs/_data`
- `/var/lib/docker/volumes/live-recordings/_data`
- `/var/lib/docker/volumes/live-logs/_data`
- `/var/lib/docker/volumes/live-data/_data` (Phase 1)
- `/var/lib/docker/volumes/redis-data/_data` (Phase 1)

## 6.9 Backups y restore (recomendación operativa)

El objetivo mínimo es poder recuperar:

- (Phase 1) `events.json`
- grabaciones (`/app/recordings`)
- logs (si son necesarios para auditoría/debug)
- (Phase 1) Redis AOF/RDB (si se desea continuidad de estado)
- (Fase 2) PostgreSQL (si `event-service` persiste en Postgres local)

### Backup (método 1): copiar desde contenedores

- `events.json` (Phase 1)
  - `docker cp ilenia-live-service:/app/data/events.json ./backup/events.json`
- grabaciones
  - `docker cp ilenia-live-service:/app/recordings ./backup/recordings`
- logs
  - `docker cp ilenia-live-service:/app/logs ./backup/live-logs`
  - `docker cp ilenia-nginx:/var/log/nginx ./backup/nginx-logs`

### Backup (Fase 2): export lógico de PostgreSQL

- Recomendación: usar dumps lógicos (`pg_dump`) además del volumen.
- Ejemplo (si el contenedor se llama `postgres`):
  - `docker exec -t postgres pg_dump -U <user> <db> > ./backup/postgres.dump.sql`

### Backup (método 2): copiar desde volúmenes (en el host)

- Copiar directamente desde `/var/lib/docker/volumes/.../_data`.
- Recomendación: comprimir y versionar por fecha (y, si aplica, cifrar).

### Restore (idea)

- Con el stack detenido (`docker compose down`), restaurar los ficheros dentro de:
  - `/var/lib/docker/volumes/live-recordings/_data`
  - `/var/lib/docker/volumes/live-data/_data` (Phase 1)
  - `/var/lib/docker/volumes/live-logs/_data`
  - `/var/lib/docker/volumes/nginx-logs/_data`
  - `/var/lib/docker/volumes/redis-data/_data` (Phase 1)
- Para Fase 2 (PostgreSQL):
  - restaurar `postgres-data` o aplicar `psql < ./backup/postgres.dump.sql` según estrategia.
- Levantar el stack (`docker compose up -d`).

## 6.10 Consideraciones de capacidad (disco)

Al ser almacenamiento local, es crítico vigilar el disco del droplet:

- `live-recordings` puede crecer muy rápido.
- `nginx-logs` y `live-logs` pueden crecer (aunque Docker `json-file` ya rota).

Recomendación: definir política de retención (p. ej. borrar grabaciones antiguas por fecha o por evento) y, si más adelante se migra a storage externo, hacer el cutover de este capítulo.

En el futuro, este apartado puede migrar a almacenamiento externo (S3 compatible) para durabilidad y escalabilidad.
