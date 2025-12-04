#!/bin/bash

# 🔒 SSL Setup Script for Ilenia using Let's Encrypt
# This script obtains and configures SSL certificates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="ilenia.link3rs.com"
EMAIL="your-email@example.com"  # ⚠️ CHANGE THIS!

echo -e "${BLUE}🔒 SSL Setup for Ilenia${NC}"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if email is set
if [ "$EMAIL" = "your-email@example.com" ]; then
    echo -e "${RED}❌ Please update the EMAIL variable in this script${NC}"
    exit 1
fi

# Check if domain resolves to this server
echo -e "${YELLOW}🔍 Checking DNS resolution...${NC}"
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

echo "Server IP:  $SERVER_IP"
echo "Domain IP:  $DOMAIN_IP"

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    echo -e "${YELLOW}⚠️  Warning: Domain does not resolve to this server${NC}"
    echo "Make sure DNS A record for $DOMAIN points to $SERVER_IP"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Nginx is running
echo -e "${YELLOW}🔍 Checking Nginx status...${NC}"
if ! systemctl is-active --quiet nginx; then
    echo -e "${RED}❌ Nginx is not running${NC}"
    echo "Start Nginx: systemctl start nginx"
    exit 1
fi

# Test Nginx configuration
echo -e "${YELLOW}🧪 Testing Nginx configuration...${NC}"
nginx -t

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    exit 1
fi

# Obtain SSL certificate
echo -e "${YELLOW}🔐 Obtaining SSL certificate from Let's Encrypt...${NC}"
echo "Domain: $DOMAIN"
echo "Email:  $EMAIL"
echo ""

certbot --nginx \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --redirect \
    --hsts \
    --staple-ocsp

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ SSL certificate installation failed${NC}"
    exit 1
fi

# Test SSL configuration
echo -e "${YELLOW}🧪 Testing SSL configuration...${NC}"
nginx -t

# Reload Nginx
echo -e "${YELLOW}🔄 Reloading Nginx...${NC}"
systemctl reload nginx

# Setup auto-renewal
echo -e "${YELLOW}⏰ Setting up automatic certificate renewal...${NC}"
systemctl enable certbot.timer
systemctl start certbot.timer

# Test renewal
echo -e "${YELLOW}🧪 Testing certificate renewal...${NC}"
certbot renew --dry-run

echo ""
echo -e "${GREEN}=========================================="
echo "✅ SSL certificate installed successfully!"
echo "==========================================${NC}"
echo ""
echo "📊 Certificate Information:"
certbot certificates
echo ""
echo "🔄 Auto-renewal status:"
systemctl status certbot.timer --no-pager -l
echo ""
echo "🌐 Your site is now available at:"
echo -e "${BLUE}https://$DOMAIN${NC}"
echo ""
echo "🔐 SSL Test:"
echo -e "${BLUE}https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN${NC}"
echo ""
echo "📝 Useful commands:"
echo "  - Check certificates:  certbot certificates"
echo "  - Renew certificates:  certbot renew"
echo "  - Test renewal:        certbot renew --dry-run"
echo ""
