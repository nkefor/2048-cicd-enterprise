FROM nginx:1.27-alpine

# Copy static game files
COPY www /usr/share/nginx/html

# Security hardening - custom NGINX config
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
  '' \
  '  location / {' \
  '    root /usr/share/nginx/html;' \
  '    try_files $uri /index.html;' \
  '  }' \
  '}' > /etc/nginx/conf.d/2048.conf

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1
