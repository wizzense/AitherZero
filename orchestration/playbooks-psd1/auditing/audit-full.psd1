@{
    Name = 'audit-full'
    Description = 'Complete audit of codebase, dependencies, and security'
    Version = '1.0.0'
    Author = 'AitherZero Audit System'
    
    Stages = @(
        @{
            Name = 'CodeQuality'
            Description = 'Code quality audit'
            Sequence = @('0404', '0522')  # PSScriptAnalyzer, analyze code quality
            ContinueOnError = $true
            Timeout = 300
        }
        @{
            Name = 'Security'
            Description = 'Security vulnerability scan'
            Sequence = @('0523', '0735')  # Security analysis, AI security scan
            ContinueOnError = $true
            Timeout = 600
        }
        @{
            Name = 'Dependencies'
            Description = 'Dependency audit'
            Sequence = @('0520')  # Analyze configuration usage
            ContinueOnError = $true
            Timeout = 180
        }
        @{
            Name = 'Documentation'
            Description = 'Documentation coverage audit'
            Sequence = @('0521')  # Analyze documentation coverage
            ContinueOnError = $true
            Timeout = 180
        }
        @{
            Name = 'TechnicalDebt'
            Description = 'Technical debt assessment'
            Sequence = @('0524')  # Generate tech debt report
            ContinueOnError = $true
            Timeout = 300
        }
        @{
            Name = 'Report'
            Description = 'Generate audit report'
            Sequence = @('0510')  # Generate project report
            ContinueOnError = $false
            Timeout = 120
        }
    )
    
    Variables = @{
        OutputPath = './audit-reports'
        GenerateHTML = $true
        SendNotifications = $false
        FailThreshold = 0.8  # 80% pass rate required
    }
    
    PostActions = @{
        CreateGitHubIssues = $true
        UpdateDashboard = $true
        SendReport = $false
    }
}