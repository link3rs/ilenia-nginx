# 5. Despliegue y operación (Docker + Nginx + GHCR)

## 5.1 Requisitos

- Droplet DigitalOcean (Ubuntu 22.04+ recomendado)
- Docker y Docker Compose v2+
- Dominio apuntando al droplet (A record)
- Certificados TLS (Let's Encrypt)
- Acceso a GHCR (docker login)
- Variables de entorno configuradas (`.env`)

## 5.2 Despliegue (Fase 2 - Con Auth Service)

La operativa actual (Fase 2) levanta el stack con autenticación:

### Servicios desplegados:
- `nginx` - Reverse proxy con SSL
- `react-frontend` - Aplicación React SPA
- `auth-service` - Servicio de autenticación JWT
- `auth-keys-init` - Contenedor init para permisos de volumen
- `live-service` - Servicio de eventos en vivo (STT, MT, TTS)
- `redis` - Estado de sesión y caché

### Flujo de despliegue:

1. **Crear directorio de despliegue**:
   ```bash
   mkdir -p ~/ilenia-deployment
   cd ~/ilenia-deployment
   ```

2. **Login a GHCR**:
   ```bash
   docker login ghcr.io -u YOUR_GITHUB_USERNAME -p YOUR_GITHUB_TOKEN
   ```

3. **Descargar docker-compose.yml**:
   ```bash
   wget https://raw.githubusercontent.com/link3rs/ilenia-nginx/main/docker-compose.yml
   ```

4. **Configurar variables de entorno** (`.env`):
   ```bash
   cat > .env <<EOF
   # HuggingFace Endpoints
   HF_ASR_URL=https://your-asr-endpoint.aws.endpoints.huggingface.cloud
   HF_ASR_TOKEN=hf_your_token_here
   HF_MT_URL=https://your-mt-endpoint.aws.endpoints.huggingface.cloud/v1
   HF_MT_TOKEN=hf_your_token_here
   
   # Logging
   LOG_LEVEL=INFO
   
   # Auth Service (REQUERIDO)
   AUTH_ISSUER=https://ilenia.link3rs.com
   ACCESS_TTL_SECONDS=3600
   AUTH_SEED_ADMIN_EMAIL=admin@ilenia.link3rs.com
   AUTH_SEED_ADMIN_PASSWORD=your_secure_password_here
   AUTH_SEED_ADMIN_NAME=Admin
   AUTH_SEED_ADMIN_LANG=en
   EOF
   ```

5. **Desplegar servicios**:
   ```bash
   docker compose pull
   docker compose up -d
   ```

6. **Verificar despliegue**:
   ```bash
   docker compose ps
   # Esperado:
   # - ilenia-nginx (Up, healthy)
   # - ilenia-frontend (Up, healthy)
   # - ilenia-auth-service (Up, healthy)
   # - ilenia-live-service (Up, healthy)
   # - ilenia-redis (Up, healthy)
   # - ilenia-auth-keys-init (Exit 0)
   ```

## 5.3 Auth Service: Solución de permisos JWT keys

### Problema
El `auth-service` necesita generar claves RSA para firmar tokens JWT en el primer login. Estas claves se almacenan en `/app/keys/` dentro del contenedor.

**Desafío**: El contenedor corre como usuario no-root (`appuser`, uid `10001`) por seguridad, pero los volúmenes Docker se crean con ownership `root:root` por defecto, causando `PermissionError` al intentar escribir las claves.

### Solución: Init Container

El `docker-compose.yml` incluye un contenedor de inicialización que se ejecuta **antes** de `auth-service`:

```yaml
auth-keys-init:
  image: alpine:3.20
  container_name: ilenia-auth-keys-init
  restart: "no"                    # Solo se ejecuta una vez
  user: "0:0"                       # Corre como root
  volumes:
    - auth-keys:/app/keys
  command: ["sh", "-lc", "mkdir -p /app/keys && chown -R 10001:10001 /app/keys"]
  networks:
    - ilenia-net

auth-service:
  image: ghcr.io/link3rs/ilenia-auth-service:main
  depends_on:
    auth-keys-init:
      condition: service_completed_successfully  # Espera a que init termine
  volumes:
    - auth-keys:/app/keys
```

### Cómo funciona

1. **`auth-keys-init` se ejecuta primero** como root
2. Crea el directorio `/app/keys` en el volumen
3. Cambia ownership a `10001:10001` (appuser)
4. Sale con código 0 (éxito)
5. **`auth-service` arranca** solo después de que init complete
6. `auth-service` puede escribir claves JWT sin errores de permisos

### Verificación

```bash
# 1. Verificar que init completó exitosamente
docker compose ps auth-keys-init
# Output esperado: Exit 0

# 2. Verificar que auth-service está healthy
docker compose ps auth-service
# Output esperado: Up (healthy)

# 3. Probar endpoint de login (debe devolver 401, NO 500)
curl -i https://ilenia.link3rs.com/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test"}'
# Esperado: HTTP/2 401 Unauthorized
# NO esperado: HTTP/2 500 Internal Server Error

# 4. Verificar logs (NO debe haber PermissionError)
docker logs ilenia-auth-service --tail 50 | grep -i permission
# Output esperado: (vacío, sin errores de permisos)
```

### Troubleshooting

Si ves `500 Internal Server Error` en login con error en logs:
```
PermissionError: [Errno 13] Permission denied: '/app/keys/private.pem'
```

**Solución manual**:
```bash
cd ~/ilenia-deployment

# Arreglar ownership del volumen manualmente
docker run --rm -v ilenia-deployment_auth-keys:/app/keys alpine \
  sh -c "mkdir -p /app/keys && chown -R 10001:10001 /app/keys"

# Recrear auth-service
docker compose up -d --force-recreate auth-service

# Verificar
docker logs ilenia-auth-service --tail 20
curl -i https://ilenia.link3rs.com/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@ilenia.link3rs.com","password":"your_password"}'
```

### Seguridad

✅ **Ventajas de este enfoque**:
- `auth-service` corre como **no-root** (uid 10001)
- Claves JWT **persisten** en volumen Docker (`auth-keys`)
- Init container solo corre **una vez** al desplegar
- Solución **automática** sin intervención manual

⚠️ **Importante**:
- Las claves RSA se generan en el **primer login**
- Si borras el volumen `auth-keys`, se regenerarán nuevas claves
- Regenerar claves **invalida todos los tokens JWT existentes**

## 5.4 Despliegue (Fase 1 transitoria - sin Auth)

Si necesitas desplegar sin autenticación (solo para desarrollo/testing):

```bash
# Usar docker-compose.no-auth.yml
wget https://raw.githubusercontent.com/link3rs/ilenia-nginx/main/docker-compose.no-auth.yml -O docker-compose.yml
```

En esta fase, el CRUD de eventos vive en `live-service` y se persiste en JSON (`EVENTS_STORAGE_PATH`).

## 5.5 Verificación rápida

### Endpoints de salud

```bash
# Nginx
curl https://ilenia.link3rs.com/health
# Esperado: "healthy"

# Live Service
curl https://ilenia.link3rs.com/api/live/health
# Esperado: {"status":"healthy",...}

# Auth Service
curl https://ilenia.link3rs.com/api/auth/health
# Esperado: {"status":"healthy",...}

# Frontend
curl -I https://ilenia.link3rs.com/
# Esperado: HTTP/2 200
```

### Verificar contenedores

```bash
cd ~/ilenia-deployment
docker compose ps

# Salida esperada:
# NAME                      STATUS
# ilenia-auth-keys-init     Exited (0)
# ilenia-auth-service       Up (healthy)
# ilenia-frontend           Up (healthy)
# ilenia-live-service       Up (healthy)
# ilenia-nginx              Up (healthy)
# ilenia-redis              Up (healthy)
```

### Probar autenticación

```bash
# Login con admin seed user
curl -i https://ilenia.link3rs.com/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"admin@ilenia.link3rs.com",
    "password":"your_secure_password_here"
  }'

# Esperado: HTTP/2 200 con token JWT en response body
```

## 5.6 Logs y monitorización

### Ver logs de servicios

```bash
cd ~/ilenia-deployment

# Todos los servicios
docker compose logs -f

# Servicio específico
docker compose logs -f auth-service
docker compose logs -f live-service
docker compose logs -f nginx

# Últimas N líneas
docker compose logs --tail 100 auth-service
```

### Logs persistentes

- **Nginx**: Volumen `nginx-logs` → `/var/log/nginx/`
- **Live Service**: Volumen `live-logs` → `/app/logs/`
- **Redis**: Persistencia AOF en volumen `redis-data`

### Monitorizar estado

```bash
# Estado de contenedores
docker compose ps

# Uso de recursos
docker stats

# Healthchecks
docker inspect ilenia-auth-service --format '{{json .State.Health}}' | jq
docker inspect ilenia-live-service --format '{{json .State.Health}}' | jq
```

## 5.7 Actualización de servicios

### Actualizar todos los servicios

```bash
cd ~/ilenia-deployment

# Pull de nuevas imágenes
docker compose pull

# Recrear contenedores con nuevas imágenes
docker compose up -d

# Verificar
docker compose ps
```

### Actualizar servicio específico

```bash
# Solo frontend
docker compose pull react-frontend
docker compose up -d --force-recreate react-frontend

# Solo auth-service
docker compose pull auth-service
docker compose up -d --force-recreate auth-service

# Solo live-service
docker compose pull live-service
docker compose up -d --force-recreate live-service
```

### Actualizar Nginx (con nueva configuración)

```bash
# Pull nueva imagen de nginx
docker compose pull nginx

# Recrear contenedor
docker compose up -d --force-recreate nginx

# Verificar configuración
docker exec ilenia-nginx nginx -t

# Ver logs
docker compose logs -f nginx
```

### Rollback en caso de error

```bash
# Ver imágenes disponibles
docker images | grep ilenia

# Editar docker-compose.yml para usar tag específico
# Ejemplo: ghcr.io/link3rs/ilenia-auth-service:v1.2.3

# Recrear con imagen anterior
docker compose up -d --force-recreate auth-service
```

## 5.8 Backup y restauración

### Backup de volúmenes

```bash
cd ~/ilenia-deployment

# Backup de claves JWT (auth-keys)
docker run --rm -v ilenia-deployment_auth-keys:/data -v $(pwd):/backup alpine \
  tar czf /backup/auth-keys-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup de eventos (live-data)
docker cp ilenia-live-service:/app/data/events.json ./events-backup-$(date +%Y%m%d).json

# Backup de Redis
docker exec ilenia-redis redis-cli BGSAVE
docker cp ilenia-redis:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb
```

### Restauración

```bash
# Restaurar claves JWT
docker run --rm -v ilenia-deployment_auth-keys:/data -v $(pwd):/backup alpine \
  tar xzf /backup/auth-keys-backup-20260109.tar.gz -C /data

# Restaurar eventos
docker cp ./events-backup-20260109.json ilenia-live-service:/app/data/events.json
docker compose restart live-service

# Restaurar Redis
docker cp ./redis-backup-20260109.rdb ilenia-redis:/data/dump.rdb
docker compose restart redis
```

