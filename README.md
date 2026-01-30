# 🌐 Ilenia Nginx - Reverse Proxy for Ilenia Services

Docker image for Nginx reverse proxy that routes traffic to Ilenia microservices.

## 📋 Architecture

### Phase 1 (Current)

```
Internet
    ↓
ilenia.link3rs.com (Nginx on ports 80/443)
    ↓
    ├─ /                          → react-frontend:80 (Docker)
    ├─ /api/live/*                → live-service:8082 (Docker)
    ├─ /api/live/events           → live-service:8082 (Events CRUD - JSON persistence)
    ├─ /ws/live/v2/captions       → live-service:8082 (WebSocket)
    ├─ /ws/live/v2/speaker/:id    → live-service:8082 (WebSocket)
    └─ /ws/live/v2/manager/:id    → live-service:8082 (WebSocket)
    
    Redis (internal)
    └─ redis:6379                 → Session state & cache
```

### Phase 2 (Current - with Auth Service)

```
    ├─ /api/auth/*                → auth-service:8081 (Docker)
```

### Phase 3 (Future)

```

    ├─ /api/events/*              → event-service (PostgreSQL persistence)
```

All services run as Docker containers in the same network (`ilenia-net`).

## 🗄️ Redis - Session State & Cache

Redis is used in Phase 1 for:
- **Session state management** for live events
- **Captions cache** for real-time subtitle distribution
- **Temporary data storage** during live sessions

### Redis Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Image | `redis:7-alpine` | Lightweight Alpine-based Redis 7 |
| Container | `ilenia-redis` | Container name |
| Port | `6379` (internal) | Not exposed externally |
| Persistence | AOF (`appendonly yes`) | Append-only file for durability |
| Memory | `256mb` max | Memory limit |
| Eviction | `allkeys-lru` | Least Recently Used eviction |

### Redis Health Check

```bash
# Check Redis status
docker exec ilenia-redis redis-cli ping
# Should return: PONG

# Check Redis info
docker exec ilenia-redis redis-cli info | grep used_memory_human
```

### Redis Data Persistence

Redis data is stored in a Docker volume (`redis-data`) and persists across container restarts.

## 🎯 URL Mapping

### Frontend
- `https://ilenia.link3rs.com/` → React app
- `https://ilenia.link3rs.com/health` → Nginx health check

### REST APIs
- `https://ilenia.link3rs.com/api/live/health` → Live service health
- `https://ilenia.link3rs.com/api/event/v1/events` → Events CRUD (GET, POST)
- `https://ilenia.link3rs.com/api/event/v1/events/{id}` → Event by ID (GET, PUT, DELETE)
- `https://ilenia.link3rs.com/api/event/v1/events/{id}/channels` → Channel operations
- `https://ilenia.link3rs.com/api/auth/v2/login` → User authentication
- `https://ilenia.link3rs.com/api/auth/v2/register` → User registration
- `https://ilenia.link3rs.com/api/auth/v2 /health` → Auth service health


### WebSockets
- `wss://ilenia.link3rs.com/ws/live/v2/captions` → Captions WebSocket
- `wss://ilenia.link3rs.com/ws/live/v2/speaker/{session_id}` → Speaker WebSocket
- `wss://ilenia.link3rs.com/ws/live/v2/manager/{session_id}` → Manager WebSocket

## 🚀 Quick Deployment

### Prerequisites

1. **DigitalOcean Droplet** with Ubuntu 22.04+ and Docker installed
2. **Domain** pointing to your droplet IP (`ilenia.link3rs.com`)
3. **SSL certificates** from Let's Encrypt
4. **GHCR access** (GitHub Container Registry)

### 1️⃣ Create Deployment User (Security Best Practice)

```bash
# Connect as root
ssh root@YOUR_DROPLET_IP

# Create user 'ilenia'
adduser ilenia

# Add to sudo and docker groups
usermod -aG sudo,docker ilenia

# Copy SSH keys for passwordless login
mkdir -p /home/ilenia/.ssh
cp ~/.ssh/authorized_keys /home/ilenia/.ssh/
chown -R ilenia:ilenia /home/ilenia/.ssh
chmod 700 /home/ilenia/.ssh
chmod 600 /home/ilenia/.ssh/authorized_keys

# Verify docker works without sudo
su - ilenia
docker --version
exit

# Set permissions for SSL certificates
chmod 755 /etc/letsencrypt/live
chmod 755 /etc/letsencrypt/archive
```

**Configure SSH on your local machine** (`~/.ssh/config`):

```
Host ilenia-droplet
    HostName YOUR_DROPLET_IP
    User ilenia
    IdentityFile ~/.ssh/id_ed25519
```

Now you can connect with: `ssh ilenia-droplet`

### 2️⃣ DNS Configuration

Add an A record in your DNS provider:

```
Type: A
Name: ilenia (or @)
Value: YOUR_DROPLET_IP
TTL: 3600
```

Verify DNS propagation:
```bash
dig ilenia.link3rs.com +short
# Should return your droplet IP
```

### 3️⃣ Setup SSL Certificates (First Time)

```bash
# As root (before Docker deployment)
sudo certbot certonly --standalone -d ilenia.link3rs.com --email your@email.com --agree-tos

# Set permissions for Docker to read certificates
sudo chmod 755 /etc/letsencrypt/live
sudo chmod 755 /etc/letsencrypt/archive
```

### 4️⃣ Deploy with Docker Compose

```bash
# Connect as deployment user
ssh ilenia-droplet

# Create deployment directory
mkdir -p ~/ilenia-deployment
cd ~/ilenia-deployment

# Login to GitHub Container Registry
docker login ghcr.io -u YOUR_GITHUB_USERNAME -p YOUR_GITHUB_TOKEN

# Download docker-compose.yml (Phase 2 - with auth service)
wget https://raw.githubusercontent.com/link3rs/ilenia-nginx/main/docker-compose.yml -O docker-compose.yml


# Create .env file with your configuration
cat > .env <<EOF
# HuggingFace Endpoints (configured via frontend Settings modal)
# These are optional - the manager can configure them in the browser
HF_ASR_URL=https://your-asr-endpoint.us-east-1.aws.endpoints.huggingface.cloud
HF_ASR_TOKEN=hf_your_token_here
HF_MT_URL=https://your-mt-endpoint.us-east-1.aws.endpoints.huggingface.cloud/v1
HF_MT_TOKEN=hf_your_token_here

# Logging
LOG_LEVEL=INFO

# ASR Tuning (optional)
ASR_RMS_SPEECH_THRESHOLD=0.003
ASR_MIN_SPEECH_DURATION_MS=300
ASR_MIN_SILENCE_DURATION_MS=500
ASR_SPEECH_PAD_MS=400

# Auth Service Configuration
AUTH_ISSUER=https://auth.ilenia.link3rs.com
ACCESS_TTL_SECONDS=3600
AUTH_SEED_ADMIN_EMAIL=admin@ilenia.com
AUTH_SEED_ADMIN_PASSWORD=your_secure_password_here
AUTH_SEED_ADMIN_NAME=Admin
AUTH_SEED_ADMIN_LANG=en
EOF

# Pull images and start all services (includes Redis and Auth)
docker compose pull
docker compose up -d

# Verify all containers are running
# Expected: redis, nginx, react-frontend, live-service, auth-service, auth-keys-init (completed)

docker compose ps
```

### 5️⃣ Verify Deployment

```bash
# Test nginx health
curl https://ilenia.link3rs.com/health

# Test backend API
curl https://ilenia.link3rs.com/api/live/health

# Test auth service
curl https://ilenia.link3rs.com/api/auth/health

# Test Events API
curl https://ilenia.link3rs.com/api/live/events

# Test Redis connectivity
docker exec ilenia-redis redis-cli ping
# Should return: PONG

# Test frontend
curl -I https://ilenia.link3rs.com/
```

## 🔧 Configuration Details

### Nginx Configuration Files

The Docker container uses **two nginx configuration files** from the `nginx/` directory:

| File | Destination in Container | Purpose |
|------|--------------------------|---------|
| `nginx/nginx.conf` | `/etc/nginx/nginx.conf` | **Global configuration** - workers, logs, gzip, timeouts |
| `nginx/ilenia.link3rs.com.conf` | `/etc/nginx/conf.d/default.conf` | **Virtual host** - SSL, upstreams, routing to services |

Both files are copied in the Dockerfile:
```dockerfile
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/ilenia.link3rs.com.conf /etc/nginx/conf.d/default.conf
```

The global `nginx.conf` includes all files in `conf.d/` via the standard nginx include directive, loading `ilenia.link3rs.com.conf` as the default server block.

### Virtual Host Configuration

`ilenia.link3rs.com.conf` includes:

- ✅ **HTTP to HTTPS redirect**
- ✅ **SSL/TLS configuration** (Mozilla Intermediate)
- ✅ **WebSocket support** with proper upgrade headers
- ✅ **CORS headers** for API and WebSocket endpoints
- ✅ **Rate limiting** (10 req/s for API, 5 req/s for WebSocket)
- ✅ **Gzip compression**
- ✅ **Security headers** (HSTS, X-Frame-Options, etc.)
- ✅ **Static file caching** (1 year for assets)
- ✅ **SPA routing** (all routes serve index.html)
- ✅ **Health check endpoint**

### Backend Services

Make sure these services are running:

```bash
# Check all containers
docker compose ps

# Expected containers in Phase 2:
# - ilenia-redis            (Redis for session state)
# - ilenia-nginx            (Reverse proxy)
# - ilenia-frontend         (React app)
# - ilenia-live-service     (STT, MT, Events CRUD)
# - ilenia-auth-service     (Authentication & JWT)
# - ilenia-auth-keys-init   (Init container - exits after setup)

# Check Redis
docker exec ilenia-redis redis-cli ping

# Check Live Service
docker logs ilenia-live-service --tail 10
```

### Service Dependencies

```
auth-keys-init
    └─ (runs once to fix volume ownership)

auth-service
    └─ depends_on: auth-keys-init (completed)


live-service
    └─ depends_on: redis (healthy)

nginx

    └─ depends_on: react-frontend, live-service, auth-service

```

### Frontend Environment Variables

Update your React `.env` file:

```bash
# .env.production
VITE_BACKEND_URL=https://ilenia.link3rs.com/api/live
VITE_WS_URL=wss://ilenia.link3rs.com/ws/live
VITE_AUTH_URL=https://ilenia.link3rs.com/api/auth
VITE_EVENT_URL=https://ilenia.link3rs.com/api/event
```

## 🧪 Testing

### Test HTTP to HTTPS Redirect

```bash
curl -I http://ilenia.link3rs.com
# Should return 301 redirect to https://
```

### Test Frontend

```bash
curl -I https://ilenia.link3rs.com
# Should return 200 OK

curl https://ilenia.link3rs.com/health
# Should return health check HTML
```

### Test Backend API

```bash
curl https://ilenia.link3rs.com/api/live/health
# Should return backend health status
```

### Test WebSocket

```bash
# Using wscat (install: npm install -g wscat)
wscat -c wss://ilenia.link3rs.com/ws/live/v2/captions
```

### Test SSL Certificate

```bash
# Check certificate
openssl s_client -connect ilenia.link3rs.com:443 -servername ilenia.link3rs.com

# Online SSL test
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=ilenia.link3rs.com
```

## 📊 Monitoring

### View Nginx Logs

```bash
# Access logs
tail -f /var/log/nginx/ilenia.access.log

# Error logs
tail -f /var/log/nginx/ilenia.error.log

# Filter WebSocket connections
grep "Upgrade" /var/log/nginx/ilenia.access.log
```

### Check Nginx Status

```bash
# Status
systemctl status nginx

# Test configuration
nginx -t

# Reload configuration
systemctl reload nginx

# Restart Nginx
systemctl restart nginx
```

### Monitor Connections

```bash
# Active connections
netstat -an | grep :443 | wc -l

# WebSocket connections
netstat -an | grep ESTABLISHED | grep :8082
```

## 🔄 Updating

### Update All Services

```bash
# Connect as deployment user
ssh ilenia-droplet
cd ~/ilenia-deployment

# Pull latest images from GHCR
docker-compose pull

# Restart with new images (zero downtime)
docker-compose up -d

# Verify
docker-compose ps
```

### Update Single Service

```bash
# Update only frontend
docker-compose pull react-frontend
docker-compose up -d react-frontend

# Update only backend
docker-compose pull live-service
docker-compose up -d live-service

# Update only nginx
docker-compose pull nginx
docker-compose up -d nginx
```

### View Update Logs

```bash
# Watch logs during update
docker-compose logs -f

# Check specific service
docker-compose logs -f live-service
```

## 🛠️ Troubleshooting

### 502 Bad Gateway

**Cause**: Backend service not running or not accessible

**Solution**:
```bash
cd ~/ilenia-deployment

# Check all containers
docker-compose ps

# Check backend logs
docker-compose logs live-service

# Restart backend
docker-compose restart live-service
```

### 504 Gateway Timeout

**Cause**: Backend taking too long to respond

**Solution**:
```bash
# Increase timeouts in Nginx config
proxy_connect_timeout 120s;
proxy_send_timeout 120s;
proxy_read_timeout 120s;

# Reload Nginx
systemctl reload nginx
```

### WebSocket Connection Fails

**Cause**: Missing upgrade headers or timeout too short

**Solution**:
```bash
# Check Nginx configuration has:
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 7d;

# Check backend WebSocket endpoint
curl -I http://localhost:8082/v2/captions
```

### SSL Certificate Renewal Fails

**Cause**: Port 80 blocked or Nginx not configured correctly

**Solution**:
```bash
# Check certbot timer
systemctl status certbot.timer

# Manual renewal
certbot renew --dry-run

# Check logs
journalctl -u certbot
```

### CORS Errors

**Cause**: Missing or incorrect CORS headers

**Solution**:
```bash
# Check Nginx configuration has CORS headers
# Test with curl
curl -H "Origin: https://example.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     https://ilenia.link3rs.com/api/live/health -v
```

### Redis Connection Failed

**Cause**: Redis container not running or unhealthy

**Solution**:
```bash
cd ~/ilenia-deployment

# Check Redis status
docker compose ps redis

# Check Redis logs
docker compose logs redis

# Restart Redis
docker compose restart redis

# Verify Redis is healthy before live-service starts
docker exec ilenia-redis redis-cli ping
```

### Events API Returns 405 Method Not Allowed

**Cause**: Old version of live-service without Events CRUD endpoints

**Solution**:
```bash
cd ~/ilenia-deployment

# Pull latest image
docker compose pull live-service

# Recreate container with new image
docker compose up -d --force-recreate live-service

# Verify Events API works
curl https://ilenia.link3rs.com/api/live/events
```

### Auth Service Returns 500 on Login

**Cause**: Permission denied writing JWT keys to `/app/keys/private.pem`

**Root Issue**: The `auth-service` container runs as non-root user (`appuser`, uid `10001`) for security, but Docker volumes are created with root ownership by default. When the service tries to generate RSA keys for JWT signing on first login, it fails with `PermissionError`.

**Solution (Automatic)**: The `docker-compose.yml` includes an **init container** (`auth-keys-init`) that automatically fixes volume ownership before `auth-service` starts:

```yaml
auth-keys-init:
  image: alpine:3.20
  container_name: ilenia-auth-keys-init
  restart: "no"
  user: "0:0"
  volumes:
    - auth-keys:/app/keys
  command: ["sh", "-lc", "mkdir -p /app/keys && chown -R 10001:10001 /app/keys"]

auth-service:
  depends_on:
    auth-keys-init:
      condition: service_completed_successfully
```

**How it works**:
1. `auth-keys-init` runs **once** as root
2. Creates `/app/keys` directory and sets ownership to `10001:10001` (appuser)
3. Exits successfully
4. `auth-service` starts only after init completes
5. `auth-service` can now write JWT keys without permission errors

**Verification**:
```bash
# Check init container completed successfully
docker compose ps auth-keys-init
# Should show: Exit 0

# Check auth-service is healthy
docker compose ps auth-service
# Should show: Up (healthy)

# Test login endpoint (should return 401 for invalid credentials, not 500)
curl -i https://ilenia.link3rs.com/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test"}'
# Expected: HTTP/2 401 (Unauthorized) - NOT 500

# Check auth-service logs for permission errors
docker logs ilenia-auth-service --tail 50
# Should NOT see: PermissionError: [Errno 13] Permission denied: '/app/keys/private.pem'
```

**Manual Fix (if needed)**:
If you deployed without the init container, fix manually:
```bash
cd ~/ilenia-deployment

# Fix volume ownership manually
docker run --rm -v ilenia-deployment_auth-keys:/app/keys alpine \
  sh -c "mkdir -p /app/keys && chown -R 10001:10001 /app/keys"

# Restart auth-service
docker compose restart auth-service

# Verify
docker logs ilenia-auth-service --tail 20
```

**Security Note**: This approach allows `auth-service` to run as non-root (secure) while still being able to generate and persist JWT signing keys. The keys are stored in the `auth-keys` volume and persist across container restarts.


## 🔐 Security

### Firewall Configuration

```bash
# Allow only necessary ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# Check status
ufw status
```

### Rate Limiting

Configured in Nginx:
- API endpoints: 10 requests/second
- WebSocket endpoints: 5 requests/second

Adjust in `ilenia.link3rs.com.conf`:
```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=5r/s;
```

### Security Headers

All responses include:
- `Strict-Transport-Security` (HSTS)
- `X-Frame-Options`
- `X-Content-Type-Options`
- `X-XSS-Protection`
- `Referrer-Policy`

## 📚 Additional Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [WebSocket Proxy Guide](https://nginx.org/en/docs/http/websocket.html)
- [SSL Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

## 💡 Tips

1. **Use HTTP/2**: Already enabled in configuration for better performance
2. **Enable Gzip**: Already enabled for text-based content
3. **Cache static assets**: Already configured with 1-year cache
4. **Monitor logs**: Set up log rotation to prevent disk space issues
5. **Backup configuration**: Keep backups of working Nginx configs
6. **Test before deploy**: Always test configuration with `nginx -t`
7. **Use staging**: Test changes on a staging environment first


## 📦 Docker Volumes 


| Volume | Container | Purpose |
|--------|-----------|---------|
| `redis-data` | ilenia-redis | Redis AOF persistence |
| `live-data` | ilenia-live-service | Events JSON file (`events.json`) |
| `live-recordings` | ilenia-live-service | Audio recordings |
| `live-logs` | ilenia-live-service | Application logs |
| `nginx-logs` | ilenia-nginx | Access and error logs |
| `certbot-webroot` | ilenia-nginx | Let's Encrypt challenges |
| `auth-keys` | ilenia-auth-service | JWT signing keys (RSA private/public) |


### Backup Data

```bash
# Backup events data
docker cp ilenia-live-service:/app/data/events.json ./backup-events.json

# Backup Redis data
docker exec ilenia-redis redis-cli BGSAVE
docker cp ilenia-redis:/data/dump.rdb ./backup-redis.rdb
```

## 🎉 You're Ready!

Your Ilenia application is now accessible at:
- **Frontend**: https://ilenia.link3rs.com
- **API**: https://ilenia.link3rs.com/api/live/health
- **WebSocket**: wss://ilenia.link3rs.com/ws/live/v2/captions

Enjoy your production deployment! 🚀
