require('dotenv').config();
const express = require('express');
const session = require('express-session');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const bcrypt = require('bcryptjs');
const cookieParser = require('cookie-parser');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const { body, validationResult } = require('express-validator');
const winston = require('winston');

// Initialize Express app
const app = express();

// ============================================
// LOGGING CONFIGURATION
// ============================================
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/security.log', level: 'warn' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Create logs directory if it doesn't exist
if (!fs.existsSync('logs')) {
  fs.mkdirSync('logs');
}

// ============================================
// SECURITY MIDDLEWARE
// ============================================

// Helmet for security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // Required for inline scripts in game
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// HTTP request logging
app.use(morgan('combined', {
  stream: { write: message => logger.info(message.trim()) }
}));

// ============================================
// RATE LIMITING
// ============================================

// General API rate limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn({
      message: 'Rate limit exceeded',
      ip: req.ip,
      path: req.path,
      userAgent: req.get('user-agent')
    });
    res.status(429).json({
      error: 'Too many requests, please try again later.'
    });
  }
});

// Strict rate limiter for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login attempts per windowMs
  message: 'Too many login attempts, please try again later.',
  skipSuccessfulRequests: true,
  handler: (req, res) => {
    logger.warn({
      message: 'Auth rate limit exceeded',
      ip: req.ip,
      path: req.path,
      username: req.body.username
    });
    res.status(429).json({
      error: 'Too many login attempts. Please try again in 15 minutes.'
    });
  }
});

// Apply rate limiting
app.use('/api/', apiLimiter);

// ============================================
// SESSION MANAGEMENT
// ============================================

app.use(session({
  secret: process.env.SESSION_SECRET || 'change-this-secret-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production', // Require HTTPS in production
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict'
  },
  name: 'sessionId' // Don't use default 'connect.sid'
}));

// ============================================
// USER DATABASE (In-memory for demo)
// In production, use a real database
// ============================================

const users = new Map();

// Create default admin user (for demo)
const initializeUsers = async () => {
  const defaultPassword = process.env.ADMIN_PASSWORD || 'ChangeMe123!';
  const hashedPassword = await bcrypt.hash(defaultPassword, 10);
  users.set('admin', {
    username: 'admin',
    password: hashedPassword,
    email: 'admin@example.com',
    createdAt: new Date().toISOString()
  });

  logger.info('Default admin user created');
  if (!process.env.ADMIN_PASSWORD) {
    logger.warn('WARNING: Using default admin password. Set ADMIN_PASSWORD environment variable!');
  }
};

initializeUsers();

// ============================================
// AUTHENTICATION MIDDLEWARE
// ============================================

const requireAuth = (req, res, next) => {
  if (req.session && req.session.userId) {
    next();
  } else {
    res.status(401).json({ error: 'Authentication required' });
  }
};

// ============================================
// API ROUTES
// ============================================

// Health check endpoint (no auth required)
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Login endpoint
app.post('/api/login',
  authLimiter,
  [
    body('username').trim().isLength({ min: 3 }).escape(),
    body('password').isLength({ min: 6 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      logger.warn({
        message: 'Login validation failed',
        ip: req.ip,
        errors: errors.array()
      });
      return res.status(400).json({ error: 'Invalid input' });
    }

    const { username, password } = req.body;
    const user = users.get(username);

    if (!user) {
      logger.warn({
        message: 'Login failed - user not found',
        ip: req.ip,
        username: username
      });
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      logger.warn({
        message: 'Login failed - invalid password',
        ip: req.ip,
        username: username
      });
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Successful login
    req.session.userId = username;
    logger.info({
      message: 'Successful login',
      ip: req.ip,
      username: username
    });

    res.json({
      success: true,
      message: 'Login successful',
      username: username
    });
  }
);

// Logout endpoint
app.post('/api/logout', (req, res) => {
  const username = req.session.userId;
  req.session.destroy((err) => {
    if (err) {
      logger.error({
        message: 'Logout error',
        error: err.message,
        username: username
      });
      return res.status(500).json({ error: 'Logout failed' });
    }

    logger.info({
      message: 'User logged out',
      username: username
    });

    res.json({ success: true, message: 'Logged out successfully' });
  });
});

// Check auth status
app.get('/api/auth/status', (req, res) => {
  if (req.session && req.session.userId) {
    res.json({
      authenticated: true,
      username: req.session.userId
    });
  } else {
    res.json({ authenticated: false });
  }
});

// Register new user (protected endpoint)
app.post('/api/register',
  requireAuth, // Only authenticated users can create new users
  [
    body('username').trim().isLength({ min: 3, max: 20 }).isAlphanumeric().escape(),
    body('password').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
    body('email').isEmail().normalizeEmail()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { username, password, email } = req.body;

    if (users.has(username)) {
      return res.status(409).json({ error: 'Username already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    users.set(username, {
      username,
      password: hashedPassword,
      email,
      createdAt: new Date().toISOString()
    });

    logger.info({
      message: 'New user registered',
      username: username,
      createdBy: req.session.userId
    });

    res.status(201).json({
      success: true,
      message: 'User created successfully'
    });
  }
);

// Protected game endpoint - requires authentication
app.get('/game', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'www', 'index.html'));
});

// ============================================
// STATIC FILES & PUBLIC ROUTES
// ============================================

// Serve login page (public)
app.get('/', (req, res) => {
  // Check if user is already authenticated
  if (req.session && req.session.userId) {
    return res.redirect('/game');
  }
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

// Static files for login page
app.use('/public', express.static(path.join(__dirname, 'public')));

// ============================================
// SECURITY MONITORING
// ============================================

// Log suspicious activities
app.use((req, res, next) => {
  const suspicious = [
    req.path.includes('..'),
    req.path.includes('<script'),
    req.path.includes('SELECT'),
    req.path.includes('DROP'),
    req.get('user-agent') === undefined
  ];

  if (suspicious.some(Boolean)) {
    logger.warn({
      message: 'Suspicious request detected',
      ip: req.ip,
      path: req.path,
      userAgent: req.get('user-agent'),
      method: req.method
    });
  }

  next();
});

// ============================================
// ERROR HANDLING
// ============================================

// 404 handler
app.use((req, res) => {
  logger.warn({
    message: '404 Not Found',
    ip: req.ip,
    path: req.path
  });
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error({
    message: 'Server error',
    error: err.message,
    stack: err.stack,
    ip: req.ip,
    path: req.path
  });

  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message
  });
});

// ============================================
// SERVER STARTUP
// ============================================

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// HTTP server (will be upgraded to HTTPS in production with Let's Encrypt)
const server = app.listen(PORT, HOST, () => {
  logger.info({
    message: 'Server started',
    port: PORT,
    host: HOST,
    env: process.env.NODE_ENV || 'development',
    nodeVersion: process.version
  });

  console.log(`
╔═══════════════════════════════════════════════════════════╗
║  🔐 Secure 2048 Game Server                               ║
║                                                           ║
║  Status: Running                                          ║
║  Port: ${PORT}                                              ║
║  Environment: ${process.env.NODE_ENV || 'development'}                                  ║
║                                                           ║
║  Default Credentials:                                     ║
║  Username: admin                                          ║
║  Password: ${process.env.ADMIN_PASSWORD || 'ChangeMe123!'}                                    ║
║                                                           ║
║  ⚠️  CHANGE DEFAULT PASSWORD IN PRODUCTION!               ║
╚═══════════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

module.exports = app;
