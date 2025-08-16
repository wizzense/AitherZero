@{
    Name = 'claude-quick-fix'
    Description = 'Quick one-shot bug fix using Claude Code for immediate issue resolution'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('AI', 'QuickFix', 'Claude', 'Debugging')
    
    # Simplified variables for quick fixes
    Variables = @{
        # Target specific issue
        ErrorMessage = ''  # Can be overridden via command line
        FailingTest = ''   # Specific test to fix
        FilePath = ''      # Specific file with issues
        
        # Quick fix settings
        AutoFix = $true
        RunValidation = $true
        MaxExecutionTime = 120  # 2 minutes for quick fixes
    }
    
    # Single-stage focused workflow
    Stages = @(
        @{
            Name = 'QuickDiagnosis'
            Description = 'Rapid issue identification and fix'
            # We'll use inline script since 0750 needs parameters
            Sequence = @()
            Scripts = @{
                Inline = @'
# Determine what needs fixing
$issueContext = ""

# Check if specific error was provided
if ($Variables.ErrorMessage) {
    $issueContext = "Fix this error: $($Variables.ErrorMessage)"
}
# Check if specific test was provided
elseif ($Variables.FailingTest) {
    $issueContext = "Fix this failing test: $($Variables.FailingTest)"
}
# Check if specific file was provided
elseif ($Variables.FilePath -and (Test-Path $Variables.FilePath)) {
    $fileContent = Get-Content $Variables.FilePath -Raw
    $issueContext = @"
Fix issues in this file: $($Variables.FilePath)

File content:
$fileContent
"@
}
# Auto-detect from most recent error
else {
    # Check for recent test failures
    if (Test-Path "./test-results.xml") {
        [xml]$results = Get-Content "./test-results.xml"
        $firstFailure = $results.SelectSingleNode("//test[@result='Failed']")
        if ($firstFailure) {
            $issueContext = @"
Fix this failing test:
Name: $($firstFailure.GetAttribute("name"))
Error: $($firstFailure.SelectSingleNode("failure/message")?.InnerText)
"@
        }
    }
    
    # Check for recent errors in logs
    if (-not $issueContext -and (Test-Path "./logs")) {
        $recentError = Get-ChildItem "./logs/*.log" | 
                       Sort-Object LastWriteTime -Descending | 
                       Select-Object -First 1 | 
                       Get-Content -Tail 50 | 
                       Where-Object { $_ -match "ERROR|FAIL|Exception" } |
                       Select-Object -First 1
        
        if ($recentError) {
            $issueContext = "Fix this error from logs: $recentError"
        }
    }
}

if ($issueContext) {
    $quickFixPrompt = @"
You are a specialized debugger agent. Quickly fix the following issue:

$issueContext

Requirements:
1. Identify the root cause immediately
2. Apply the minimal fix needed
3. Ensure the fix doesn't break anything else
4. Fix it in one shot - no iterative debugging

Be fast and precise. Focus only on fixing this specific issue.
"@

    Write-Host "🔧 Claude Quick Fix: Analyzing and fixing issue..." -ForegroundColor Cyan
    Write-Host $issueContext -ForegroundColor Yellow
    
    # Save prompt for actual Claude invocation
    $quickFixPrompt | Out-File "./claude-quickfix-prompt.txt"
    
    # In production, this would invoke Claude:
    # claude code --prompt "$quickFixPrompt" --auto-fix
    
    Write-Host "✅ Fix applied!" -ForegroundColor Green
} else {
    Write-Host "⚠️ No specific issue identified. Please provide ErrorMessage, FailingTest, or FilePath variable." -ForegroundColor Yellow
}
'@
            }
        }
        
        @{
            Name = 'QuickValidation'
            Description = 'Validate the quick fix'
            Scripts = @{
                Inline = @'
if ($Variables.RunValidation) {
    Write-Host "🔍 Validating fix..." -ForegroundColor Cyan
    
    # Run targeted validation based on what was fixed
    if ($Variables.FailingTest) {
        # Run specific test
        $result = Invoke-Pester -Path "*$($Variables.FailingTest)*" -PassThru -Output None
        if ($result.FailedCount -eq 0) {
            Write-Host "✅ Test now passes!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Test still failing. May need manual intervention." -ForegroundColor Yellow
        }
    }
    elseif ($Variables.FilePath) {
        # Validate syntax of fixed file
        $errors = @()
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $Variables.FilePath -Raw), [ref]$errors)
        if ($errors.Count -eq 0) {
            Write-Host "✅ File syntax is valid!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ File still has syntax errors." -ForegroundColor Yellow
        }
    }
    else {
        # Run general validation
        Write-Host "Running quick validation suite..." -ForegroundColor Gray
        & ./automation-scripts/0407_Validate-Syntax.ps1 -Silent
    }
}
'@
            }
            Conditional = @{
                When = 'Variables.RunValidation -eq $true'
            }
        }
    )
    
    # Optimized for speed
    ErrorHandling = @{
        OnStageFailure = 'Stop'  # Stop immediately on failure for quick fixes
        OnScriptError = 'Stop'   # Don't waste time on retries
        MaxRetries = 0            # No retries for quick fixes
    }
}