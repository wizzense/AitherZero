---
allowed-tools: Glob, Read, Task, TodoWrite, Write
description: Run validation on all content in the system
---

## Your Task

Perform comprehensive validation on ALL content in the analyzed folder.

1. Create a todo list of all content to validate:
   - Find all JSON files in ./analyzed/Scripts/
   - Find all JSON files in ./analyzed/packages/
   - Track total count and types

2. For each content item, run these validations concurrently:
   - Use the Task tool to invoke syntax-validator agent for all platforms
   - Use the Task tool to invoke security-scanner agent for vulnerability scanning
   - Use the Task tool to invoke performance-analyzer agent for impact assessment
   - Use the Task tool to invoke compliance-enforcer agent for best practices
   - Use the Task tool to invoke quality-gatekeeper agent for final validation

3. Categorize findings by severity:
   - 🔴 CRITICAL: Security vulnerabilities, syntax errors
   - 🟠 HIGH: Performance issues, missing error handling
   - 🟡 MEDIUM: Best practice violations, incomplete docs
   - 🟢 LOW: Minor improvements, style suggestions

4. Generate validation summary:
   ```
   📊 VALIDATION SUMMARY
   ====================
   Total Content: X items (Y Scripts, Z packages)
   
   Status Overview:
   ✅ Passed: X items
   ⚠️ Warnings: Y items  
   ❌ Failed: Z items
   
   Issues by Severity:
   🔴 Critical: X issues
   🟠 High: Y issues
   🟡 Medium: Z issues
   🟢 Low: W issues
   
   Top Issues:
   1. Missing error handling (15 Scripts)
   2. Deprecated commands (8 Scripts)
   3. No input validation (5 packages)
   ```

5. Create actionable reports:
   - Full validation report in ./reports/validation-[date].md
   - Priority fix list for critical issues
   - Batch remediation suggestions

6. Update the database with validation status for each item.

This comprehensive validation helps ensure all content meets quality standards before deployment.