# 🌐 Ilenia Nginx - Reverse Proxy for Ilenia Services

Docker image for Nginx reverse proxy that routes traffic to Ilenia microservices.

## 📋 Architecture

```
Internet
    ↓
ilenia.link3rs.com (Nginx on ports 80/443)
    ↓
    ├─ /                          → react-frontend:80 (Docker)
    ├─ /api/live/*                → live-service:8082 (Docker)
    ├─ /api/auth/*                → auth-service:8081 (Docker)
    ├─ /ws/live/v2/captions       → live-service:8082 (WebSocket)
    ├─ /ws/live/v2/speaker/:id    → live-service:8082 (WebSocket)
    └─ /ws/live/v2/manager/:id    → live-service:8082 (WebSocket)
```

All services run as Docker containers in the same network.

## 🎯 URL Mapping

### Frontend
- `https://ilenia.link3rs.com/` → React app
- `https://ilenia.link3rs.com/health` → Nginx health check

### REST APIs
- `https://ilenia.link3rs.com/api/live/health` → Live service health
- `https://ilenia.link3rs.com/api/live/sessions` → Live service sessions
- `https://ilenia.link3rs.com/api/auth/login` → Auth service login

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

# Download docker-compose.yml
wget https://raw.githubusercontent.com/link3rs/ilenia-nginx/develop/docker-compose.yml

# Create .env file with your configuration
cat > .env <<EOF
HF_ASR_URL=https://your-asr-endpoint.hf.space
HF_ASR_TOKEN=hf_your_token_here
HF_MT_URL=https://your-mt-endpoint.hf.space
HF_MT_TOKEN=hf_your_token_here
LOG_LEVEL=INFO
EOF

# Pull images and start all services
docker-compose pull
docker-compose up -d

# Verify all containers are running
docker-compose ps
```

### 5️⃣ Verify Deployment

```bash
# Test nginx health
curl https://ilenia.link3rs.com/health

# Test backend API
curl https://ilenia.link3rs.com/api/live/health

# Test frontend
curl -I https://ilenia.link3rs.com/
```

## 🔧 Configuration Details

### Nginx Configuration File

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
# Live Event Service (port 8082)
docker ps | grep ilenia-backend

# Auth Service (port 8081) - if implemented
# LiveKit Service (port 8086) - if implemented
```

### Frontend Environment Variables

Update your React `.env` file:

```bash
# .env.production
VITE_BACKEND_URL=https://ilenia.link3rs.com/api/live
VITE_WS_URL=wss://ilenia.link3rs.com/ws/live
VITE_AUTH_URL=https://ilenia.link3rs.com/api/auth
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

## 🎉 You're Ready!

Your Ilenia application is now accessible at:
- **Frontend**: https://ilenia.link3rs.com
- **API**: https://ilenia.link3rs.com/api/live/health
- **WebSocket**: wss://ilenia.link3rs.com/ws/live/v2/captions

Enjoy your production deployment! 🚀
