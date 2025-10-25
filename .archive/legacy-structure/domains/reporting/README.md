# Reporting Module

The Reporting module provides comprehensive reporting and visualization capabilities for the AitherZero platform.

## Features

### Real-time Dashboards
- **Execution Dashboard**: Monitor orchestration sequences in real-time
- **Auto-refresh**: Configurable refresh intervals
- **Metrics Display**: CPU, memory, disk usage monitoring
- **Progress Tracking**: Visual progress bars and status indicators

### Test Reporting
- **Multi-format Export**: HTML, Markdown, JSON, CSV
- **Comprehensive Coverage**: Test results, code coverage, static analysis
- **Trend Analysis**: Historical test performance tracking
- **Visual Reports**: Rich HTML reports with charts and metrics

### Metrics Collection
- **System Metrics**: CPU, memory, disk, network usage
- **Process Metrics**: PowerShell process resource consumption  
- **Custom Metrics**: Application-specific measurements
- **Performance Tracking**: Execution time and resource usage

### Report Types
- **Test Reports**: Detailed test execution results
- **Coverage Reports**: Code coverage visualization
- **Analysis Reports**: PSScriptAnalyzer findings
- **Metrics Reports**: System and application metrics
- **Trend Reports**: Historical performance analysis

## Usage

### Creating a Dashboard

```powershell
# Basic dashboard
$dashboard = New-ExecutionDashboard -Title "My Deployment" -AutoRefresh

# Detailed dashboard with metrics
$dashboard = New-ExecutionDashboard -Layout Detailed -ShowMetrics -ShowLogs

# Update dashboard
Update-ExecutionDashboard -Status @{
    Current = "Installing dependencies"
    Progress = 45
} -Progress @{
    Completed = 45
    Total = 100
    CurrentTask = "Installing Node.js"
}
```

### Generating Reports

```powershell
# Generate HTML test report
New-TestReport -Format HTML -IncludeTests -IncludeCoverage -IncludeAnalysis

# Generate trend analysis
Show-TestTrends -Days 30 -IncludeCoverage

# Export metrics
Export-MetricsReport -Format CSV -MetricTypes @('Tests', 'Coverage', 'Quality')
```

### Integration with Testing

```powershell
# After running tests
$testResult = Invoke-TestSuite -Profile Full -PassThru
$report = New-TestReport -Format HTML -TestResults $testResult -Title "CI Build #123"

# Open report
Start-Process $report
```

## Dashboard Components

### Status Panel
Shows current execution status with color-coded indicators:
- Green: Running/Success
- Yellow: Warning
- Red: Failed/Error

### Progress Bar
Visual representation of task completion with:
- Percentage complete
- Current/total items
- Current task description

### Metrics Grid
Real-time system metrics:
- CPU usage percentage
- Memory utilization
- Disk space usage
- Custom application metrics

### Log Viewer
Scrolling log display with:
- Configurable line limit
- Level-based coloring
- Auto-scroll capability

## Report Formats

### HTML Reports
- Rich formatting with CSS
- Interactive elements
- Charts and graphs (when data available)
- Responsive design

### Markdown Reports
- GitHub-compatible formatting
- Table support
- Easy to read in text editors
- Version control friendly

### JSON Reports
- Machine-readable format
- Complete data export
- Integration-friendly
- Preserves all metadata

### CSV Reports
- Excel-compatible
- Easy data analysis
- Simplified structure
- Time-series friendly

## Advanced Features

### Historical Analysis
Track metrics over time:
```powershell
# View test trends
Show-TestTrends -Days 90 -IncludeCoverage -IncludeAnalysis

# Export historical data
Export-MetricsReport -StartDate (Get-Date).AddMonths(-3) -Format JSON
```

### Custom Metrics
Add application-specific metrics:
```powershell
$metrics = Get-ExecutionMetrics -IncludeCustom
$metrics['DeploymentTime'] = $duration.TotalMinutes
Update-ExecutionDashboard -Metrics $metrics
```

### Report Aggregation
Combine multiple report sources:
```powershell
$testResults = Get-LatestTestResults
$coverage = Get-LatestCoverageData
$analysis = Get-LatestAnalysisResults

New-TestReport -Format HTML `
    -TestResults $testResults `
    -CoverageData $coverage `
    -AnalysisResults $analysis `
    -Title "Complete Quality Report"
```

## Configuration

Reports use configuration from `config.json`:
```json
{
  "Reporting": {
    "DefaultFormat": "HTML",
    "OutputPath": "./tests/reports",
    "RetentionDays": 30,
    "Dashboard": {
      "RefreshInterval": 5,
      "MaxLogLines": 50
    }
  }
}
```

## Best Practices

1. **Regular Reporting**: Generate reports after each test run
2. **Trend Monitoring**: Review trends weekly to catch regressions
3. **Metrics Baselines**: Establish performance baselines
4. **Report Archival**: Archive reports for compliance/history
5. **Dashboard Usage**: Use dashboards for long-running operations

## Integration Points

- **Testing Framework**: Automatic report generation after tests
- **Orchestration Engine**: Real-time dashboard updates
- **Logging Module**: Log aggregation in reports
- **CI/CD Pipeline**: Automated report publishing