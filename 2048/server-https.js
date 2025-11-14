require('dotenv').config();
const greenlockExpress = require('greenlock-express');
const app = require('./server');
const path = require('path');

// Production HTTPS server with Let's Encrypt
if (process.env.ENABLE_HTTPS === 'true') {
  console.log('Starting HTTPS server with Let\'s Encrypt...');

  greenlockExpress
    .init({
      packageRoot: __dirname,
      configDir: './greenlock.d',

      // Contact for Let's Encrypt notifications
      maintainerEmail: process.env.EMAIL || 'admin@example.com',

      // Cluster options (for load balancing)
      cluster: false,

      // Manager for storing certs
      manager: {
        module: 'greenlock-manager-fs',
        basePath: './greenlock.d'
      }
    })
    .serve(app, function (glx) {
      // Greenlock Express serves on 80 and 443
      console.log(`
╔═══════════════════════════════════════════════════════════╗
║  🔐 HTTPS Server with Let's Encrypt                       ║
║                                                           ║
║  HTTP:  Port 80 (redirects to HTTPS)                     ║
║  HTTPS: Port 443 (with TLS certificate)                  ║
║  Domain: ${process.env.DOMAIN || 'Not configured'}                                    ║
║  Email:  ${process.env.EMAIL || 'Not configured'}                               ║
║                                                           ║
║  Let's Encrypt will automatically:                        ║
║  - Issue TLS certificate for your domain                  ║
║  - Renew certificates before expiration                   ║
║  - Handle ACME challenges                                 ║
║                                                           ║
║  ⚠️  Make sure your domain points to this server!         ║
╚═══════════════════════════════════════════════════════════╝
      `);
    });
} else {
  // Development/HTTP-only server
  const PORT = process.env.PORT || 3000;
  const HOST = process.env.HOST || '0.0.0.0';

  app.listen(PORT, HOST, () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║  🔧 Development Server (HTTP Only)                        ║
║                                                           ║
║  Port: ${PORT}                                              ║
║  Host: ${HOST}                                        ║
║                                                           ║
║  To enable HTTPS with Let's Encrypt:                      ║
║  1. Set ENABLE_HTTPS=true in .env                         ║
║  2. Set DOMAIN to your domain name                        ║
║  3. Set EMAIL to your email address                       ║
║  4. Ensure port 80 and 443 are open                       ║
║  5. Point your domain to this server                      ║
║                                                           ║
║  Note: HTTPS requires a public domain name.               ║
║        For local testing, use HTTP mode.                  ║
╚═══════════════════════════════════════════════════════════╝
    `);
  });
}
