/**
 * Test Fixtures
 * Reusable test data and setup for test suites
 */

/**
 * Expected security headers for all responses
 */
const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'x-xss-protection': '1; mode=block',
  'referrer-policy': 'no-referrer-when-downgrade'
};

/**
 * Performance budgets for page loads
 */
const PERFORMANCE_BUDGETS = {
  pageLoad: 3000,        // 3 seconds max
  domContentLoaded: 1500, // 1.5 seconds max
  firstContentfulPaint: 1500,
  largestContentfulPaint: 2500,
  timeToInteractive: 3500,
  cumulativeLayoutShift: 0.1,
  totalBlockingTime: 200,
  speedIndex: 3000,
  resourceSize: 102400    // 100KB max
};

/**
 * Lighthouse score thresholds
 */
const LIGHTHOUSE_THRESHOLDS = {
  performance: 90,
  accessibility: 95,
  bestPractices: 90,
  seo: 90
};

/**
 * Load test thresholds
 */
const LOAD_TEST_THRESHOLDS = {
  errorRate: 0.01,        // 1% max error rate
  p95ResponseTime: 300,   // 300ms max p95
  p99ResponseTime: 500,   // 500ms max p99
  maxResponseTime: 1000   // 1s max response time
};

/**
 * Common viewport sizes for responsive testing
 */
const VIEWPORTS = {
  mobile: { width: 375, height: 667 },        // iPhone SE
  mobileLarge: { width: 414, height: 896 },   // iPhone 11 Pro Max
  tablet: { width: 768, height: 1024 },       // iPad
  tabletLandscape: { width: 1024, height: 768 },
  desktop: { width: 1920, height: 1080 },     // Full HD
  desktopSmall: { width: 1366, height: 768 }  // Laptop
};

/**
 * Network conditions for testing
 */
const NETWORK_CONDITIONS = {
  slow3G: {
    downloadThroughput: 500 * 1024 / 8,
    uploadThroughput: 500 * 1024 / 8,
    latency: 400
  },
  fast3G: {
    downloadThroughput: 1.6 * 1024 * 1024 / 8,
    uploadThroughput: 750 * 1024 / 8,
    latency: 150
  },
  slow4G: {
    downloadThroughput: 4 * 1024 * 1024 / 8,
    uploadThroughput: 3 * 1024 * 1024 / 8,
    latency: 100
  },
  offline: {
    downloadThroughput: 0,
    uploadThroughput: 0,
    latency: 0
  }
};

/**
 * Browser user agents for testing
 */
const USER_AGENTS = {
  chrome: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  firefox: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
  safari: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
  edge: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  mobile: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
};

/**
 * Common error messages to check for
 */
const ERROR_PATTERNS = {
  javascript: [
    /Uncaught \w+Error/i,
    /Cannot read property/i,
    /undefined is not/i,
    /null is not/i
  ],
  network: [
    /Failed to fetch/i,
    /Network request failed/i,
    /CORS/i
  ],
  security: [
    /Refused to execute/i,
    /Content Security Policy/i,
    /Mixed Content/i
  ]
};

/**
 * Common CSS selectors for 2048 game
 */
const GAME_SELECTORS = {
  container: '.game-container, #game-container, .container',
  tiles: '.tile, .grid-cell, [class*="tile"]',
  score: '.score, .score-container, [class*="score"]',
  newGameButton: 'button, .restart-button, .new-game, [class*="new-game"]',
  gameOver: '.game-over, [class*="game-over"]',
  grid: '.grid, .grid-container, [class*="grid"]'
};

/**
 * Test environment configuration
 */
const TEST_ENV = {
  baseUrl: process.env.BASE_URL || 'http://localhost:8080',
  devUrl: process.env.DEV_URL || '',
  stagingUrl: process.env.STAGING_URL || '',
  prodUrl: process.env.PROD_URL || '',
  timeout: parseInt(process.env.TEST_TIMEOUT || '30000'),
  retries: parseInt(process.env.TEST_RETRIES || '2'),
  headless: process.env.HEADLESS !== 'false',
  slowMo: parseInt(process.env.SLOW_MO || '0')
};

/**
 * Docker test configuration
 */
const DOCKER_CONFIG = {
  imageName: '2048-test',
  containerName: 'test-container',
  port: 8080,
  maxImageSize: 100 * 1024 * 1024, // 100MB
  maxLayers: 20,
  healthCheckInterval: 30,
  healthCheckTimeout: 3,
  healthCheckRetries: 3
};

/**
 * Accessibility test configuration
 */
const A11Y_CONFIG = {
  wcagLevel: 'AA',
  standards: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'],
  rules: {
    'color-contrast': { enabled: true },
    'heading-order': { enabled: true },
    'html-has-lang': { enabled: true },
    'label': { enabled: true },
    'link-name': { enabled: true },
    'image-alt': { enabled: true }
  }
};

module.exports = {
  SECURITY_HEADERS,
  PERFORMANCE_BUDGETS,
  LIGHTHOUSE_THRESHOLDS,
  LOAD_TEST_THRESHOLDS,
  VIEWPORTS,
  NETWORK_CONDITIONS,
  USER_AGENTS,
  ERROR_PATTERNS,
  GAME_SELECTORS,
  TEST_ENV,
  DOCKER_CONFIG,
  A11Y_CONFIG
};
