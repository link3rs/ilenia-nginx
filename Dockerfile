# Nginx reverse proxy for Ilenia services
# Handles SSL termination and routing to backend services

FROM nginx:alpine

# Install certbot for SSL certificate management
RUN apk add --no-cache certbot certbot-nginx curl

# Create directories for certificates and certbot
RUN mkdir -p /var/www/certbot \
    && mkdir -p /etc/letsencrypt \
    && mkdir -p /var/log/nginx

# Copy nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/ilenia.link3rs.com.conf /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Expose ports
EXPOSE 80 443

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
