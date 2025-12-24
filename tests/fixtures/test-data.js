/**
 * Test Data Fixtures
 *
 * Centralized test data for consistent testing across the suite
 */

/**
 * HTTP Security Headers
 */
const securityHeaders = {
  required: [
    'X-Frame-Options',
    'X-Content-Type-Options',
    'X-XSS-Protection',
    'Referrer-Policy'
  ],

  expected: {
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'no-referrer-when-downgrade'
  },

  optional: [
    'Content-Security-Policy',
    'Strict-Transport-Security',
    'Permissions-Policy'
  ]
};

/**
 * Performance Budgets
 */
const performanceBudgets = {
  pageLoad: {
    maxTime: 3000, // 3 seconds
    warnTime: 2000  // 2 seconds
  },

  firstContentfulPaint: {
    maxTime: 1500, // 1.5 seconds
    warnTime: 1000  // 1 second
  },

  largestContentfulPaint: {
    maxTime: 2500, // 2.5 seconds
    warnTime: 1800  // 1.8 seconds
  },

  timeToInteractive: {
    maxTime: 3500, // 3.5 seconds
    warnTime: 2500  // 2.5 seconds
  },

  totalBlockingTime: {
    maxTime: 200,  // 200ms
    warnTime: 150   // 150ms
  },

  cumulativeLayoutShift: {
    maxScore: 0.1,
    warnScore: 0.05
  },

  pageSize: {
    maxBytes: 102400, // 100KB
    warnBytes: 81920   // 80KB
  }
};

/**
 * Lighthouse Score Thresholds
 */
const lighthouseScores = {
  performance: {
    min: 90,
    warn: 95
  },

  accessibility: {
    min: 95,
    warn: 98
  },

  bestPractices: {
    min: 90,
    warn: 95
  },

  seo: {
    min: 90,
    warn: 95
  }
};

/**
 * Network Conditions for Testing
 */
const networkConditions = {
  slow3G: {
    downloadThroughput: 400 * 1024 / 8, // 400 Kbps
    uploadThroughput: 400 * 1024 / 8,
    latency: 400
  },

  fast3G: {
    downloadThroughput: 1.6 * 1024 * 1024 / 8, // 1.6 Mbps
    uploadThroughput: 750 * 1024 / 8,
    latency: 150
  },

  slow4G: {
    downloadThroughput: 4 * 1024 * 1024 / 8, // 4 Mbps
    uploadThroughput: 3 * 1024 * 1024 / 8,
    latency: 50
  },

  offline: {
    downloadThroughput: 0,
    uploadThroughput: 0,
    latency: 0
  }
};

/**
 * Viewport Sizes for Responsive Testing
 */
const viewports = {
  mobile: {
    width: 375,
    height: 667,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true
  },

  tablet: {
    width: 768,
    height: 1024,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true
  },

  desktop: {
    width: 1920,
    height: 1080,
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false
  },

  ultrawide: {
    width: 3440,
    height: 1440,
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false
  }
};

/**
 * Docker Test Configuration
 */
const dockerConfig = {
  maxImageSize: 104857600, // 100MB in bytes
  maxLayers: 20,
  healthCheckInterval: 30000, // 30 seconds
  healthCheckTimeout: 3000,   // 3 seconds
  healthCheckRetries: 3,

  expectedPorts: [80],
  expectedUser: 'nginx', // If running as non-root

  memoryLimit: {
    min: 52428800,  // 50MB minimum
    max: 524288000   // 500MB maximum
  }
};

/**
 * Load Test Configuration
 */
const loadTestConfig = {
  smoke: {
    vus: 1,
    duration: '30s',
    thresholds: {
      http_req_duration: ['p(95)<300'],
      http_req_failed: ['rate<0.01']
    }
  },

  load: {
    stages: [
      { duration: '1m', target: 20 },
      { duration: '2m', target: 50 },
      { duration: '1m', target: 100 },
      { duration: '2m', target: 100 },
      { duration: '1m', target: 0 }
    ],
    thresholds: {
      http_req_duration: ['p(95)<300', 'p(99)<500'],
      http_req_failed: ['rate<0.01'],
      http_reqs: ['rate>10']
    }
  },

  stress: {
    stages: [
      { duration: '2m', target: 100 },
      { duration: '5m', target: 200 },
      { duration: '2m', target: 300 },
      { duration: '5m', target: 300 },
      { duration: '2m', target: 0 }
    ],
    thresholds: {
      http_req_duration: ['p(95)<500', 'p(99)<1000'],
      http_req_failed: ['rate<0.05']
    }
  },

  spike: {
    stages: [
      { duration: '10s', target: 20 },
      { duration: '1m', target: 20 },
      { duration: '10s', target: 200 },
      { duration: '3m', target: 200 },
      { duration: '10s', target: 20 },
      { duration: '3m', target: 20 },
      { duration: '10s', target: 0 }
    ],
    thresholds: {
      http_req_duration: ['p(95)<800'],
      http_req_failed: ['rate<0.1']
    }
  }
};

/**
 * Environment URLs
 */
const environments = {
  local: 'http://localhost:8080',
  dev: process.env.DEV_URL || 'http://localhost:8080',
  staging: process.env.STAGING_URL || '',
  production: process.env.PROD_URL || ''
};

/**
 * Test User Agents
 */
const userAgents = {
  chrome: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  firefox: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  safari: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
  edge: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  mobile: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1'
};

/**
 * Common Test Timeouts
 */
const timeouts = {
  short: 5000,      // 5 seconds
  medium: 15000,    // 15 seconds
  long: 30000,      // 30 seconds
  veryLong: 60000   // 60 seconds
};

module.exports = {
  securityHeaders,
  performanceBudgets,
  lighthouseScores,
  networkConditions,
  viewports,
  dockerConfig,
  loadTestConfig,
  environments,
  userAgents,
  timeouts
};
