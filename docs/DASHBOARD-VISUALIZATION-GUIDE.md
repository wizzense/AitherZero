# Dashboard Visualization Guide

## Quick Reference: What Each Visualization Shows

### 1. Quality Trends Line Chart 📈
**Location:** Enhanced Visualizations section, top-left  
**Data Source:** `$HistoricalMetrics.TestTrends`  
**Type:** Line chart with gradient fill  

**What it shows:**
- Quality score progression over last 10 snapshots
- Upward trend = improving quality
- Downward trend = degrading quality
- Flat line = stable quality

**Fallback:** Shows "No historical data available yet" message if fewer than 2 data points

---

### 2. Test Results Distribution 🧪
**Location:** Enhanced Visualizations section, top-right  
**Data Source:** `$Metrics.Tests.{Passed, Failed, Skipped}`  
**Type:** Doughnut chart  

**What it shows:**
- Green slice = Passed tests
- Red slice = Failed tests  
- Yellow slice = Skipped tests

**Interactive:** Hover shows exact count and percentage  
**Fallback:** Shows "No test results available" if no tests run

---

### 3. PSScriptAnalyzer Issues 🔬
**Location:** Enhanced Visualizations section, bottom-left  
**Data Source:** `$PSScriptAnalyzerMetrics.{Errors, Warnings, Information}`  
**Type:** Vertical bar chart  

**What it shows:**
- Red bar = Error severity issues (critical)
- Yellow bar = Warning severity issues (important)
- Blue bar = Information severity issues (minor)

**Target:** All bars should be as low as possible  
**Fallback:** Shows "✅ No PSScriptAnalyzer issues found!" when clean

---

### 4. Code Coverage Breakdown 📏
**Location:** Enhanced Visualizations section, bottom-right  
**Data Source:** `$Metrics.Coverage.{CoveredLines, TotalLines}`  
**Type:** Stacked horizontal bar  

**What it shows:**
- Green segment = Lines covered by tests
- Red segment = Lines not covered by tests

**Target:** Green should be 80%+ of total  
**Fallback:** Shows message to run tests with coverage if no data

---

### 5. File Quality Heatmap 🗺️
**Location:** Below the 4-chart grid  
**Data Source:** `$FileMetrics.Files` (worst 50 files)  
**Type:** Interactive grid  

**What it shows:**
- Each cell = one file
- Cell background = gradient based on score
  - Green (90-100) = High quality
  - Yellow (70-89) = Moderate quality
  - Orange (50-69) = Needs improvement
  - Red (0-49) = Critical issues
- File name and score displayed in cell
- Domain shown below file name

**Interactive:** Click cell to see file details  
**Purpose:** Quickly identify which files need the most attention

---

### 6. Embedded Code Map 🗺️
**Location:** Below the heatmap  
**Data Source:** Existing code-map.html  
**Type:** iframe embed with D3.js visualization  

**What it shows:**
- Complete codebase structure
- File relationships and dependencies
- Interactive exploration of code organization

**Actions:**
- Zoom/pan within iframe
- Click "Open in New Window" for full-screen experience
- Explore file tree and dependency graph

---

## Dashboard Sections Overview

```
┌─────────────────────────────────────────────────────────┐
│  Header: Project name, stats, last updated              │
├─────────────────────────────────────────────────────────┤
│  Quick Actions: Buttons for common tasks                │
├─────────────────────────────────────────────────────────┤
│  Project Metrics: File counts, LOC, functions           │
├─────────────────────────────────────────────────────────┤
│  Build Status: Overall health indicators                │
├─────────────────────────────────────────────────────────┤
│  Test Results: Detailed test execution stats            │
├─────────────────────────────────────────────────────────┤
│  Quality Drilldown: File-level quality details          │
├─────────────────────────────────────────────────────────┤
│  Code Quality Validation: Validation results            │
├─────────────────────────────────────────────────────────┤
│  PSScriptAnalyzer: Static analysis results              │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📊 ENHANCED VISUALIZATIONS (NEW!)                   │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ ┌──────────────────┬──────────────────┐            │ │
│ │ │ Quality Trends   │ Test Distribution │            │ │
│ │ │ (Line Chart)     │ (Doughnut)        │            │ │
│ │ ├──────────────────┼──────────────────┤            │ │
│ │ │ PSSA Issues      │ Code Coverage    │            │ │
│ │ │ (Bar Chart)      │ (Stacked Bar)    │            │ │
│ │ └──────────────────┴──────────────────┘            │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────┐   │ │
│ │ │ File Quality Heatmap                         │   │ │
│ │ │ (Interactive grid - click for details)       │   │ │
│ │ └─────────────────────────────────────────────┘   │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────┐   │ │
│ │ │ Embedded Code Map (iframe with D3.js)       │   │ │
│ │ │ [Open in New Window] button                  │   │ │
│ │ └─────────────────────────────────────────────┘   │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│  Project Health: Build, Tests, Quality badges           │
├─────────────────────────────────────────────────────────┤
│  Git Repository: Branch, commits, contributors          │
├─────────────────────────────────────────────────────────┤
│  Dependency Mapping: Config.psd1 dependencies           │
├─────────────────────────────────────────────────────────┤
│  Configuration Explorer: Interactive config browser     │
└─────────────────────────────────────────────────────────┘
```

---

## Color Coding Legend

### Quality Scores
- 🟢 **Green (90-100):** Excellent quality
- 🟡 **Yellow (70-89):** Good quality  
- 🟠 **Orange (50-69):** Needs improvement
- 🔴 **Red (0-49):** Critical issues

### Test Results
- 🟢 **Green:** Passed tests
- 🔴 **Red:** Failed tests
- 🟡 **Yellow:** Skipped tests

### Issue Severity
- 🔴 **Red:** Errors (must fix)
- 🟡 **Yellow:** Warnings (should fix)
- 🔵 **Blue:** Information (nice to fix)

---

## How to Generate

```powershell
# Generate complete dashboard with all visualizations
./az 0512

# Or use the full path
./library/automation-scripts/0512_Generate-Dashboard.ps1

# Specify format (HTML is default)
./library/automation-scripts/0512_Generate-Dashboard.ps1 -Format HTML

# Output location
# Default: reports/dashboard.html
```

---

## Browser Compatibility

| Browser | Status | Notes |
|---------|--------|-------|
| Chrome 90+ | ✅ Full support | Recommended |
| Edge 90+ | ✅ Full support | Chromium-based |
| Firefox 88+ | ✅ Full support | All features work |
| Safari 14+ | ✅ Full support | macOS/iOS |
| Mobile browsers | ✅ Responsive | Charts adapt to screen |

---

## Performance

### Dashboard Generation Time
- **Average:** 70-90 seconds
- **Main steps:**
  - File analysis: ~60 seconds
  - Metrics collection: ~10 seconds
  - HTML generation: ~5 seconds
  - Chart data preparation: ~5 seconds

### Page Load Time
- **Initial load:** < 2 seconds
- **Chart rendering:** < 1 second
- **Total interactive:** < 3 seconds

### Data Limits
- **File heatmap:** 50 files maximum (prevents slowdown)
- **Quality trends:** 10 most recent snapshots
- **Historical data:** Unlimited (stored in reports/metrics-history/)

---

## Troubleshooting

### Charts Don't Appear
1. Check browser console for JavaScript errors
2. Verify Chart.js CDN loaded successfully
3. Ensure data is available (run tests, analysis)
4. Try hard refresh (Ctrl+F5 / Cmd+Shift+R)

### "No data available" Messages
- **Quality Trends:** Run dashboard multiple times to accumulate data
- **Test Results:** Run `./az 0402` to generate test data
- **Coverage:** Run tests with coverage enabled
- **PSSA Issues:** Run `./az 0404` for static analysis

### Heatmap Shows No Files
- Verify file metrics collection ran successfully
- Check that PSScriptAnalyzer is installed
- Ensure files are in expected directories

---

## Tips & Best Practices

### Daily Usage
1. Generate dashboard after major changes
2. Review trends weekly to track improvement
3. Use heatmap to prioritize refactoring
4. Check test distribution before merging PRs

### CI/CD Integration
1. Generate dashboard in workflows
2. Publish as artifact for history
3. Archive metrics-history/ snapshots
4. Set quality gates based on chart thresholds

### Team Collaboration
1. Share dashboard URL in team channels
2. Review in stand-ups for quick status
3. Use in retrospectives to show progress
4. Celebrate improvements when charts go green!

---

## What's Next?

The dashboard is now production-ready with world-class visualizations. Future enhancements could include:

- Real-time data updates
- Chart export functionality  
- Custom filtering and search
- Comparative views
- Predictive analytics
- AI-powered insights

---

**Questions?** Check [DASHBOARD-ENHANCEMENT-SUMMARY.md](DASHBOARD-ENHANCEMENT-SUMMARY.md) for complete technical documentation.

**Feedback?** Open an issue or PR with suggestions for improvement!
