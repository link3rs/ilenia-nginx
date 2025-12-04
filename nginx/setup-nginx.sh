#!/bin/bash

# 🌐 Nginx Setup Script for Ilenia on DigitalOcean
# This script installs and configures Nginx as a reverse proxy

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="ilenia.link3rs.com"
EMAIL="your-email@example.com"  # Change this!

echo -e "${BLUE}🌐 Nginx Setup for Ilenia${NC}"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install Nginx
echo -e "${YELLOW}📦 Installing Nginx...${NC}"
apt-get install -y nginx

# Install Certbot for Let's Encrypt
echo -e "${YELLOW}📦 Installing Certbot...${NC}"
apt-get install -y certbot python3-certbot-nginx

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p /var/www/ilenia-frontend
mkdir -p /var/www/certbot
mkdir -p /var/log/nginx

# Create a simple health check file
echo -e "${YELLOW}📝 Creating health check file...${NC}"
cat > /var/www/ilenia-frontend/health.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Ilenia Health Check</title></head>
<body>
<h1>✅ Ilenia is running</h1>
<p>Timestamp: $(date)</p>
</body>
</html>
EOF

# Backup default Nginx config
echo -e "${YELLOW}💾 Backing up default Nginx config...${NC}"
if [ -f /etc/nginx/sites-available/default ]; then
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
fi

# Copy Nginx configuration
echo -e "${YELLOW}📝 Installing Nginx configuration...${NC}"
if [ -f "ilenia.link3rs.com.conf" ]; then
    cp ilenia.link3rs.com.conf /etc/nginx/sites-available/ilenia.link3rs.com
else
    echo -e "${RED}❌ Configuration file not found: ilenia.link3rs.com.conf${NC}"
    echo "Please run this script from the nginx/ directory"
    exit 1
fi

# Create symlink to enable site
echo -e "${YELLOW}🔗 Enabling site...${NC}"
ln -sf /etc/nginx/sites-available/ilenia.link3rs.com /etc/nginx/sites-enabled/

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo -e "${YELLOW}🧪 Testing Nginx configuration...${NC}"
nginx -t

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    exit 1
fi

# Reload Nginx
echo -e "${YELLOW}🔄 Reloading Nginx...${NC}"
systemctl reload nginx
systemctl enable nginx

# Configure firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
ufw allow 'Nginx Full'
ufw allow OpenSSH
ufw --force enable

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Nginx installed and configured!"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: SSL Certificate Setup${NC}"
echo ""
echo "Before obtaining SSL certificate, make sure:"
echo "1. DNS A record for $DOMAIN points to this server's IP"
echo "2. Port 80 and 443 are open in your firewall"
echo "3. Update EMAIL variable in this script"
echo ""
echo "To obtain SSL certificate, run:"
echo ""
echo -e "${BLUE}certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email${NC}"
echo ""
echo "Or use the automated script:"
echo -e "${BLUE}./setup-ssl.sh${NC}"
echo ""
echo "📊 Nginx Status:"
systemctl status nginx --no-pager -l
echo ""
echo "📝 Test configuration:"
echo "  - HTTP:  http://$DOMAIN"
echo "  - HTTPS: https://$DOMAIN (after SSL setup)"
echo "  - Health: https://$DOMAIN/health"
echo ""
