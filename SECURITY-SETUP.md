# 🔐 Secure Web Application with TLS, Authentication & Rate Limiting

> **"Localhost is safe. The internet is not."**
> This project demonstrates production-grade security by exposing a real application to the internet with proper authentication, TLS encryption, and rate limiting.

## 🎯 What You'll Learn

This isn't just another localhost demo. This is a **real-world security implementation** where you'll:

- ✅ **Expose a web app to the internet** - Not localhost, but the actual internet where bots and attackers roam
- ✅ **Implement TLS with Let's Encrypt** - Free, automated SSL certificates
- ✅ **Add authentication** - Protect your app from unauthorized access
- ✅ **Configure rate limiting** - Watch brute force attacks fail in real-time
- ✅ **Monitor security events** - See every failed login, rate limit violation, and suspicious request

**You need to feel what it's like when strangers can reach your services. That's when security becomes real.**

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet Traffic                        │
│                  (Bots, Users, Attackers)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Let's Encrypt TLS                          │
│         (Automatic HTTPS with valid certificates)            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Rate Limiter                              │
│     Login: 5 attempts/15min  │  API: 100 req/15min          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Authentication Layer                       │
│          (Session-based with secure cookies)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Security Logging                          │
│        (Winston: All auth attempts & violations)             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Protected Application                      │
│                    (2048 Game Demo)                          │
└─────────────────────────────────────────────────────────────┘
```

## 🔒 Security Features

### 1. **TLS/HTTPS Encryption**
- Automated certificate issuance via Let's Encrypt
- Auto-renewal before expiration
- HTTPS redirect for all HTTP traffic
- HSTS (HTTP Strict Transport Security)
- Modern TLS 1.2+ only

### 2. **Authentication**
- Session-based authentication
- Bcrypt password hashing (10 rounds)
- Secure HTTP-only cookies
- Session expiry (24 hours)
- Password complexity requirements

### 3. **Rate Limiting**
- **General API**: 100 requests per 15 minutes per IP
- **Login endpoint**: 5 attempts per 15 minutes per IP
- Real-time blocking with informative error messages
- Configurable limits via environment variables

### 4. **Security Headers** (via Helmet.js)
- Content Security Policy (CSP)
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Referrer-Policy
- HSTS with preload

### 5. **Security Logging**
- All authentication attempts (success and failure)
- Rate limit violations
- Suspicious request patterns
- User session events
- Structured JSON logs with Winston

### 6. **Additional Security**
- Non-root container user
- Input validation and sanitization
- SQL injection prevention
- XSS protection
- CSRF protection via SameSite cookies

## 🚀 Quick Start

### Prerequisites

1. **Server Requirements**:
   - Linux server with public IP
   - Ports 80 and 443 open
   - Domain name pointing to your server

2. **Local Requirements**:
   - Docker installed
   - Node.js 18+ (for local testing)

### Option 1: Local Testing (HTTP)

```bash
# Navigate to the app directory
cd 2048

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env and set:
# - NODE_ENV=development
# - ADMIN_PASSWORD=YourSecurePassword123!
# - ENABLE_HTTPS=false

# Start the server
npm start

# Access at http://localhost:3000
# Default login: admin / ChangeMe123! (or your ADMIN_PASSWORD)
```

### Option 2: Production Deployment with HTTPS

#### Step 1: Prepare Your Domain

```bash
# Ensure your domain (e.g., secure.yourdomain.com) points to your server
# Check DNS propagation:
dig secure.yourdomain.com
nslookup secure.yourdomain.com
```

#### Step 2: Configure Environment

```bash
# Create production .env file
cat > .env << EOF
NODE_ENV=production
PORT=80
HOST=0.0.0.0

# CRITICAL: Change these!
SESSION_SECRET=$(openssl rand -base64 48)
ADMIN_PASSWORD=YourVerySecurePassword123!

# Let's Encrypt Configuration
ENABLE_HTTPS=true
DOMAIN=secure.yourdomain.com
EMAIL=your-email@example.com
ACME_DIRECTORY_URL=https://acme-v02.api.letsencrypt.org/directory

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
AUTH_RATE_LIMIT_MAX=5
EOF
```

#### Step 3: Test with Let's Encrypt Staging (Recommended)

```bash
# First, test with staging to avoid rate limits
# Edit .env and change:
ACME_DIRECTORY_URL=https://acme-staging-v02.api.letsencrypt.org/directory

# Start with staging
npm start

# Verify staging certificate works (browser will show warning - this is expected)
# Check logs for successful certificate issuance
```

#### Step 4: Deploy with Production Certificates

```bash
# Edit .env back to production:
ACME_DIRECTORY_URL=https://acme-v02.api.letsencrypt.org/directory

# Remove staging certificates
rm -rf greenlock.d

# Start production server
npm start
```

### Option 3: Docker Deployment

```bash
# Build the image
docker build -t secure-2048:latest .

# Run with environment variables
docker run -d \
  --name secure-2048 \
  -p 80:80 \
  -p 443:443 \
  -e NODE_ENV=production \
  -e ENABLE_HTTPS=true \
  -e DOMAIN=secure.yourdomain.com \
  -e EMAIL=your-email@example.com \
  -e ADMIN_PASSWORD=YourSecurePassword123! \
  -e SESSION_SECRET=$(openssl rand -base64 48) \
  -v $(pwd)/greenlock.d:/app/greenlock.d \
  -v $(pwd)/logs:/app/logs \
  secure-2048:latest

# View logs
docker logs -f secure-2048
```

### Option 4: Deploy to AWS ECS (Recommended for Production)

The existing CI/CD pipeline in this repo supports automated deployment to AWS ECS Fargate:

```bash
# Configure GitHub secrets (see README.md)
# Push to main branch triggers automatic deployment

# The application will be available at:
# http://your-alb-address.region.elb.amazonaws.com

# For custom domain with HTTPS:
# 1. Point your domain to the ALB
# 2. Set environment variables in ECS task definition
# 3. Certificate will be auto-issued on first request
```

## 🧪 Testing Security Features

### Test 1: Try Accessing Without Authentication

```bash
# Should redirect to login
curl -L http://secure.yourdomain.com/game
```

### Test 2: Rate Limit Testing

```bash
# Attempt multiple failed logins
for i in {1..6}; do
  curl -X POST http://secure.yourdomain.com/api/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrong"}' \
    -w "\n%{http_code}\n"
  echo "Attempt $i"
done

# 6th attempt should return 429 (Too Many Requests)
```

### Test 3: Check Security Headers

```bash
curl -I https://secure.yourdomain.com

# Should see:
# Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
```

### Test 4: View Security Logs

```bash
# Real-time log monitoring
tail -f logs/security.log

# Filter for failed authentication
grep "Login failed" logs/security.log

# View rate limit violations
grep "Rate limit exceeded" logs/security.log
```

### Test 5: Simulate Bot Attack

```bash
# Run automated login attempts (simulates brute force)
# This should trigger rate limiting after 5 attempts

for password in $(cat common-passwords.txt); do
  curl -X POST https://secure.yourdomain.com/api/login \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"$password\"}"
  sleep 1
done

# Watch security logs to see the defense in action
tail -f logs/security.log
```

## 📊 Monitoring in Production

### View Live Security Events

The login page includes a **real-time security event log** that shows:
- Login attempts
- Rate limit violations
- Authentication successes/failures
- Human behavior detection (mouse movement, input focus)

### Check Application Logs

```bash
# All logs (combined)
tail -f logs/combined.log

# Security events only
tail -f logs/security.log

# Errors only
tail -f logs/error.log

# Watch for specific events
grep "Authentication successful" logs/security.log
grep "Rate limit exceeded" logs/security.log
```

### Monitor with CloudWatch (AWS deployment)

The CI/CD pipeline automatically configures CloudWatch logging:

```bash
# View logs in AWS Console
aws logs tail /ecs/2048-app --follow

# Create alarms for security events
# (Already configured in Terraform)
```

## 🔐 Default Credentials

**⚠️ CHANGE THESE IMMEDIATELY IN PRODUCTION**

```
Username: admin
Password: ChangeMe123! (or value of ADMIN_PASSWORD env var)
```

## 🛡️ Best Practices

### 1. Password Security
- Minimum 8 characters
- Must contain uppercase, lowercase, and numbers
- Stored with bcrypt (10 rounds)
- Never log passwords

### 2. Session Security
- HTTP-only cookies (no JavaScript access)
- Secure flag in production (HTTPS only)
- SameSite: strict (CSRF protection)
- 24-hour expiry

### 3. TLS/HTTPS
- Use production Let's Encrypt (not staging)
- Monitor certificate expiry (auto-renewed at 30 days)
- Enable HSTS preload
- Disable old TLS versions

### 4. Rate Limiting
- Adjust limits based on traffic patterns
- Monitor logs for legitimate users being blocked
- Consider IP whitelisting for known good IPs

### 5. Logging
- Log all security events
- Rotate logs (prevent disk filling)
- Consider centralized logging (ELK, Splunk)
- Never log sensitive data (passwords, tokens)

## 🚨 Incident Response

### Suspicious Activity Detected

```bash
# 1. Check security logs
grep "suspicious" logs/security.log -A 5

# 2. Identify attacking IPs
grep "Rate limit exceeded" logs/security.log | awk '{print $X}' | sort | uniq -c

# 3. Block at firewall level (temporary)
sudo ufw deny from <attacker-ip>

# 4. Review all authentication attempts from that IP
grep "<attacker-ip>" logs/combined.log
```

### Account Compromise

```bash
# 1. Force logout all sessions (restart server)
docker restart secure-2048

# 2. Change admin password immediately
# Edit .env and update ADMIN_PASSWORD

# 3. Review access logs
grep "admin" logs/combined.log | grep "Successful login"

# 4. Check for unauthorized changes
git log --all --since="24 hours ago"
```

## 📈 Scaling Security

### Add Redis for Session Store (Recommended for Production)

```javascript
// Update server.js to use Redis for sessions
const Redis = require('ioredis');
const RedisStore = require('connect-redis').default;

const redisClient = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});

app.use(session({
  store: new RedisStore({ client: redisClient }),
  // ... other options
}));
```

### Add WAF (Web Application Firewall)

For AWS ALB deployments, enable AWS WAF:
- SQL injection protection
- XSS prevention
- Rate limiting at edge
- Geo-blocking
- Bot detection

### Add Multi-Factor Authentication (MFA)

```bash
npm install speakeasy qrcode

# Implement TOTP (Time-based One-Time Password)
# See examples in security documentation
```

## 🎓 Learning Outcomes

After completing this setup, you will have:

1. ✅ **Real TLS certificate** - Not self-signed, but trusted by all browsers
2. ✅ **Real authentication** - Session-based with secure cookies
3. ✅ **Real rate limiting** - Protecting against actual attacks
4. ✅ **Real logging** - Visibility into who's trying to access your app
5. ✅ **Real internet exposure** - Your app is accessible worldwide

**Most importantly**: You'll have experienced what it's like to secure a real application against real threats. This is invaluable experience that you can't get from localhost development.

## 🐛 Troubleshooting

### Let's Encrypt Certificate Fails

```bash
# Check DNS is pointing to your server
dig +short yourdomain.com

# Ensure ports 80 and 443 are open
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Check firewall
sudo ufw status

# View Let's Encrypt logs
tail -f greenlock.d/logs/*.log

# Test with staging first to avoid rate limits
```

### Rate Limiting Too Aggressive

```bash
# Edit .env to increase limits
RATE_LIMIT_MAX_REQUESTS=200
AUTH_RATE_LIMIT_MAX=10

# Or increase time window
RATE_LIMIT_WINDOW_MS=1800000  # 30 minutes
```

### Sessions Not Persisting

```bash
# Check session secret is set
echo $SESSION_SECRET

# Verify cookies are being set
# In browser DevTools > Application > Cookies

# Check for clock skew
ntpdate -q pool.ntp.org
```

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Express Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)

## 🎯 What's Next?

Now that you have a secure web application:

1. **Monitor it** - Watch the logs and see real attack attempts
2. **Test it** - Try to break into your own app
3. **Improve it** - Add more security features (MFA, CAPTCHA, etc.)
4. **Scale it** - Deploy to multiple regions, add WAF, use Redis
5. **Learn from it** - Analyze attack patterns, improve defenses

**Security is not a checkbox. It's a continuous process of improvement.**

---

**Built with**: Node.js, Express, Let's Encrypt, Helmet, Winston, bcrypt
**Deployed to**: AWS ECS Fargate with automated CI/CD
**License**: MIT
