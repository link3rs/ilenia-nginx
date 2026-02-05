# Ilenia Nginx - Reverse Proxy

## Descripción del Proyecto
Configuración de Nginx como reverse proxy para el ecosistema Ilenia. Gestiona SSL/TLS, routing a microservicios, WebSocket upgrades, CORS, rate limiting y seguridad.

**Tech Stack**: Nginx, Docker, Let's Encrypt, Redis

## Arquitectura del Workspace
Este proyecto es parte del ecosistema Ilenia y actúa como punto de entrada para:
- **Frontend React**: `/Users/link3rs/Developer/JSWorkshop/github.com/link3rs/ilenia-react-frontend`
- **Live Service**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-live-event-service`
- **Auth Service**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-auth-service`
- **Events Service**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-events-service`
- **LiveKit Provider**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-livekit-provider`

## Archivos Clave
- [nginx/nginx.conf](nginx/nginx.conf) - Configuración global de Nginx
- [nginx/ilenia.link3rs.com.conf](nginx/ilenia.link3rs.com.conf) - Virtual host con SSL y routing
- [docker-compose.yml](docker-compose.yml) - Orquestación completa de servicios
- [docker-compose.local.yml](docker-compose.local.yml) - Configuración para desarrollo local
- [docker-compose.no-auth.yml](docker-compose.no-auth.yml) - Sin autenticación (testing)
- [Dockerfile](Dockerfile) - Imagen de Nginx personalizada

## Routing de URLs
### Frontend
- `https://ilenia.link3rs.com/` → React app
- `https://ilenia.link3rs.com/health` → Health check de Nginx

### REST APIs
- `https://ilenia.link3rs.com/api/live/*` → Live service (puerto 8082)
- `https://ilenia.link3rs.com/api/auth/*` → Auth service (puerto 8081)
- `https://ilenia.link3rs.com/api/events/*` → Events service (futuro)

### WebSockets
- `wss://ilenia.link3rs.com/ws/live/v2/captions` → Subtítulos
- `wss://ilenia.link3rs.com/ws/live/v2/speaker/{id}` → Canal speaker
- `wss://ilenia.link3rs.com/ws/live/v2/manager/{id}` → Canal manager

## Servicios Gestionados
El `docker-compose.yml` orquesta:
1. **ilenia-redis** - Cache y sesiones (puerto 6379, interno)
2. **ilenia-nginx** - Reverse proxy (puertos 80/443)
3. **ilenia-frontend** - React app
4. **ilenia-live-service** - Backend de eventos en vivo
5. **ilenia-auth-service** - Autenticación JWT
6. **ilenia-auth-keys-init** - Init container (configura permisos de JWT keys)

## Comandos Comunes
```bash
# Desarrollo local
docker-compose -f docker-compose.local.yml up -d

# Producción (con SSL)
docker-compose up -d

# Ver logs
docker-compose logs -f nginx
docker-compose logs -f live-service

# Verificar estado
docker-compose ps

# Actualizar un servicio
docker-compose pull live-service
docker-compose up -d live-service

# Reiniciar todo
docker-compose restart

# Detener todo
docker-compose down

# Backup de datos
docker cp ilenia-live-service:/app/data/events.json ./backup-events.json
docker exec ilenia-redis redis-cli BGSAVE
```

## Configuración SSL/TLS
Certificados Let's Encrypt montados desde el host:
```
/etc/letsencrypt/live/ilenia.link3rs.com/fullchain.pem
/etc/letsencrypt/live/ilenia.link3rs.com/privkey.pem
```

Renovación automática con certbot en el host:
```bash
sudo certbot renew --dry-run
```

## Características de Seguridad
- ✅ HTTP to HTTPS redirect automático
- ✅ SSL/TLS (Mozilla Intermediate profile)
- ✅ HSTS headers
- ✅ Rate limiting (10 req/s API, 5 req/s WebSocket)
- ✅ CORS configurado para orígenes permitidos
- ✅ Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- ✅ Gzip compression para contenido estático

## Redis
Redis se usa para:
- Estado de sesiones en vivo
- Cache de subtítulos en tiempo real
- Datos temporales durante sesiones activas

Configuración:
- Imagen: `redis:7-alpine`
- Persistencia: AOF (Append-Only File)
- Memoria máxima: 256MB
- Eviction: `allkeys-lru`

Comandos útiles:
```bash
# Health check
docker exec ilenia-redis redis-cli ping

# Ver memoria usada
docker exec ilenia-redis redis-cli info | grep used_memory_human

# Ver todas las keys
docker exec ilenia-redis redis-cli keys '*'
```

## PostgreSQL
PostgreSQL se usa para persistencia de datos en:
- **Auth Service** - Usuarios, roles, permisos (DB: `ilenia_auth`)
- **Events Service** - Eventos, canales, asignaciones (DB: `ilenia_events`)

### Arquitectura de BD
- **Opción implementada**: 1 clúster PostgreSQL, 2 bases de datos, 2 usuarios
- **Container**: `ilenia-postgres`
- **Puerto**: 5432 (interno)
- **Tecnología**: PostgreSQL 16, SQLAlchemy 2.0, Alembic

### Estructura
```
PostgreSQL Container
├── ilenia_auth (DB)
│   └── ilenia_auth_user (owner)
│       ├── users
│       ├── roles
│       ├── permissions
│       └── oauth_clients
└── ilenia_events (DB)
    └── ilenia_events_user (owner)
        ├── events
        ├── channels
        ├── event_speakers
        └── event_listeners
```

### Ventajas
- ✅ Aislamiento real por servicio
- ✅ Backups/restore independientes
- ✅ Rotación de credenciales por servicio
- ✅ Migraciones independientes (Alembic)

### Stack de Persistencia
- **ORM**: SQLAlchemy 2.0 (async con `asyncpg`)
- **Migraciones**: Alembic (cada servicio con su `alembic.ini`)
- **Schemas**: Pydantic v2 (separados de modelos ORM)

### Comandos útiles
```bash
# Conectar a auth DB
docker exec -it ilenia-postgres psql -U ilenia_auth_user -d ilenia_auth

# Conectar a events DB
docker exec -it ilenia-postgres psql -U ilenia_events_user -d ilenia_events

# Backup
docker exec ilenia-postgres pg_dump -U ilenia_auth_user ilenia_auth > backup_auth.sql
docker exec ilenia-postgres pg_dump -U ilenia_events_user ilenia_events > backup_events.sql

# Ver conexiones activas
docker exec ilenia-postgres psql -U postgres -c "SELECT datname, usename, application_name FROM pg_stat_activity WHERE datname IN ('ilenia_auth', 'ilenia_events');"
```

Ver documentación detallada:
- [ILENIA_ECOSYSTEM.md](ILENIA_ECOSYSTEM.md) - Arquitectura completa
- Auth Service: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-auth-service/POSTGRESQL.md`
- Events Service: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-events-service/POSTGRESQL.md`

## Volúmenes Docker
- `postgres-data` - Persistencia de PostgreSQL
- `redis-data` - Persistencia de Redis
- `live-data` - Archivo `events.json` del live service (legacy, migrar a PostgreSQL)
- `live-recordings` - Grabaciones de audio
- `live-logs` - Logs de aplicación
- `nginx-logs` - Logs de Nginx
- `auth-keys` - Claves RSA para JWT (private.pem, public.pem)

## Variables de Entorno
Ver [.env.example](.env.example). Principales:
- `HF_ASR_URL`, `HF_ASR_TOKEN` - HuggingFace STT
- `HF_MT_URL`, `HF_MT_TOKEN` - HuggingFace MT
- `AUTH_ISSUER` - Issuer de JWT (ej: `https://auth.ilenia.link3rs.com`)
- `AUTH_SEED_ADMIN_*` - Usuario admin inicial

## Documentación Adicional
- [README.md](README.md) - Guía completa de despliegue
- [Uso-de-redis.md](Uso-de-redis.md) - Documentación de Redis
- [manual/](manual/) - Manuales de configuración

## Notas de Desarrollo
- Nginx corre en puertos 80 (HTTP) y 443 (HTTPS)
- Los servicios backend NO están expuestos directamente, solo vía proxy
- Usa `docker-compose.local.yml` para desarrollo sin SSL
- Los logs de Nginx se guardan en el volumen `nginx-logs`
- Para debugging, usa `docker-compose logs -f <servicio>`
