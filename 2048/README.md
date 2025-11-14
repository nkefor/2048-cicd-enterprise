# 🔐 Secure 2048 Web Application

> **Production-grade web application with TLS certificates, authentication, and rate limiting**

This is not your typical localhost demo. This application is designed to be **exposed to the real internet** with proper security controls, so you can experience what it's like to protect a service from actual threats.

## 🚀 Quick Start

### Option 1: One-Command Start (Recommended)

```bash
./start.sh
```

This interactive script will guide you through:
- Local development setup (HTTP)
- Production deployment with HTTPS
- Docker deployment

### Option 2: Manual Start

```bash
# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env and configure your settings
nano .env

# Start the application
npm start
```

### Option 3: Docker

```bash
docker-compose up --build
```

## 🔑 Default Credentials

```
Username: admin
Password: ChangeMe123!
```

**⚠️ Change the password in `.env` before deploying to production!**

## 🛡️ Security Features

- ✅ **TLS/HTTPS** - Automatic certificates via Let's Encrypt
- ✅ **Authentication** - Session-based auth with bcrypt
- ✅ **Rate Limiting** - 5 login attempts per 15 minutes
- ✅ **Security Headers** - Helmet.js (CSP, HSTS, etc.)
- ✅ **Security Logging** - Winston logger for all auth events
- ✅ **Input Validation** - Express-validator for all inputs

## 📖 Full Documentation

See [SECURITY-SETUP.md](../SECURITY-SETUP.md) for complete documentation including:
- Production deployment guide
- Let's Encrypt configuration
- Security testing procedures
- Monitoring and logging
- Incident response
- Troubleshooting

## 🎯 What Makes This Different?

Most security tutorials use localhost. **This one doesn't.**

When you deploy this application to the internet with a real domain:
1. You'll see actual bot traffic in your logs
2. You'll watch rate limiting block brute force attempts
3. You'll get a valid TLS certificate trusted by all browsers
4. You'll experience what real-world security looks like

**Localhost is safe. The internet is not. This teaches you the difference.**

## 🔧 Configuration

All configuration is done via environment variables in `.env`:

```bash
# Required
NODE_ENV=production
ADMIN_PASSWORD=YourSecurePassword123!
SESSION_SECRET=generate-random-secret-here

# For HTTPS (production)
ENABLE_HTTPS=true
DOMAIN=your-domain.com
EMAIL=your-email@example.com
```

## 📊 Endpoints

- `GET /` - Login page (public)
- `POST /api/login` - Login endpoint (rate limited)
- `POST /api/logout` - Logout endpoint
- `GET /api/auth/status` - Check auth status
- `GET /game` - Protected game page (requires auth)
- `GET /health` - Health check (public)

## 🧪 Testing

### Test Authentication
```bash
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"ChangeMe123!"}'
```

### Test Rate Limiting
```bash
# Run this 6 times - 6th should be blocked
for i in {1..6}; do
  curl -X POST http://localhost:3000/api/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrong"}'
  echo "Attempt $i"
done
```

### Check Security Logs
```bash
tail -f logs/security.log
```

## 🐳 Docker Build

```bash
# Build
docker build -t secure-2048:latest .

# Run
docker run -d \
  --name secure-2048 \
  -p 3000:80 \
  -e ADMIN_PASSWORD=SecurePass123! \
  -e SESSION_SECRET=$(openssl rand -base64 48) \
  -v $(pwd)/logs:/app/logs \
  secure-2048:latest

# View logs
docker logs -f secure-2048
```

## 📁 Project Structure

```
2048/
├── server.js              # Main application server
├── server-https.js        # HTTPS server with Let's Encrypt
├── package.json           # Dependencies
├── Dockerfile             # Production container
├── docker-compose.yml     # Local Docker setup
├── start.sh              # Interactive startup script
├── .env.example          # Environment template
├── .env                  # Your configuration (create from .env.example)
├── public/
│   └── login.html        # Login page
└── www/
    └── index.html        # Protected game page
```

## 🔍 Monitoring

### Real-Time Security Events

The login page includes a live security event log showing:
- Authentication attempts
- Rate limit violations
- Suspicious activity detection
- Human behavior tracking

### Application Logs

```bash
# All logs
tail -f logs/combined.log

# Security only
tail -f logs/security.log

# Errors only
tail -f logs/error.log
```

## 🚨 Security Best Practices

1. **Always use HTTPS in production** - Set `ENABLE_HTTPS=true`
2. **Change default password** - Set `ADMIN_PASSWORD` in `.env`
3. **Generate strong session secret** - Use `openssl rand -base64 48`
4. **Monitor logs regularly** - Watch for unusual patterns
5. **Keep dependencies updated** - Run `npm audit` regularly
6. **Use strong passwords** - Min 8 chars with upper, lower, numbers
7. **Enable firewall** - Only allow ports 80, 443, and SSH

## 🛠️ Troubleshooting

### Can't get HTTPS certificate

1. Verify domain points to your server: `dig +short yourdomain.com`
2. Ensure ports 80 and 443 are open: `sudo netstat -tlnp`
3. Check firewall: `sudo ufw status`
4. Try Let's Encrypt staging first to avoid rate limits

### Sessions not working

1. Check `SESSION_SECRET` is set in `.env`
2. Verify cookies are enabled in browser
3. Check server logs for errors

### Rate limiting too strict

Edit `.env`:
```bash
RATE_LIMIT_MAX_REQUESTS=200
AUTH_RATE_LIMIT_MAX=10
```

## 📚 Learn More

- [SECURITY-SETUP.md](../SECURITY-SETUP.md) - Full security documentation
- [Let's Encrypt Docs](https://letsencrypt.org/docs/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Express Security](https://expressjs.com/en/advanced/best-practice-security.html)

## 🤝 Contributing

This is part of the Enterprise CI/CD Platform. See main [README.md](../README.md) for contribution guidelines.

## 📄 License

MIT License - See [LICENSE](../LICENSE)

---

**Ready to experience real security?**

```bash
./start.sh
```

**When you're ready for production, deploy to the internet and watch the bots try to break in. That's when security becomes real.**
