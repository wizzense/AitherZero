@{
    Name = 'report-dashboard'
    Description = 'Generate executive dashboard with all metrics'
    Version = '1.0.0'
    Author = 'AitherZero Reporting System'
    
    Stages = @(
        @{
            Name = 'CollectMetrics'
            Description = 'Collect all metrics'
            Sequence = @('0501', '0406')  # System info, test coverage
            ContinueOnError = $true
            Parallel = $true
        }
        @{
            Name = 'AnalyzeData'
            Description = 'Analyze collected data'
            Sequence = @('0520', '0522', '0524')  # Config usage, code quality, tech debt
            ContinueOnError = $true
            Parallel = $true
        }
        @{
            Name = 'GenerateReports'
            Description = 'Generate all reports'
            Sequence = @('0510', '0511')  # Project report, dashboard
            ContinueOnError = $false
        }
        @{
            Name = 'PublishReports'
            Description = 'Publish reports'
            Sequence = @('0450')  # Publish test results
            ContinueOnError = $true
        }
    )
    
    Variables = @{
        ReportFormat = 'HTML'
        IncludeCharts = $true
        TimePeriod = '7days'
        OutputPath = './reports/dashboard'
        Metrics = @(
            'TestCoverage'
            'CodeQuality'
            'Performance'
            'Security'
            'TechnicalDebt'
            'Documentation'
        )
    }
    
    Schedule = @{
        Frequency = 'Weekly'
        DayOfWeek = 'Monday'
        Time = '09:00'
    }
}