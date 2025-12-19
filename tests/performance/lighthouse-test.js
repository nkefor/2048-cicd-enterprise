#!/usr/bin/env node

/**
 * Lighthouse Performance Testing
 * Tests performance budgets and web vitals using Google Lighthouse
 */

const lighthouse = require('lighthouse');
const chromeLauncher = require('chrome-launcher');
const fs = require('fs');
const path = require('path');

// Configuration
const TEST_URL = process.env.TEST_URL || 'http://localhost:8080';
const OUTPUT_DIR = path.join(__dirname, '../../lighthouse-reports');

// Performance budgets
const PERFORMANCE_BUDGETS = {
  performance: 90,
  accessibility: 90,
  'best-practices': 80,
  seo: 80,
  pwa: 50, // Optional for static site
};

const METRICS_BUDGETS = {
  'first-contentful-paint': 1800, // ms
  'largest-contentful-paint': 2500, // ms
  'total-blocking-time': 300, // ms
  'cumulative-layout-shift': 0.1,
  'speed-index': 3000, // ms
  'interactive': 3800, // ms
};

async function runLighthouse() {
  console.log('🚀 Starting Lighthouse performance tests...');
  console.log(`📍 Testing URL: ${TEST_URL}\n`);

  let chrome;
  let results;

  try {
    // Launch Chrome
    chrome = await chromeLauncher.launch({
      chromeFlags: ['--headless', '--disable-gpu', '--no-sandbox'],
    });

    // Run Lighthouse
    const options = {
      logLevel: 'info',
      output: 'html',
      onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo', 'pwa'],
      port: chrome.port,
    };

    const runnerResult = await lighthouse(TEST_URL, options);

    // Extract results
    results = runnerResult.lhr;

    // Save HTML report
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    const reportPath = path.join(OUTPUT_DIR, `lighthouse-${Date.now()}.html`);
    fs.writeFileSync(reportPath, runnerResult.report);
    console.log(`📊 Report saved to: ${reportPath}\n`);

    // Save JSON results
    const jsonPath = path.join(OUTPUT_DIR, `lighthouse-${Date.now()}.json`);
    fs.writeFileSync(jsonPath, JSON.stringify(results, null, 2));

  } catch (error) {
    console.error('❌ Error running Lighthouse:', error);
    process.exit(1);
  } finally {
    if (chrome) {
      await chrome.kill();
    }
  }

  return results;
}

function checkCategoryScores(results) {
  console.log('📈 Category Scores:');
  console.log('─'.repeat(50));

  let allPassed = true;

  for (const [category, minScore] of Object.entries(PERFORMANCE_BUDGETS)) {
    const score = results.categories[category]?.score * 100 || 0;
    const passed = score >= minScore;
    const icon = passed ? '✅' : '❌';

    console.log(`${icon} ${category.padEnd(20)}: ${score.toFixed(1)}% (required: ${minScore}%)`);

    if (!passed) {
      allPassed = false;
    }
  }

  console.log('─'.repeat(50));
  return allPassed;
}

function checkMetricsBudgets(results) {
  console.log('\n⚡ Core Web Vitals & Metrics:');
  console.log('─'.repeat(50));

  let allPassed = true;
  const audits = results.audits;

  // First Contentful Paint
  const fcp = audits['first-contentful-paint']?.numericValue || 0;
  const fcpPassed = fcp <= METRICS_BUDGETS['first-contentful-paint'];
  console.log(`${fcpPassed ? '✅' : '❌'} First Contentful Paint: ${fcp.toFixed(0)}ms (budget: ${METRICS_BUDGETS['first-contentful-paint']}ms)`);
  if (!fcpPassed) allPassed = false;

  // Largest Contentful Paint
  const lcp = audits['largest-contentful-paint']?.numericValue || 0;
  const lcpPassed = lcp <= METRICS_BUDGETS['largest-contentful-paint'];
  console.log(`${lcpPassed ? '✅' : '❌'} Largest Contentful Paint: ${lcp.toFixed(0)}ms (budget: ${METRICS_BUDGETS['largest-contentful-paint']}ms)`);
  if (!lcpPassed) allPassed = false;

  // Total Blocking Time
  const tbt = audits['total-blocking-time']?.numericValue || 0;
  const tbtPassed = tbt <= METRICS_BUDGETS['total-blocking-time'];
  console.log(`${tbtPassed ? '✅' : '❌'} Total Blocking Time: ${tbt.toFixed(0)}ms (budget: ${METRICS_BUDGETS['total-blocking-time']}ms)`);
  if (!tbtPassed) allPassed = false;

  // Cumulative Layout Shift
  const cls = audits['cumulative-layout-shift']?.numericValue || 0;
  const clsPassed = cls <= METRICS_BUDGETS['cumulative-layout-shift'];
  console.log(`${clsPassed ? '✅' : '❌'} Cumulative Layout Shift: ${cls.toFixed(3)} (budget: ${METRICS_BUDGETS['cumulative-layout-shift']})`);
  if (!clsPassed) allPassed = false;

  // Speed Index
  const si = audits['speed-index']?.numericValue || 0;
  const siPassed = si <= METRICS_BUDGETS['speed-index'];
  console.log(`${siPassed ? '✅' : '❌'} Speed Index: ${si.toFixed(0)}ms (budget: ${METRICS_BUDGETS['speed-index']}ms)`);
  if (!siPassed) allPassed = false;

  // Time to Interactive
  const tti = audits['interactive']?.numericValue || 0;
  const ttiPassed = tti <= METRICS_BUDGETS['interactive'];
  console.log(`${ttiPassed ? '✅' : '❌'} Time to Interactive: ${tti.toFixed(0)}ms (budget: ${METRICS_BUDGETS['interactive']}ms)`);
  if (!ttiPassed) allPassed = false;

  console.log('─'.repeat(50));
  return allPassed;
}

function checkResourceSizes(results) {
  console.log('\n📦 Resource Sizes:');
  console.log('─'.repeat(50));

  const audits = results.audits;

  // Total page size
  const totalSize = audits['total-byte-weight']?.numericValue || 0;
  const totalSizeKB = (totalSize / 1024).toFixed(1);
  console.log(`📄 Total Page Size: ${totalSizeKB} KB`);

  // JavaScript size
  const jsSize = audits['bootup-time']?.details?.items?.[0]?.total || 0;
  console.log(`📜 JavaScript Execution: ${jsSize.toFixed(0)}ms`);

  // Image optimization
  const unoptimizedImages = audits['uses-optimized-images']?.details?.items?.length || 0;
  console.log(`🖼️  Unoptimized Images: ${unoptimizedImages}`);

  // Unused CSS
  const unusedCSS = audits['unused-css-rules']?.details?.items?.length || 0;
  console.log(`🎨 Unused CSS Rules: ${unusedCSS}`);

  // Render blocking resources
  const renderBlocking = audits['render-blocking-resources']?.details?.items?.length || 0;
  console.log(`🚧 Render Blocking Resources: ${renderBlocking}`);

  console.log('─'.repeat(50));
}

function checkAccessibilityIssues(results) {
  console.log('\n♿ Accessibility Issues:');
  console.log('─'.repeat(50));

  const audits = results.audits;
  const a11yAudits = [
    'color-contrast',
    'image-alt',
    'label',
    'aria-valid-attr',
    'button-name',
    'link-name',
  ];

  let issuesFound = 0;

  for (const auditKey of a11yAudits) {
    const audit = audits[auditKey];
    if (audit && audit.score !== null && audit.score < 1) {
      const itemCount = audit.details?.items?.length || 0;
      if (itemCount > 0) {
        console.log(`❌ ${audit.title}: ${itemCount} issue(s)`);
        issuesFound += itemCount;
      }
    }
  }

  if (issuesFound === 0) {
    console.log('✅ No critical accessibility issues found');
  } else {
    console.log(`⚠️  Total issues found: ${issuesFound}`);
  }

  console.log('─'.repeat(50));
}

function displayFailedAudits(results) {
  console.log('\n⚠️  Failed Audits:');
  console.log('─'.repeat(50));

  const failedAudits = [];

  for (const [key, audit] of Object.entries(results.audits)) {
    if (audit.score !== null && audit.score < 0.9 && audit.score >= 0) {
      failedAudits.push({
        id: key,
        title: audit.title,
        score: (audit.score * 100).toFixed(1),
        description: audit.description,
      });
    }
  }

  if (failedAudits.length === 0) {
    console.log('✅ All audits passed!');
  } else {
    failedAudits.slice(0, 10).forEach(audit => {
      console.log(`❌ ${audit.title} (${audit.score}%)`);
      console.log(`   ${audit.description.substring(0, 100)}...`);
    });

    if (failedAudits.length > 10) {
      console.log(`\n... and ${failedAudits.length - 10} more issues`);
    }
  }

  console.log('─'.repeat(50));
}

async function main() {
  console.log('═'.repeat(50));
  console.log('  LIGHTHOUSE PERFORMANCE TEST SUITE');
  console.log('═'.repeat(50));

  const results = await runLighthouse();

  const categoryScoresPassed = checkCategoryScores(results);
  const metricsPassed = checkMetricsBudgets(results);

  checkResourceSizes(results);
  checkAccessibilityIssues(results);
  displayFailedAudits(results);

  console.log('\n═'.repeat(50));

  if (categoryScoresPassed && metricsPassed) {
    console.log('✅ ALL PERFORMANCE TESTS PASSED!');
    console.log('═'.repeat(50));
    process.exit(0);
  } else {
    console.log('❌ SOME PERFORMANCE TESTS FAILED');
    console.log('═'.repeat(50));
    console.log('\n💡 Recommendations:');
    console.log('  - Review the HTML report for detailed recommendations');
    console.log('  - Optimize images and assets');
    console.log('  - Minimize JavaScript and CSS');
    console.log('  - Enable compression and caching');
    console.log('  - Fix accessibility issues\n');
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { runLighthouse, PERFORMANCE_BUDGETS, METRICS_BUDGETS };
