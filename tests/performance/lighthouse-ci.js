#!/usr/bin/env node

/**
 * Lighthouse CI Performance Testing
 *
 * Tests performance budgets using Google Lighthouse
 *
 * Priority: MEDIUM - Prevents performance regressions
 *
 * Usage:
 *   node tests/performance/lighthouse-ci.js
 *   BASE_URL=https://example.com node tests/performance/lighthouse-ci.js
 *
 * Performance Budgets:
 *   - Performance Score: >= 90
 *   - Accessibility Score: >= 95
 *   - Best Practices Score: >= 90
 *   - SEO Score: >= 90
 *   - First Contentful Paint: < 1.5s
 *   - Largest Contentful Paint: < 2.5s
 *   - Total Blocking Time: < 200ms
 *   - Cumulative Layout Shift: < 0.1
 */

const lighthouse = require('lighthouse');
const chromeLauncher = require('chrome-launcher');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';
const REPORT_DIR = path.join(__dirname, '../../test-results/lighthouse');

// Performance budgets
const PERFORMANCE_BUDGETS = {
  performance: 90,
  accessibility: 95,
  bestPractices: 90,
  seo: 90,
  pwa: 30, // Not a PWA, so low threshold
};

const METRICS_BUDGETS = {
  'first-contentful-paint': 1500, // 1.5s
  'largest-contentful-paint': 2500, // 2.5s
  'total-blocking-time': 200, // 200ms
  'cumulative-layout-shift': 0.1,
  'speed-index': 3000, // 3s
  'interactive': 3500, // 3.5s
};

/**
 * Launch Chrome and run Lighthouse
 */
async function runLighthouse(url) {
  console.log(`\n🔍 Running Lighthouse audit on: ${url}\n`);

  const chrome = await chromeLauncher.launch({
    chromeFlags: ['--headless', '--disable-gpu', '--no-sandbox'],
  });

  const options = {
    logLevel: 'info',
    output: ['html', 'json'],
    onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo', 'pwa'],
    port: chrome.port,
    throttling: {
      // Simulated Fast 3G
      rttMs: 150,
      throughputKbps: 1638.4,
      cpuSlowdownMultiplier: 4,
    },
  };

  try {
    const runnerResult = await lighthouse(url, options);

    await chrome.kill();

    return runnerResult;
  } catch (error) {
    await chrome.kill();
    throw error;
  }
}

/**
 * Check if scores meet budgets
 */
function checkScores(lhr) {
  const scores = {
    performance: lhr.categories.performance.score * 100,
    accessibility: lhr.categories.accessibility.score * 100,
    bestPractices: lhr.categories['best-practices'].score * 100,
    seo: lhr.categories.seo.score * 100,
    pwa: lhr.categories.pwa.score * 100,
  };

  console.log('📊 Lighthouse Scores:');
  console.log('─────────────────────────────────────');

  let allPassed = true;

  for (const [category, score] of Object.entries(scores)) {
    const budget = PERFORMANCE_BUDGETS[category];
    const passed = score >= budget;
    const icon = passed ? '✓' : '✗';
    const status = passed ? 'PASS' : 'FAIL';

    console.log(`${icon} ${category.padEnd(20)} ${score.toFixed(1)}% (budget: ${budget}%) [${status}]`);

    if (!passed) {
      allPassed = false;
    }
  }

  console.log('─────────────────────────────────────\n');

  return { scores, allPassed };
}

/**
 * Check if metrics meet budgets
 */
function checkMetrics(lhr) {
  const metrics = {
    'first-contentful-paint': lhr.audits['first-contentful-paint'].numericValue,
    'largest-contentful-paint': lhr.audits['largest-contentful-paint'].numericValue,
    'total-blocking-time': lhr.audits['total-blocking-time'].numericValue,
    'cumulative-layout-shift': lhr.audits['cumulative-layout-shift'].numericValue,
    'speed-index': lhr.audits['speed-index'].numericValue,
    'interactive': lhr.audits['interactive'].numericValue,
  };

  console.log('⏱  Core Web Vitals & Metrics:');
  console.log('─────────────────────────────────────');

  let allPassed = true;

  for (const [metric, value] of Object.entries(metrics)) {
    const budget = METRICS_BUDGETS[metric];
    let passed;
    let displayValue;

    if (metric === 'cumulative-layout-shift') {
      // CLS is a score, not time
      passed = value <= budget;
      displayValue = value.toFixed(3);
    } else {
      // Time metrics in milliseconds
      passed = value <= budget;
      displayValue = `${Math.round(value)}ms`;
    }

    const icon = passed ? '✓' : '✗';
    const status = passed ? 'PASS' : 'FAIL';
    const budgetDisplay = metric === 'cumulative-layout-shift' ? budget.toFixed(3) : `${budget}ms`;

    console.log(`${icon} ${metric.padEnd(30)} ${displayValue.padEnd(10)} (budget: ${budgetDisplay}) [${status}]`);

    if (!passed) {
      allPassed = false;
    }
  }

  console.log('─────────────────────────────────────\n');

  return { metrics, allPassed };
}

/**
 * Get failed audits
 */
function getFailedAudits(lhr) {
  const failedAudits = [];

  for (const [auditId, audit] of Object.entries(lhr.audits)) {
    if (audit.score !== null && audit.score < 1) {
      // Only include important audits
      if (audit.scoreDisplayMode === 'binary' || audit.scoreDisplayMode === 'numeric') {
        failedAudits.push({
          id: auditId,
          title: audit.title,
          description: audit.description,
          score: audit.score * 100,
          displayValue: audit.displayValue,
        });
      }
    }
  }

  return failedAudits;
}

/**
 * Save reports to disk
 */
function saveReports(lhr, reportHtml, reportJson) {
  // Create reports directory if it doesn't exist
  if (!fs.existsSync(REPORT_DIR)) {
    fs.mkdirSync(REPORT_DIR, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  // Save HTML report
  const htmlPath = path.join(REPORT_DIR, `lighthouse-${timestamp}.html`);
  fs.writeFileSync(htmlPath, reportHtml);
  console.log(`📄 HTML Report saved: ${htmlPath}`);

  // Save JSON report
  const jsonPath = path.join(REPORT_DIR, `lighthouse-${timestamp}.json`);
  fs.writeFileSync(jsonPath, reportJson);
  console.log(`📄 JSON Report saved: ${jsonPath}`);

  // Save summary
  const summary = {
    url: lhr.finalUrl,
    timestamp: lhr.fetchTime,
    scores: {
      performance: lhr.categories.performance.score * 100,
      accessibility: lhr.categories.accessibility.score * 100,
      bestPractices: lhr.categories['best-practices'].score * 100,
      seo: lhr.categories.seo.score * 100,
    },
    metrics: {
      fcp: lhr.audits['first-contentful-paint'].numericValue,
      lcp: lhr.audits['largest-contentful-paint'].numericValue,
      tbt: lhr.audits['total-blocking-time'].numericValue,
      cls: lhr.audits['cumulative-layout-shift'].numericValue,
      si: lhr.audits['speed-index'].numericValue,
      tti: lhr.audits['interactive'].numericValue,
    },
  };

  const summaryPath = path.join(REPORT_DIR, 'lighthouse-summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  console.log(`📄 Summary saved: ${summaryPath}\n`);
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('╔════════════════════════════════════════════════════════╗');
    console.log('║         Lighthouse Performance Audit                   ║');
    console.log('╚════════════════════════════════════════════════════════╝');

    // Run Lighthouse
    const runnerResult = await runLighthouse(BASE_URL);

    if (!runnerResult) {
      throw new Error('Lighthouse audit failed to complete');
    }

    const { lhr, report } = runnerResult;

    // Check scores
    const scoreResults = checkScores(lhr);

    // Check metrics
    const metricsResults = checkMetrics(lhr);

    // Get failed audits
    const failedAudits = getFailedAudits(lhr);

    if (failedAudits.length > 0) {
      console.log('⚠  Failed Audits (Top 10):');
      console.log('─────────────────────────────────────');

      failedAudits
        .sort((a, b) => a.score - b.score)
        .slice(0, 10)
        .forEach(audit => {
          console.log(`  • ${audit.title} (${audit.score.toFixed(0)}%)`);
          console.log(`    ${audit.description}`);
          if (audit.displayValue) {
            console.log(`    Value: ${audit.displayValue}`);
          }
          console.log();
        });
    }

    // Save reports
    saveReports(lhr, report[0], report[1]);

    // Determine overall pass/fail
    const overallPassed = scoreResults.allPassed && metricsResults.allPassed;

    if (overallPassed) {
      console.log('✅ All performance budgets met!\n');
      process.exit(0);
    } else {
      console.log('❌ Performance budgets not met\n');
      console.log('Review the detailed report for improvement opportunities.');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Lighthouse audit failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { runLighthouse, checkScores, checkMetrics };
