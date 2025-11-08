# Enhanced Log Search & Health Dashboard - Implementation Plan

**Objective:** Add powerful log search capabilities and comprehensive health dashboard with multiple output formats  
**Timeline:** 2-3 days  
**Status:** 🟡 PLANNING  
**Priority:** HIGH - User-requested features

---

## Requirements from User Comments

### Comment 3493496117
> "also want the ability to search and view logs"

### Comment 3494145896
> "I also want the ability to easily search logs from 830 like transcripts, run logs. All of it. Also wanted to show like the health the ability to like show a health dashboard summary of course via text or or have it output the actual HTML report or whatever"

**Key Requirements:**
1. **Enhanced Log Search** - Search across ALL log types (transcripts, run logs, application logs)
2. **Easy Access** - Quick access from script 830 or similar
3. **Health Dashboard** - Show system health status
4. **Multiple Formats** - Text output AND HTML report options
5. **Comprehensive** - Cover all log sources

---

## Current State Analysis

### Existing Capabilities ✅

**Scripts:**
- **0530_View-Logs.ps1** - Log viewing with modes: Dashboard, Latest, Errors, Transcript, Search, Status
- **0550_Health-Dashboard.ps1** - Health monitoring with system checks
- **0512_Generate-Dashboard.ps1** - HTML/Markdown dashboard generation

**Modules:**
- **LogViewer.psm1** - `Get-LogFiles`, `Show-LogContent`, `Search-Logs`, `Get-LogStatistics`
- **Logging.psm1** - Core logging functionality
- **LoggingDashboard.psm1** - Dashboard utilities

### Current Search Capabilities
```powershell
# Existing search (basic)
./automation-scripts/0530_View-Logs.ps1 -Mode Search -SearchPattern "error"

# Features:
- Searches Application and Transcript logs
- Returns first 5 matching lines per file
- Simple pattern matching
```

### Current Health Dashboard
```powershell
# Existing health dashboard
./automation-scripts/0550_Health-Dashboard.ps1

# Features:
- PowerShell version check
- Module loading status
- Logging system check
- Test infrastructure check
- Text-based output only
```

### Gaps Identified ❌

1. **Limited Search Scope**
   - Only searches log files in `logs/` directory
   - Doesn't search run logs from orchestration
   - No search across test results
   - No search in archived logs

2. **Basic Search Features**
   - No regex support indication
   - No context lines (before/after match)
   - No date range filtering
   - No severity filtering
   - Limited to 5 results per file

3. **Health Dashboard Limitations**
   - Text-only output
   - No HTML report generation
   - Limited health metrics
   - No historical trend data
   - No alert thresholds

4. **No Unified Script 830**
   - User mentioned script "830" - doesn't exist yet
   - No single entry point for log operations

---

## Solution Design

### Feature 1: Enhanced Log Search (Script 0830)

Create `0830_Search-AllLogs.ps1` - Comprehensive log search utility

**Search Capabilities:**
```powershell
# Basic search
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "error"

# Advanced search with context
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "failed" -Context 3

# Search specific log types
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "test" -LogType Transcript

# Date range search
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "deploy" -After "2025-11-01"

# Regex search
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "ERROR|FATAL" -Regex

# Case-sensitive search
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "Failed" -CaseSensitive

# Export results
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "issue" -Export JSON
```

**Log Sources to Search:**
1. **Application Logs** - `logs/aitherzero-*.log`
2. **Transcript Logs** - `logs/transcript-*.log`
3. **Orchestration Logs** - Run logs from workflow executions
4. **Test Result Logs** - `tests/results/*.xml`, `tests/results/*.json`
5. **PSScriptAnalyzer Logs** - `tests/analysis/*.csv`
6. **CI/CD Logs** - GitHub Actions workflow logs (if available locally)
7. **Archived Logs** - Compressed/archived log files

**Parameters:**
```powershell
param(
    [Parameter(Mandatory)]
    [string]$Pattern,              # Search pattern (supports regex)
    
    [ValidateSet('All', 'Application', 'Transcript', 'Orchestration', 'Test', 'Analysis', 'Archived')]
    [string]$LogType = 'All',      # Type of logs to search
    
    [switch]$Regex,                # Treat pattern as regex
    [switch]$CaseSensitive,        # Case-sensitive search
    [int]$Context = 0,             # Lines of context (before/after)
    [int]$MaxResults = 100,        # Maximum results to return
    
    [datetime]$After,              # Search logs after this date
    [datetime]$Before,             # Search logs before this date
    
    [ValidateSet('Error', 'Warning', 'Information', 'Debug', 'Trace')]
    [string]$Severity,             # Filter by severity level
    
    [ValidateSet('Text', 'JSON', 'CSV', 'HTML')]
    [string]$Format = 'Text',      # Output format
    
    [string]$OutputFile,           # Save results to file
    [switch]$Interactive           # Interactive mode with menu
)
```

**Output Formats:**

**Text (Default):**
```
🔍 LOG SEARCH RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pattern: "error"
Log Types: All
Results: 42 matches across 7 files

📄 aitherzero-2025-11-05.log (15 matches)
───────────────────────────────────────────
2025-11-05 10:23:45 [ERROR] Failed to load module
  > Logging.psm1:234 - Module not found
2025-11-05 14:12:03 [ERROR] Connection timeout
  > OrchestrationEngine.psm1:567 - Remote host unreachable

📜 transcript-2025-11-05.log (8 matches)
───────────────────────────────────────────
...
```

**JSON:**
```json
{
  "search": {
    "pattern": "error",
    "logTypes": ["All"],
    "timestamp": "2025-11-05T20:00:00Z"
  },
  "summary": {
    "totalMatches": 42,
    "filesSearched": 7,
    "filesWithMatches": 3
  },
  "results": [
    {
      "file": "aitherzero-2025-11-05.log",
      "type": "Application",
      "matches": [
        {
          "lineNumber": 234,
          "timestamp": "2025-11-05T10:23:45Z",
          "severity": "ERROR",
          "message": "Failed to load module",
          "context": {
            "before": ["..."],
            "after": ["..."]
          }
        }
      ]
    }
  ]
}
```

### Feature 2: Unified Health Dashboard (Enhanced 0550)

Enhance existing `0550_Health-Dashboard.ps1` with multiple output formats

**Enhanced Capabilities:**
```powershell
# Text summary (existing)
./automation-scripts/0550_Health-Dashboard.ps1

# Detailed text report
./automation-scripts/0550_Health-Dashboard.ps1 -Detailed

# HTML report
./automation-scripts/0550_Health-Dashboard.ps1 -Format HTML -Open

# JSON export
./automation-scripts/0550_Health-Dashboard.ps1 -Format JSON -OutputFile health.json

# Check specific areas
./automation-scripts/0550_Health-Dashboard.ps1 -CheckType Infrastructure

# Include historical data
./automation-scripts/0550_Health-Dashboard.ps1 -IncludeHistory
```

**Health Metrics to Include:**

1. **System Health**
   - PowerShell version ✅ (exists)
   - Module loading status ✅ (exists)
   - Disk space available
   - Memory usage
   - CPU usage

2. **Logging System** ✅ (exists)
   - Log files present
   - Log rotation status
   - Logging module loaded
   - Recent error count

3. **Test Infrastructure** ✅ (exists)
   - Pester installed
   - Test directories present
   - Recent test results
   - Test pass rate

4. **Code Quality**
   - PSScriptAnalyzer status
   - Recent violations count
   - Code coverage percentage
   - Technical debt indicators

5. **CI/CD Health**
   - GitHub Actions status
   - Workflow success rate
   - Recent build status
   - Deployment status

6. **Security**
   - Security scan results
   - Known vulnerabilities
   - Certificate expiration warnings
   - Credential storage status

7. **Dependencies**
   - Required modules installed
   - Module versions
   - Update availability
   - Compatibility checks

**HTML Dashboard Layout:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Health Dashboard</title>
    <style>
        /* Modern dashboard styling */
        .health-card { border-left: 4px solid; padding: 20px; }
        .healthy { border-color: #28a745; }
        .warning { border-color: #ffc107; }
        .critical { border-color: #dc3545; }
    </style>
</head>
<body>
    <h1>🏥 AitherZero Health Dashboard</h1>
    <p>Generated: 2025-11-05 20:00:00</p>
    
    <!-- Overall Status -->
    <div class="health-card healthy">
        <h2>✅ Overall Status: Healthy</h2>
        <p>All systems operational</p>
    </div>
    
    <!-- System Metrics -->
    <div class="health-card">
        <h3>💻 System</h3>
        <ul>
            <li>PowerShell: 7.4.0 ✅</li>
            <li>Disk Space: 45.2 GB available ✅</li>
            <li>Memory: 8.5 GB / 16 GB (53%) ✅</li>
        </ul>
    </div>
    
    <!-- Code Quality -->
    <div class="health-card warning">
        <h3>📊 Code Quality</h3>
        <ul>
            <li>PSScriptAnalyzer: 12 warnings ⚠️</li>
            <li>Test Coverage: 87% ✅</li>
            <li>Tech Debt: Medium ⚠️</li>
        </ul>
    </div>
    
    <!-- Charts -->
    <div>
        <canvas id="testTrendChart"></canvas>
        <canvas id="errorRateChart"></canvas>
    </div>
    
    <!-- Recent Issues -->
    <div class="health-card">
        <h3>🔴 Recent Errors (Last 24h)</h3>
        <table>
            <tr><td>10:23 AM</td><td>Module load failure</td></tr>
            <tr><td>14:12 PM</td><td>Connection timeout</td></tr>
        </table>
    </div>
</body>
</html>
```

---

## Implementation Tasks

### Task 1: Create Script 0830 - Enhanced Log Search (8 hours)

**1.1 Create Script File** (1 hour)
```powershell
# File: automation-scripts/0830_Search-AllLogs.ps1
# Metadata: Stage: Issue Management, Dependencies: LogViewer
```

**1.2 Implement Core Search Logic** (3 hours)
```powershell
function Search-AllLogSources {
    param($Pattern, $LogType, $Options)
    
    # Search application logs
    $appResults = Search-ApplicationLogs @params
    
    # Search transcripts
    $transcriptResults = Search-TranscriptLogs @params
    
    # Search orchestration logs
    $orchestrationResults = Search-OrchestrationLogs @params
    
    # Search test results
    $testResults = Search-TestLogs @params
    
    # Search analysis results
    $analysisResults = Search-AnalysisLogs @params
    
    # Search archived logs
    if ($IncludeArchived) {
        $archivedResults = Search-ArchivedLogs @params
    }
    
    # Aggregate and sort results
    $allResults = @() + $appResults + $transcriptResults + 
                  $orchestrationResults + $testResults + 
                  $analysisResults + $archivedResults
    
    return $allResults | Sort-Object Timestamp -Descending
}
```

**1.3 Add Advanced Features** (2 hours)
- Regex support
- Context lines (before/after)
- Date range filtering
- Severity filtering
- Max results limiting

**1.4 Add Output Formats** (2 hours)
- Text (colored, formatted)
- JSON (structured data)
- CSV (for Excel)
- HTML (interactive)

**Files to Create/Modify:**
- ✨ NEW: `automation-scripts/0830_Search-AllLogs.ps1`
- 📝 UPDATE: `aithercore/utilities/LogViewer.psm1` (add advanced search functions)

### Task 2: Enhance Health Dashboard (6 hours)

**2.1 Add New Health Checks** (2 hours)
```powershell
function Get-ExtendedSystemHealth {
    # Existing checks (System, Modules, Logging, Tests)
    
    # NEW: Disk space check
    $diskHealth = Test-DiskSpace -WarnThresholdGB 10 -CriticalThresholdGB 5
    
    # NEW: Memory check
    $memoryHealth = Test-MemoryUsage -WarnThresholdPercent 80
    
    # NEW: Code quality check
    $codeQuality = Get-CodeQualityStatus
    
    # NEW: CI/CD health
    $cicdHealth = Get-CICDStatus
    
    # NEW: Security status
    $securityHealth = Get-SecurityStatus
    
    # NEW: Dependencies check
    $dependencyHealth = Test-Dependencies
    
    return @{
        System = $systemHealth
        Logging = $loggingHealth
        Tests = $testHealth
        CodeQuality = $codeQuality
        CICD = $cicdHealth
        Security = $securityHealth
        Dependencies = $dependencyHealth
    }
}
```

**2.2 Add HTML Report Generation** (3 hours)
```powershell
function New-HTMLHealthDashboard {
    param(
        [hashtable]$HealthData,
        [string]$OutputPath
    )
    
    # Generate HTML with:
    # - Bootstrap/Tailwind CSS
    # - Chart.js for graphs
    # - Responsive layout
    # - Auto-refresh capability
    # - Export to PDF option
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Health Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <!-- Dashboard content -->
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
}
```

**2.3 Add Multiple Format Support** (1 hour)
- Text (enhanced, colored)
- HTML (interactive dashboard)
- JSON (machine-readable)
- Markdown (documentation-friendly)

**Files to Modify:**
- 📝 UPDATE: `automation-scripts/0550_Health-Dashboard.ps1`
- 📝 UPDATE: `aithercore/utilities/LoggingDashboard.psm1` (add helpers)

### Task 3: Integration & Testing (3 hours)

**3.1 Add to Unified Menu** (1 hour)
```powershell
# Update UnifiedMenu.psm1 to include:
- "Search Logs" option (calls 0830)
- "Health Dashboard" option (calls 0550)
```

**3.2 Add to CLIHelper Shortcuts** (30 minutes)
```powershell
# Add shortcuts:
$script:CLIState.Aliases['search-logs'] = @{ 
    Mode = 'Run'; Target = '0830' 
}
$script:CLIState.Aliases['health'] = @{ 
    Mode = 'Run'; Target = '0550' 
}
```

**3.3 Create Tests** (1.5 hours)
```powershell
# tests/unit/automation-scripts/0800-0899/0830_Search-AllLogs.Tests.ps1
Describe "0830_Search-AllLogs" {
    It "Should search application logs" { }
    It "Should search transcript logs" { }
    It "Should support regex patterns" { }
    It "Should filter by date range" { }
    It "Should export to JSON" { }
}

# tests/unit/automation-scripts/0500-0599/0550_Health-Dashboard.Tests.ps1
Describe "0550_Health-Dashboard Enhancements" {
    It "Should generate HTML report" { }
    It "Should export to JSON" { }
    It "Should include all health checks" { }
}
```

### Task 4: Documentation (2 hours)

**4.1 Create Usage Guides** (1 hour)
- **docs/LOG-SEARCH-GUIDE.md** - Comprehensive search guide
- **docs/HEALTH-DASHBOARD-GUIDE.md** - Dashboard usage

**4.2 Update Existing Docs** (1 hour)
- Update `CLI-QOL-ANALYSIS.md` to include these features
- Update `DOCUMENTATION-INDEX.md`
- Update `.github/copilot-instructions.md`

---

## Configuration Updates

### config.psd1 Additions
```powershell
Experience = @{
    # ... existing settings ...
    
    # NEW: Log Search Settings
    LogSearch = @{
        Enabled = $true
        MaxResults = 100
        DefaultContext = 2  # Lines before/after match
        SearchArchived = $false  # Include archived logs
        IncludeTestLogs = $true
        IncludeAnalysisLogs = $true
    }
    
    # NEW: Health Dashboard Settings
    HealthDashboard = @{
        Enabled = $true
        AutoRefresh = $false
        RefreshIntervalSeconds = 60
        DefaultFormat = 'Text'  # Text, HTML, JSON
        IncludeHistorical = $true
        HistoryDays = 7
        Thresholds = @{
            DiskSpaceWarnGB = 10
            DiskSpaceCriticalGB = 5
            MemoryWarnPercent = 80
            MemoryCriticalPercent = 90
        }
    }
}
```

---

## Timeline

### Day 1: Log Search Implementation
- Morning: Create 0830 script structure (2h)
- Afternoon: Implement core search logic (3h)
- Evening: Add advanced features (3h)

### Day 2: Health Dashboard Enhancement
- Morning: Add new health checks (3h)
- Afternoon: HTML report generation (3h)
- Evening: Multiple format support (2h)

### Day 3: Integration & Testing
- Morning: Menu integration + shortcuts (1.5h)
- Afternoon: Create tests (1.5h)
- Late Afternoon: Documentation (2h)
- Evening: Final testing & validation (2h)

**Total Effort: 19-21 hours (2.5-3 days)**

---

## Success Criteria

### Functional Requirements
- [ ] Search across ALL log types (app, transcript, orchestration, test, analysis)
- [ ] Support regex, case-sensitive, date range, severity filtering
- [ ] Context lines (before/after match)
- [ ] Export to JSON, CSV, HTML
- [ ] Health dashboard with text AND HTML output
- [ ] Comprehensive health metrics (7+ categories)
- [ ] Charts and visualizations in HTML
- [ ] Auto-refresh capability

### Performance Requirements
- [ ] Search completes in < 5s for typical log volume (100MB)
- [ ] HTML dashboard generates in < 2s
- [ ] Dashboard loads in browser in < 1s

### User Experience
- [ ] Intuitive command-line interface
- [ ] Clear, actionable output
- [ ] Helpful error messages
- [ ] Quick access from menu (1-2 clicks)
- [ ] Shortcuts work (`search-logs`, `health`)

---

## Examples

### Log Search Examples
```powershell
# Quick error search
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "error"

# Find failed tests in last 24 hours
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "failed.*test" -Regex -After (Get-Date).AddDays(-1) -LogType Test

# Search transcripts for specific command
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "Invoke-Pester" -LogType Transcript -Context 5

# Export deployment issues to JSON
./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "deploy" -Severity Error -Format JSON -OutputFile deploy-issues.json

# Interactive search
./automation-scripts/0830_Search-AllLogs.ps1 -Interactive
```

### Health Dashboard Examples
```powershell
# Quick health check
./automation-scripts/0550_Health-Dashboard.ps1

# Detailed text report
./automation-scripts/0550_Health-Dashboard.ps1 -Detailed

# Generate HTML dashboard
./automation-scripts/0550_Health-Dashboard.ps1 -Format HTML -Open

# Check infrastructure health
./automation-scripts/0550_Health-Dashboard.ps1 -CheckType Infrastructure

# Export health data
./automation-scripts/0550_Health-Dashboard.ps1 -Format JSON -OutputFile health-$(Get-Date -Format 'yyyyMMdd').json

# CI/CD integration
./automation-scripts/0550_Health-Dashboard.ps1 -NonInteractive -Format JSON
```

---

## Risk Assessment

### Low Risk
- Log search enhancements (extends existing functionality)
- Text-based health dashboard (already exists)
- New shortcuts/aliases (additive)

### Medium Risk
- HTML dashboard generation (new rendering logic)
- Multiple log source integration (complexity)

### High Risk
- None identified

### Mitigation
- Feature flags in config.psd1
- Backwards compatibility maintained
- Comprehensive testing
- Gradual rollout

---

## Future Enhancements (Phase 2)

1. **Real-time Log Monitoring**
   - Live log streaming dashboard
   - Alert notifications
   - Anomaly detection

2. **Advanced Search**
   - Full-text search index (Lucene/Elasticsearch)
   - Search across Git history
   - AI-powered log analysis

3. **Health Dashboard**
   - Historical trend analysis
   - Predictive alerts (ML-based)
   - Integration with external monitoring (Prometheus, Grafana)
   - Mobile-responsive design
   - Dark mode support

4. **Export & Sharing**
   - Email health reports
   - Slack/Teams integration
   - PDF export
   - Scheduled report generation

---

## Conclusion

This implementation plan delivers:
- ✅ **Enhanced log search** across all sources with advanced filtering
- ✅ **Comprehensive health dashboard** with text AND HTML formats
- ✅ **Easy access** via script 0830 and shortcuts
- ✅ **User-friendly** with intuitive CLI and visual dashboards
- ✅ **Extensible** architecture for future enhancements

**Estimated Impact:**
- **Time Saved:** 50-70% reduction in log troubleshooting time
- **Visibility:** Complete system health at a glance
- **Productivity:** Quick access to critical information

**Next Steps:**
1. Review and approve plan
2. Create GitHub issue for tracking
3. Begin implementation (Day 1: Log Search)

---

**Status:** 📋 READY FOR IMPLEMENTATION  
**Priority:** HIGH (User-requested)  
**Effort:** 2.5-3 days  
**Value:** Very High (Core operational capabilities)
