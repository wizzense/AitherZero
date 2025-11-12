@{
    Name = "dashboard"
    Description = "Dashboard generation with sequential metrics collection"
    Version = "1.0.0"
    
    Variables = @{
        OutputDir = "library/reports/dashboard"
        MetricsDir = "library/reports/metrics"
    }
    
    # Common configuration for all metrics collection scripts (0520-0524)
    # ContinueOnError=$true: Allow dashboard generation even if individual metric collection fails
    # Timeout=60: Each collection script has 60 seconds to complete
    # These are identical because all metrics are equally important but non-critical
    
    Sequence = @(
        # Collect ring metrics
        @{
            Script = "0520"
            Description = "Collect ring deployment metrics"
            Parameters = @{
                OutputPath = "library/reports/metrics/ring-metrics.json"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect workflow health metrics
        @{
            Script = "0521"
            Description = "Collect workflow health metrics"
            Parameters = @{
                OutputPath = "library/reports/metrics/workflow-health.json"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect code metrics
        @{
            Script = "0522"
            Description = "Collect code quality metrics"
            Parameters = @{
                OutputPath = "library/reports/metrics/code-metrics.json"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect test metrics
        @{
            Script = "0523"
            Description = "Collect test result metrics"
            Parameters = @{
                OutputPath = "library/reports/metrics/test-metrics.json"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Collect quality metrics
        @{
            Script = "0524"
            Description = "Collect quality analysis metrics"
            Parameters = @{
                OutputPath = "library/reports/metrics/quality-metrics.json"
            }
            ContinueOnError = $true
            Timeout = 60
        },
        
        # Generate dashboard HTML from collected metrics
        @{
            Script = "0525"
            Description = "Generate HTML dashboard from collected metrics"
            Parameters = @{
                OutputPath = "library/reports/dashboard/index.html"
                MetricsPath = "library/reports/metrics"
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
        # Worst-case: 5 collection scripts × 60s + 1 dashboard script × 120s = 420s
        # Adding buffer for execution overhead brings total to 450s
        EstimatedDuration = "450s"
    }
}
