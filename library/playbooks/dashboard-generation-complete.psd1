@{
    Name = "dashboard-generation-complete"
    Description = "Complete dashboard generation with parallel metrics collection"
    Version = "1.0.0"
    
    Variables = @{
        OutputDir = "reports/dashboard"
        MetricsDir = "reports/metrics"
    }
    
    Sequence = @(
        @{
            Name = "collect-metrics"
            Description = "Collect all metrics in parallel"
            Scripts = @(
                @{ Number = "0520"; AllowParallel = $true }  # Ring metrics
                @{ Number = "0521"; AllowParallel = $true }  # Workflow health
                @{ Number = "0522"; AllowParallel = $true }  # Code metrics
                @{ Number = "0523"; AllowParallel = $true }  # Test metrics
                @{ Number = "0524"; AllowParallel = $true }  # Quality metrics
            )
            ContinueOnError = $true
            MaxParallel = 5
        }
        @{
            Name = "generate-dashboard"
            Description = "Generate HTML dashboard from collected metrics"
            Scripts = @(
                @{ Number = "0525"; AllowParallel = $false }  # Generate dashboard HTML
            )
            DependsOn = @("collect-metrics")
        }
    )
    
    Metadata = @{
        Author = "AitherZero Team"
        Created = "2025-01-10"
        Tags = @("dashboard", "reporting", "metrics", "visualization")
        EstimatedDuration = "120s"
    }
}
