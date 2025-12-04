# 🌐 Nginx Reverse Proxy Setup for Ilenia

This directory contains Nginx configuration and setup scripts for deploying Ilenia on a DigitalOcean Droplet with path-based routing.

## 📋 Architecture

```
Internet
    ↓
ilenia.link3rs.com (Nginx on ports 80/443)
    ↓
    ├─ /                          → React Frontend (static files)
    ├─ /api/live/*                → Backend Live Service (localhost:8082)
    ├─ /api/auth/*                → Backend Auth Service (localhost:8081)
    ├─ /api/livekit/*             → Backend LiveKit Service (localhost:8086)
    ├─ /ws/live/v2/captions       → WebSocket (localhost:8082)
    ├─ /ws/live/v2/speaker/:id    → WebSocket (localhost:8082)
    └─ /ws/live/v2/manager/:id    → WebSocket (localhost:8082)
```

## 🎯 URL Mapping

### Frontend
- `https://ilenia.link3rs.com/` → React app (static files)
- `https://ilenia.link3rs.com/health` → Health check

### REST APIs
- `https://ilenia.link3rs.com/api/live/health` → Live service health
- `https://ilenia.link3rs.com/api/live/sessions` → Live service sessions
- `https://ilenia.link3rs.com/api/auth/login` → Auth service login
- `https://ilenia.link3rs.com/api/livekit/rooms` → LiveKit service rooms

### WebSockets
- `wss://ilenia.link3rs.com/ws/live/v2/captions` → Captions WebSocket
- `wss://ilenia.link3rs.com/ws/live/v2/speaker/{session_id}` → Speaker WebSocket
- `wss://ilenia.link3rs.com/ws/live/v2/manager/{session_id}` → Manager WebSocket

## 🚀 Quick Setup

### Prerequisites

1. **DigitalOcean Droplet** with Ubuntu 22.04+
2. **Domain** pointing to your droplet IP
3. **Root access** to the droplet

### DNS Configuration

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

### Installation Steps

#### 1️⃣ Upload Configuration Files

```bash
# From your local machine
scp -r nginx/ root@YOUR_DROPLET_IP:~/
```

#### 2️⃣ Install Nginx

```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# Navigate to nginx directory
cd ~/nginx

# Make scripts executable
chmod +x setup-nginx.sh setup-ssl.sh

# Run Nginx setup
sudo ./setup-nginx.sh
```

#### 3️⃣ Deploy Frontend

```bash
# Build React frontend locally
cd ilenia-react-frontend
npm run build

# Upload to droplet
scp -r dist/* root@YOUR_DROPLET_IP:/var/www/ilenia-frontend/
```

#### 4️⃣ Setup SSL Certificate

```bash
# On your droplet
cd ~/nginx

# Edit setup-ssl.sh and update EMAIL variable
nano setup-ssl.sh

# Run SSL setup
sudo ./setup-ssl.sh
```

#### 5️⃣ Start Backend Services

```bash
# Using Docker Compose
cd ~/ilenia-deployment
docker-compose -f docker-compose.production.yml up -d
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

### Update Nginx Configuration

```bash
# Edit configuration
nano /etc/nginx/sites-available/ilenia.link3rs.com

# Test configuration
nginx -t

# Reload Nginx
systemctl reload nginx
```

### Update Frontend

```bash
# Build new version locally
cd ilenia-react-frontend
npm run build

# Upload to droplet
scp -r dist/* root@YOUR_DROPLET_IP:/var/www/ilenia-frontend/

# Clear browser cache or use versioned assets
```

### Update Backend

```bash
# Pull new images
docker-compose -f docker-compose.production.yml pull

# Restart services
docker-compose -f docker-compose.production.yml up -d
```

## 🛠️ Troubleshooting

### 502 Bad Gateway

**Cause**: Backend service not running or not accessible

**Solution**:
```bash
# Check if backend is running
docker ps | grep ilenia-backend

# Check backend logs
docker logs ilenia-backend

# Restart backend
docker-compose -f docker-compose.production.yml restart backend
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
