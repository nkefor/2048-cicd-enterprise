module.exports = {
  testEnvironment: 'jsdom',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    '2048/www/js/**/*.js',
    'tests/**/*.js',
    '!tests/**/*.test.js',
    '!tests/**/*.spec.js',
    '!tests/e2e/**',
    '!tests/smoke/**',
    '!tests/load/**',
    '!tests/performance/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  testMatch: [
    '**/tests/unit/**/*.test.js',
    '**/tests/integration/**/*.test.js'
  ],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/tests/e2e/',
    '/tests/smoke/',
    '/tests/load/',
    '/tests/performance/'
  ],
  moduleFileExtensions: ['js', 'json'],
  verbose: true,
  collectCoverage: false,
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: 'test-results',
      outputName: 'junit.xml',
      classNameTemplate: '{classname}',
      titleTemplate: '{title}',
      ancestorSeparator: ' › ',
      usePathForSuiteName: true
    }]
  ]
};
