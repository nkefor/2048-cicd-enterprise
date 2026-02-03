FROM nginx:1.27-alpine AS base

# Metadata labels for container registry and traceability
LABEL maintainer="devops-team" \
      app="2048-game" \
      description="Enterprise CI/CD Demo - 2048 Game" \
      org.opencontainers.image.source="https://github.com/nkefor/2048-cicd-enterprise"

# Install curl for health checks (wget already available in alpine)
# Remove default config and set up security-hardened NGINX
RUN rm -f /etc/nginx/conf.d/default.conf \
  && printf '%s\n' \
  'server {' \
  '  listen 80;' \
  '  server_name _;' \
  '' \
  '  # Security headers' \
  '  add_header X-Content-Type-Options "nosniff" always;' \
  '  add_header X-Frame-Options "DENY" always;' \
  '  add_header X-XSS-Protection "1; mode=block" always;' \
  '  add_header Referrer-Policy "no-referrer-when-downgrade" always;' \
  '  add_header Content-Security-Policy "default-src '"'"'self'"'"'; script-src '"'"'self'"'"' '"'"'unsafe-inline'"'"'; style-src '"'"'self'"'"' '"'"'unsafe-inline'"'"';" always;' \
  '  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;' \
  '  add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;' \
  '' \
  '  # Disable server version disclosure' \
  '  server_tokens off;' \
  '' \
  '  # Gzip compression' \
  '  gzip on;' \
  '  gzip_types text/plain text/css application/json application/javascript text/xml;' \
  '  gzip_min_length 256;' \
  '' \
  '  # Health check endpoint' \
  '  location /health {' \
  '    access_log off;' \
  '    return 200 '"'"'{"status":"healthy","service":"2048-game"}'"'"';' \
  '    add_header Content-Type application/json;' \
  '  }' \
  '' \
  '  # Deployment info endpoint (blue/green identification)' \
  '  location /info {' \
  '    access_log off;' \
  '    default_type application/json;' \
  '    return 200 '"'"'{"app":"2048-game","version":"$DEPLOY_VERSION","environment":"$DEPLOY_ENV"}'"'"';' \
  '  }' \
  '' \
  '  location / {' \
  '    root /usr/share/nginx/html;' \
  '    try_files $uri /index.html;' \
  '' \
  '    # Cache static assets' \
  '    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {' \
  '      expires 7d;' \
  '      add_header Cache-Control "public, immutable";' \
  '    }' \
  '  }' \
  '' \
  '  # Block access to hidden files' \
  '  location ~ /\. {' \
  '    deny all;' \
  '    return 404;' \
  '  }' \
  '}' > /etc/nginx/conf.d/2048.conf

# Copy static game files
COPY www /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

# Health check against dedicated health endpoint
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health || exit 1
