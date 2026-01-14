module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'server.js',
    '!node_modules/**',
    '!coverage/**',
    '!jest.config.js'
  ],
  testMatch: [
    '**/test/**/*.test.js'
  ],
  verbose: true
};
