@{
    Name = "dashboard-generation-complete"
    Description = "Complete dashboard generation with parallel metrics collection"
    Version = "1.0.0"
    
    Variables = @{
        OutputDir = "reports/dashboard"
        MetricsDir = "reports/metrics"
    }
    
    Sequence = @(
        # Collect ring metrics
        @{
            Script = "0520"
            Description = "Collect ring deployment metrics"
            Parameters = @{
                OutputDir = "reports/metrics"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect workflow health metrics
        @{
            Script = "0521"
            Description = "Collect workflow health metrics"
            Parameters = @{
                OutputDir = "reports/metrics"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect code metrics
        @{
            Script = "0522"
            Description = "Collect code quality metrics"
            Parameters = @{
                OutputDir = "reports/metrics"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect test metrics
        @{
            Script = "0523"
            Description = "Collect test result metrics"
            Parameters = @{
                OutputDir = "reports/metrics"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect quality metrics
        @{
            Script = "0524"
            Description = "Collect quality analysis metrics"
            Parameters = @{
                OutputDir = "reports/metrics"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Generate dashboard HTML from collected metrics
        @{
            Script = "0525"
            Description = "Generate HTML dashboard from collected metrics"
            Parameters = @{
                OutputDir = "reports/dashboard"
                MetricsDir = "reports/metrics"
            }
            ContinueOnError = $false
            Timeout = 120
        }
    )
    
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $false
        CaptureOutput = $true
    }
    
    Metadata = @{
        Author = "AitherZero Team"
        Created = "2025-01-10"
        Tags = @("dashboard", "reporting", "metrics", "visualization")
        EstimatedDuration = "300s"
    }
}
