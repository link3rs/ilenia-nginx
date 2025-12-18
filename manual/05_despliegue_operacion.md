# 5. Despliegue y operación (Docker + Nginx + GHCR)

## 5.1 Requisitos

- Droplet DigitalOcean (Ubuntu 22.04+ recomendado)
- Docker y Docker Compose
- Dominio apuntando al droplet (A record)
- Certificados TLS (Let's Encrypt)
- Acceso a GHCR (docker login)

## 5.2 Despliegue (Fase 2)

La operativa objetivo (Fase 2) levanta el stack completo con:

- `nginx`
- `react-frontend`
- `auth-service`
- `event-service`
- `postgres` (local)
- `redis`
- `live-service`

Resumen del flujo:

1. Crear directorio de despliegue en el droplet.
2. `docker login ghcr.io` con token.
3. Preparar un `docker-compose.yml` de Fase 2 (o el que corresponda a tu despliegue).
4. Configurar `.env` (endpoints ASR/MT y tuning opcional, y variables de DB/auth si aplica).
5. `docker compose pull` y `docker compose up -d`.

## 5.3 Despliegue (Fase 1 transitoria)

En la fase transitoria (sin `event-service`), el CRUD de eventos vive en `live-service` y se persiste en JSON.

- Se usa el compose sin auth como base (incluye Redis y `EVENTS_STORAGE_PATH`).

## 5.4 Verificación rápida

- `https://<dominio>/health` (nginx)
- `https://<dominio>/api/live/health` (live-service)
- `https://<dominio>/api/auth/...` (auth-service)
- `https://<dominio>/api/events/...` (event-service)
- `https://<dominio>/` (frontend)

## 5.5 Logs y monitorización

- Logs Nginx en volumen dedicado.
- Logs de live-service en volumen dedicado.
- Redis con persistencia AOF en volumen.
- PostgreSQL con volumen de datos persistente.

## 5.6 Actualización

- `docker compose pull`
- `docker compose up -d`

(la estrategia exacta de cero downtime depende del servicio; en fase actual normalmente se recrean contenedores con la nueva imagen).
