#Requires -Version 7.0

<#
.SYNOPSIS
    Install and manage Git pre-commit hooks for PowerShell script validation

.DESCRIPTION
    Provides functions to install, remove, and test Git pre-commit hooks that validate
    PowerShell scripts before they are committed to the repository. Integrates with
    the project's PatchManager and validation workflows.

.NOTES
    Part of the DevEnvironment module for OpenTofu Lab Automation
#>

function Install-PreCommitHook {
    <#
    .SYNOPSIS
        Install Git pre-commit hook for PowerShell validation
    
    .DESCRIPTION
        Installs a Git pre-commit hook that validates PowerShell scripts using
        PatchManager and project validation standards before allowing commits.
    
    .PARAMETER Force
        Overwrite existing pre-commit hook if present
    
    .EXAMPLE
        Install-PreCommitHook
        Install-PreCommitHook -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )

    try {
        Write-CustomLog "Installing Git pre-commit hook..." -Level "INFO"
        
        $gitHooksDir = ".git/hooks"
        $preCommitPath = "$gitHooksDir/pre-commit"
        
        # Validate we're in a Git repository
        if (-not (Test-Path $gitHooksDir)) {
            throw "Not in a Git repository root directory. Run this from the repository root."
        }
        
        # Check for existing hook
        if ((Test-Path $preCommitPath) -and -not $Force) {
            Write-CustomLog "Pre-commit hook already exists. Use -Force to overwrite." -Level "WARN"
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess($preCommitPath, "Install pre-commit hook")) {
            $hookContent = Get-PreCommitHookContent
            Set-Content -Path $preCommitPath -Value $hookContent -NoNewline -Encoding UTF8
            
            # Install the comprehensive hook
            $hookPath = ".git/hooks/pre-commit"
            
            if (-not (Test-Path ".git")) {
                throw "Not in a Git repository. Pre-commit hook can only be installed in Git repositories."
            }
            
            # Create hooks directory if it doesn't exist
            $hooksDir = Split-Path $hookPath -Parent
            if (-not (Test-Path $hooksDir)) {
                if (-not (Test-Path $hooksDir)) { New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null }
            }
            
            # Write the hook content
            Set-Content -Path $hookPath -Value $fullHookContent -Encoding UTF8
            
            # Make executable on Unix systems
            if ($IsLinux -or $IsMacOS) {
                chmod +x $hookPath
            }
            
            Write-CustomLog "Pre-commit hook installed successfully at $hookPath" -Level SUCCESS
            Write-CustomLog "Hook includes: emoji prevention, PowerShell syntax validation" -Level INFO
            
            return @{
                Success = $true
                HookPath = $hookPath
                Features = @("Emoji Prevention", "PowerShell Syntax Validation")
            }
        }
    }
    catch {
        Write-CustomLog "Failed to install pre-commit hook: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Remove-PreCommitHook {
    <#
    .SYNOPSIS
        Remove Git pre-commit hook
    
    .DESCRIPTION
        Removes the Git pre-commit hook for PowerShell validation if it exists.
    
    .EXAMPLE
        Remove-PreCommitHook
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try {
        $preCommitPath = ".git/hooks/pre-commit"
        
        if ($PSCmdlet.ShouldProcess($preCommitPath, "Remove pre-commit hook")) {
            if (Test-Path $preCommitPath) {
                Remove-Item $preCommitPath -Force
                Write-CustomLog "Pre-commit hook removed successfully" -Level "SUCCESS"
                return $true
            } else {
                Write-CustomLog "No pre-commit hook found to remove" -Level "INFO"
                return $false
            }
        }
    }
    catch {
        Write-CustomLog "Failed to remove pre-commit hook: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-PreCommitHook {
    <#
    .SYNOPSIS
        Test the pre-commit hook functionality
    
    .DESCRIPTION
        Creates a test file with syntax errors and verifies that the pre-commit hook
        correctly blocks the commit.
    
    .EXAMPLE
        Test-PreCommitHook
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try {
        Write-CustomLog "Testing pre-commit hook functionality..." -Level "INFO"
        
        # Verify hook exists
        $preCommitPath = ".git/hooks/pre-commit"
        if (-not (Test-Path $preCommitPath)) {
            Write-CustomLog "Pre-commit hook not found. Install it first with Install-PreCommitHook" -Level "ERROR"
            return $false
        }
        
        # Create test directory and file with syntax error
        $testDir = "temp"
        $testFile = "$testDir/test-precommit.ps1"
        $testContent = @"
# Test file with intentional syntax error
Param([string]`$TestParam

Write-Host "Test script with missing closing parenthesis"
"@
        
        if ($PSCmdlet.ShouldProcess($testFile, "Create test file and validate pre-commit hook")) {
            # Create test file
            if (-not (Test-Path $testDir)) { New-Item -Path $testDir -ItemType Directory -Force | Out-Null }
            Set-Content -Path $testFile -Value $testContent -Encoding UTF8
            
            try {
                # Stage the test file
                & git add $testFile
                
                # Try to commit (this should fail due to syntax error)
                $commitOutput = & git commit -m "Test commit (should fail)" 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -ne 0) {
                    Write-CustomLog "Pre-commit hook correctly blocked invalid PowerShell script" -Level "SUCCESS"
                    $result = $true
                } else {
                    Write-CustomLog "Pre-commit hook failed to block invalid script" -Level "ERROR"
                    Write-CustomLog "Commit output: $commitOutput" -Level "ERROR"
                    $result = $false
                }
                
                # Clean up Git state
                & git reset HEAD~1 --soft 2>$null
                & git reset HEAD $testFile 2>$null
                
                return $result
            }
            finally {
                # Clean up test files
                if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
                if (Test-Path $testDir) { Remove-Item $testDir -Force -Recurse -ErrorAction SilentlyContinue }
            }
        }
    }
    catch {
        Write-CustomLog "Failed to test pre-commit hook: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-PreCommitHookContent {
    <#
    .SYNOPSIS
        Generate the content for the Git pre-commit hook
    
    .DESCRIPTION
        Creates the PowerShell script content that will be used as the Git pre-commit hook.
        This hook validates PowerShell files using PatchManager validation.
    
    .EXAMPLE
        $content = Get-PreCommitHookContent
    #>
    [CmdletBinding()]
    param()

    $hookContent = @"
#!/usr/bin/env pwsh
#Requires -Version 7.0
# Comprehensive Pre-Commit Hook for OpenTofu Lab Automation

`$ErrorActionPreference = 'Stop'

Write-Host "Running pre-commit validation..." -ForegroundColor Cyan

# Emoji Prevention Check
Write-Host "Checking for emojis in staged files..." -ForegroundColor Gray
$emojiPattern = [regex]'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0]-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]'
$stagedContent = git diff --cached
if ($emojiPattern.IsMatch($stagedContent)) {
    Write-Host "[FAIL] Emojis detected in staged files!" -ForegroundColor Red
    Write-Host "This project follows a strict no-emoji policy." -ForegroundColor Red
    Write-Host "Please remove emojis and use professional language." -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] No emojis detected" -ForegroundColor Green

# PowerShell Syntax Validation
$stagedPsFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.ps1$' }
if ($stagedPsFiles.Count -gt 0) {
    Write-Host "Validating $($stagedPsFiles.Count) PowerShell files..." -ForegroundColor Gray
    $hasErrors = $false
    foreach ($file in $stagedPsFiles) {
        if (Test-Path $file) {
            try {
                $content = Get-Content $file -Raw -ErrorAction Stop
                [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) | Out-Null
                Write-Host "  [PASS] $file" -ForegroundColor Green
            }
            catch {
                Write-Host "  [FAIL] $file - $($_.Exception.Message)" -ForegroundColor Red
                $hasErrors = $true
            }
        }
    }
    if ($hasErrors) {
        Write-Host "[FAIL] PowerShell syntax errors detected!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[PASS] All pre-commit checks passed!" -ForegroundColor Green
exit 0
"@

    return $hookContent
}

function Test-DevelopmentSetup {
    <#
    .SYNOPSIS
        Test the complete development environment setup
    
    .DESCRIPTION
        Validates that the development environment is properly configured,
        including Git hooks, required modules, and development tools.
    
    .EXAMPLE
        Test-DevelopmentSetup
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog "Testing development environment setup..." -Level "INFO"
        
        $issues = @()
        
        # Check Git repository
        if (-not (Test-Path ".git")) {
            $issues += "Not in a Git repository"
        }
        
        # Check pre-commit hook
        if (-not (Test-Path ".git/hooks/pre-commit")) {
            $issues += "Pre-commit hook not installed"
        }        # Check required modules
        $requiredModules = @("PatchManager", "Logging")
        foreach ($module in $requiredModules) {
            $modulePath = "$env:PROJECT_ROOT/pwsh/modules/$module"
            if (-not (Test-Path $modulePath)) {
                $issues += "Required module '$module' not found at $modulePath"
            }
        }
        
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $issues += "PowerShell 7.0+ required (current: $($PSVersionTable.PSVersion))"
        }
        
        if ($issues.Count -eq 0) {
            Write-CustomLog "Development environment setup is valid" -Level "SUCCESS"
            return $true
        } else {
            Write-CustomLog "Development environment issues found:" -Level "WARN"
            foreach ($issue in $issues) {
                Write-CustomLog "  - $issue" -Level "WARN"
            }
            return $false
        }
    }
    catch {
        Write-CustomLog "Failed to test development setup: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}


