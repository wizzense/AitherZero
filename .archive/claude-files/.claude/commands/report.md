---
allowed-tools: Read, Glob, Write, Bash
description: Generate comprehensive management report
---

## Your Task

Generate an executive-level report on the current state of Aitherium content.

1. Gather statistics from the database and file system:
   - Total content items by type
   - Validation status distribution
   - Platform coverage analysis
   - Category breakdown

2. Analyze trends:
   - New content added this week/month
   - Issues fixed vs discovered
   - Most common problem areas
   - Duplicate content identified

3. Create comprehensive report with these sections:

   ```markdown
   # Aitherium Content Management Report
   Generated: [Current Date]
   
   ## Executive Summary
   - Total managed content: X items
   - Overall health score: Y%
   - Critical issues requiring attention: Z
   
   ## Content Inventory
   ### By Type
   - Scripts: X (Y% of total)
   - Packages: Z (W% of total)
   
   ### By Platform
   - Windows: X items
   - Linux: Y items
   - Cross-platform: Z items
   
   ### By Category
   - System Information: X
   - Security: Y
   - Performance: Z
   
   ## Quality Metrics
   ### Validation Results
   - Fully validated: X%
   - Passed with warnings: Y%
   - Failed validation: Z%
   
   ### Common Issues
   1. Missing error handling (X occurrences)
   2. Security vulnerabilities (Y occurrences)
   3. Performance concerns (Z occurrences)
   
   ## Recommendations
   1. Priority fixes for critical issues
   2. Standardization opportunities
   3. Training needs identified
   
   ## Progress Tracking
   - Issues resolved this period: X
   - New content added: Y
   - Duplicate content eliminated: Z
   ```

4. Generate visualizations (using text-based charts):
   - Content distribution pie chart
   - Validation status bar graph
   - Trend lines for issues over time

5. Save outputs:
   - Full report to ./reports/management-report-[date].md
   - Executive summary to ./reports/executive-summary-[date].md
   - Raw data export to ./reports/data-export-[date].json

6. Highlight key achievements and areas needing attention.

This report provides leadership visibility into content quality and standardization progress.