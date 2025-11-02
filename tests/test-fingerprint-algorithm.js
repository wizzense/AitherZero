#!/usr/bin/env node

/**
 * Test script to validate the enhanced fingerprinting algorithm
 * for issue deduplication in phase2-intelligent-issue-creation.yml
 */

const crypto = require('crypto');

// Helper: Create fingerprint with enhanced normalization
function createFingerprint(failure) {
  // Normalize file paths - remove absolute paths, keep only relative structure
  const normalizeFile = (filePath) => {
    if (!filePath) return 'unknown';
    return filePath
      .replace(/\\/g, '/')  // Normalize path separators
      .replace(/^.*?(domains|tests|automation-scripts|infrastructure)/i, '$1')  // Remove prefix
      .toLowerCase()
      .trim();
  };

  // Normalize error messages - remove volatile data that changes between runs
  const normalizeError = (errorMsg) => {
    if (!errorMsg) return 'unknown';
    return errorMsg
      .toLowerCase()
      // Replace specific patterns FIRST before general number replacement
      .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, 'GUID')  // Replace GUIDs
      .replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z?/g, 'TIMESTAMP')  // Replace ISO timestamps
      .replace(/\d{4}-\d{2}-\d{2}/g, 'DATE')  // Replace dates
      .replace(/\b[0-9a-f]{32,}\b/gi, 'HASH')  // Replace long hex strings
      // THEN replace general patterns
      .replace(/line \d+/gi, 'line N')  // Normalize line numbers
      .replace(/at \d+:\d+/g, 'at N:N')  // Normalize position references
      .replace(/\d+/g, 'N')  // Replace all remaining numbers with 'N'
      .replace(/\s+/g, ' ')  // Normalize whitespace
      .trim();
  };

  // Normalize test names - keep the test name but remove parameters
  const normalizeTestName = (testName) => {
    if (!testName) return 'unknown';
    return testName
      .replace(/\s*\[.*?\]\s*/g, '')  // Remove parameterized test data in brackets
      .replace(/\s+\d+\s+/g, ' ')  // Remove numbers between words
      .toLowerCase()
      .trim();
  };

  // Build stable fingerprint from normalized data
  const fingerprintData = {
    type: failure.Type || failure.TestType || 'unknown',
    file: normalizeFile(failure.File),
    error: normalizeError(failure.ErrorMessage || failure.Message),
    category: failure.Category || failure.RuleName || 'general',
    testName: failure.TestName ? normalizeTestName(failure.TestName) : undefined
  };

  // Remove undefined values for stable hashing
  Object.keys(fingerprintData).forEach(key => {
    if (fingerprintData[key] === undefined) {
      delete fingerprintData[key];
    }
  });

  const normalizedData = JSON.stringify(fingerprintData, Object.keys(fingerprintData).sort());
  const fingerprint = crypto.createHash('sha256').update(normalizedData).digest('hex').substring(0, 16);

  return { fingerprint, fingerprintData };
}

// Test cases
const testCases = [
  {
    name: "Same error different line numbers should match",
    failure1: {
      File: "domains/configuration/Configuration.psm1",
      ErrorMessage: "Expected 'true' but got 'false' at line 42",
      TestType: "Unit"
    },
    failure2: {
      File: "domains/configuration/Configuration.psm1",
      ErrorMessage: "Expected 'true' but got 'false' at line 87",
      TestType: "Unit"
    },
    shouldMatch: true
  },
  {
    name: "Same error different timestamps should match",
    failure1: {
      File: "tests/unit/Security.Tests.ps1",
      ErrorMessage: "Certificate validation failed on 2025-11-01T10:30:45",
      TestType: "Unit"
    },
    failure2: {
      File: "tests/unit/Security.Tests.ps1",
      ErrorMessage: "Certificate validation failed on 2025-11-02T15:22:13",
      TestType: "Unit"
    },
    shouldMatch: true
  },
  {
    name: "Same error different GUIDs should match",
    failure1: {
      File: "automation-scripts/0100_Setup.ps1",
      ErrorMessage: "Resource not found: a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      TestType: "Integration"
    },
    failure2: {
      File: "automation-scripts/0100_Setup.ps1",
      ErrorMessage: "Resource not found: 9f8e7d6c-5b4a-3210-fedc-ba0987654321",
      TestType: "Integration"
    },
    shouldMatch: true
  },
  {
    name: "Different files should NOT match",
    failure1: {
      File: "domains/infrastructure/VmManagement.psm1",
      ErrorMessage: "Failed to create VM",
      TestType: "Unit"
    },
    failure2: {
      File: "domains/security/CertificateManagement.psm1",
      ErrorMessage: "Failed to create VM",
      TestType: "Unit"
    },
    shouldMatch: false
  },
  {
    name: "Different errors should NOT match",
    failure1: {
      File: "tests/unit/Logging.Tests.ps1",
      ErrorMessage: "Expected log level INFO",
      TestType: "Unit"
    },
    failure2: {
      File: "tests/unit/Logging.Tests.ps1",
      ErrorMessage: "Expected log level ERROR",
      TestType: "Unit"
    },
    shouldMatch: false
  },
  {
    name: "Parameterized test names should match",
    failure1: {
      File: "tests/unit/Validation.Tests.ps1",
      TestName: "Should validate input [TestCase1]",
      ErrorMessage: "Validation failed",
      TestType: "Unit"
    },
    failure2: {
      File: "tests/unit/Validation.Tests.ps1",
      TestName: "Should validate input [TestCase2]",
      ErrorMessage: "Validation failed",
      TestType: "Unit"
    },
    shouldMatch: true
  },
  {
    name: "Absolute vs relative paths should match",
    failure1: {
      File: "/home/runner/work/AitherZero/AitherZero/domains/experience/UserInterface.psm1",
      ErrorMessage: "UI element not found",
      TestType: "Unit"
    },
    failure2: {
      File: "domains/experience/UserInterface.psm1",
      ErrorMessage: "UI element not found",
      TestType: "Unit"
    },
    shouldMatch: true
  }
];

// Run tests
console.log('🧪 Testing Enhanced Fingerprint Algorithm\n');
console.log('='.repeat(70));

let passed = 0;
let failed = 0;

testCases.forEach((test, index) => {
  const result1 = createFingerprint(test.failure1);
  const result2 = createFingerprint(test.failure2);

  const fingerprintsMatch = result1.fingerprint === result2.fingerprint;
  const testPassed = fingerprintsMatch === test.shouldMatch;

  console.log(`\nTest ${index + 1}: ${test.name}`);
  console.log(`  Fingerprint 1: ${result1.fingerprint}`);
  console.log(`  Fingerprint 2: ${result2.fingerprint}`);
  console.log(`  Expected: ${test.shouldMatch ? 'MATCH' : 'NO MATCH'}`);
  console.log(`  Actual: ${fingerprintsMatch ? 'MATCH' : 'NO MATCH'}`);
  console.log(`  Result: ${testPassed ? '✅ PASS' : '❌ FAIL'}`);

  if (!testPassed) {
    console.log(`  Debug Info:`);
    console.log(`    Data 1:`, JSON.stringify(result1.fingerprintData, null, 2));
    console.log(`    Data 2:`, JSON.stringify(result2.fingerprintData, null, 2));
  }

  testPassed ? passed++ : failed++;
});

console.log('\n' + '='.repeat(70));
console.log(`\n📊 Test Results: ${passed} passed, ${failed} failed out of ${testCases.length} tests`);

if (failed > 0) {
  process.exit(1);
}

console.log('\n✅ All tests passed! Fingerprint algorithm is working correctly.\n');
