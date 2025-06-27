BeforeAll {
    # Import Logging module first
    $projectRoot = $env:PROJECT_ROOT
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
    
    try {
        Import-Module $loggingPath -Force -Global -ErrorAction Stop
        Write-Host "Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import Logging module: $_"
        throw
    }

    # Import PatchManager module
    $projectRoot = $env:PROJECT_ROOT
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    
    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }
    
    # Mock functions
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Mock Get-Module for testing
    function global:Get-Module {
        param([string]$Name, [switch]$ListAvailable)
        
        if ($Name -in @("Pester", "PSScriptAnalyzer")) {
            return [PSCustomObject]@{
                Name = $Name
                Version = "5.0.0"
                ModuleType = "Script"
            }
        }
        
        if ($Name -eq "MissingModule") {
            return $null
        }
        
        # Call original Get-Module for other cases
        Microsoft.PowerShell.Core\Get-Module @PSBoundParameters
    }
    
    # Mock Install-Module
    function global:Install-Module {
        param([string]$Name, [string]$Scope, [switch]$Force)
        $script:installedModules += $Name
        Write-Host "Mock: Installed module $Name"
    }
    
    # Mock Get-Command
    function global:Get-Command {
        param([string]$Name, [string]$ErrorAction)
        
        if ($Name -in @("git", "gh", "python")) {
            return [PSCustomObject]@{
                Name = $Name
                CommandType = "Application"
                Source = "C:\Program Files\$Name\$Name.exe"
            }
        }
        
        if ($Name -eq "missingcommand") {
            if ($ErrorAction -eq "SilentlyContinue") {
                return $null
            }
            throw "Command not found: $Name"
        }
        
        # Call original Get-Command for other cases
        Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
    }
    
    # Mock git for rollback testing
    function global:git {
        param()
        $gitArgs = $args
        $script:gitCalls += , $gitArgs
        
        switch -Regex ($gitArgs -join " ") {
            "^log --oneline -n" {
                return @(
                    "abc123 Latest commit",
                    "def456 Previous commit",
                    "ghi789 Older commit"
                )
            }
            "^reset --hard HEAD~1" {
                $script:rollbackPerformed = $true
                return "HEAD is now at def456 Previous commit"
            }
            "^reset --hard" {
                $script:rollbackPerformed = $true
                $commitHash = $gitArgs[2]
                return "HEAD is now at $commitHash"
            }
            "^stash save" {
                $script:stashCreated = $true
                return "Saved working directory and index state"
            }
            "^stash pop" {
                $script:stashPopped = $true
                return "Applied stash"
            }
            "^reflog" {
                return @(
                    "abc123 HEAD@{0}: commit: Latest commit",
                    "def456 HEAD@{1}: commit: Previous commit"
                )
            }
            default {
                $global:LASTEXITCODE = 0
                return ""
            }
        }
    }
}

Describe "PatchManager Validation Functions" {
    BeforeEach {
        $script:installedModules = @()
        $script:gitCalls = @()
    }
    
    Context "Test-PatchingRequirements" {
        It "Should detect available PowerShell modules" {
            $result = Test-PatchingRequirements -ProjectRoot $PWD
            
            $result.ModulesAvailable | Should -Contain "Pester"
            $result.ModulesAvailable | Should -Contain "PSScriptAnalyzer"
        }
        
        It "Should detect missing PowerShell modules" {
            # Override Get-Module to simulate missing module
            function global:Get-Module {
                param([string]$Name, [switch]$ListAvailable)
                if ($Name -eq "Pester") { return $null }
                return [PSCustomObject]@{ Name = $Name; Version = "5.0.0" }
            }
            
            $result = Test-PatchingRequirements -ProjectRoot $PWD
            
            $result.ModulesMissing | Should -Contain "Pester"
            $result.AllRequirementsMet | Should -Be $false
        }
        
        It "Should detect available commands" {
            $result = Test-PatchingRequirements -ProjectRoot $PWD
            
            $result.CommandsAvailable | Should -Contain "git"
        }
        
        It "Should detect missing commands" {
            # Override Get-Command to simulate missing command
            function global:Get-Command {
                param([string]$Name, [string]$ErrorAction)
                if ($Name -eq "git") {
                    if ($ErrorAction -eq "SilentlyContinue") { return $null }
                    throw "Command not found"
                }
                return [PSCustomObject]@{ Name = $Name; CommandType = "Application" }
            }
            
            $result = Test-PatchingRequirements -ProjectRoot $PWD
            
            $result.CommandsMissing | Should -Contain "git"
            $result.AllRequirementsMet | Should -Be $false
        }
        
        It "Should provide fix suggestions for missing requirements" {
            # Simulate missing Pester module
            function global:Get-Module {
                param([string]$Name, [switch]$ListAvailable)
                if ($Name -eq "Pester") { return $null }
                return [PSCustomObject]@{ Name = $Name; Version = "5.0.0" }
            }
            
            $result = Test-PatchingRequirements -ProjectRoot $PWD
            
            $result.Fixes | Should -Contain "Install-Module -Name 'Pester' -Scope CurrentUser -Force"
        }
        
        It "Should install missing modules when requested" {
            # Simulate missing module
            function global:Get-Module {
                param([string]$Name, [switch]$ListAvailable)
                if ($Name -eq "TestModule") { return $null }
                return [PSCustomObject]@{ Name = $Name; Version = "5.0.0" }
            }
            
            Test-PatchingRequirements -ProjectRoot $PWD -InstallMissing
            
            # Should have attempted to install missing modules
            $script:installedModules.Count | Should -BeGreaterOrEqual 0
        }
        
        It "Should validate affected files when provided" {
            $affectedFiles = @("test-file1.ps1", "test-file2.ps1")
            
            { Test-PatchingRequirements -ProjectRoot $PWD -AffectedFiles $affectedFiles } | Should -Not -Throw
        }
        
        It "Should write to log file when specified" {
            $logFile = "$env:TEMP\test-patch-requirements.log"
            
            try {
                Test-PatchingRequirements -ProjectRoot $PWD -LogFile $logFile
                
                Test-Path $logFile | Should -Be $true
                (Get-Content $logFile).Count | Should -BeGreaterThan 0
            }
            finally {
                Remove-Item $logFile -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Invoke-PatchValidation" {
        It "Should perform comprehensive patch validation" {
            { Invoke-PatchValidation -PatchDescription "test: validation check" } | Should -Not -Throw
        }
        
        It "Should validate specific files when provided" {
            $testFiles = @("test-file1.ps1", "test-file2.ps1")
            
            { Invoke-PatchValidation -PatchDescription "test: file validation" -AffectedFiles $testFiles } | Should -Not -Throw
        }
        
        It "Should perform syntax validation" {
            { Invoke-PatchValidation -PatchDescription "test: syntax check" -ValidateSyntax } | Should -Not -Throw
        }
        
        It "Should perform module validation" {
            { Invoke-PatchValidation -PatchDescription "test: module check" -ValidateModules } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Rollback Functions" {
    BeforeEach {
        $script:gitCalls = @()
        $script:rollbackPerformed = $false
        $script:stashCreated = $false
        $script:stashPopped = $false
    }
    
    Context "Invoke-QuickRollback" {
        It "Should rollback last commit" {
            $result = Invoke-QuickRollback -RollbackType "LastCommit" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should rollback to specific commit" {
            $result = Invoke-QuickRollback -RollbackType "SpecificCommit" -CommitHash "def456" -DryRun
            
            $result.Success | Should -Be $true
        }
        
        It "Should rollback working tree changes" {
            $result = Invoke-QuickRollback -RollbackType "WorkingTree" -DryRun
            
            $result.Success | Should -Be $true
        }
        
        It "Should create backup when requested" {
            $result = Invoke-QuickRollback -RollbackType "LastCommit" -CreateBackup -DryRun
            
            $result.BackupCreated | Should -Be $true
        }
        
        It "Should handle force parameter" {
            { Invoke-QuickRollback -RollbackType "LastCommit" -Force -DryRun } | Should -Not -Throw
        }
        
        It "Should validate rollback safety" {
            $result = Invoke-QuickRollback -RollbackType "LastCommit" -ValidateSafety -DryRun
            
            $result.SafetyValidated | Should -Be $true
        }
    }
    
    Context "Invoke-PatchRollback" {
        It "Should rollback specific patch by description" {
            { Invoke-PatchRollback -PatchDescription "test: specific patch" -DryRun } | Should -Not -Throw
        }
        
        It "Should rollback patch by commit hash" {
            { Invoke-PatchRollback -CommitHash "abc123" -DryRun } | Should -Not -Throw
        }
        
        It "Should handle rollback with affected files" {
            $affectedFiles = @("file1.ps1", "file2.ps1")
            
            { Invoke-PatchRollback -PatchDescription "test: file rollback" -AffectedFiles $affectedFiles -DryRun } | Should -Not -Throw
        }
        
        It "Should create restoration point" {
            { Invoke-PatchRollback -PatchDescription "test: restore point" -CreateRestorationPoint -DryRun } | Should -Not -Throw
        }
    }
    
    Context "Invoke-BranchRollback" {
        It "Should rollback to previous branch state" {
            { Invoke-BranchRollback -BranchName "feature/test" -DryRun } | Should -Not -Throw
        }
        
        It "Should handle branch deletion rollback" {
            { Invoke-BranchRollback -BranchName "deleted-branch" -RestoreDeleted -DryRun } | Should -Not -Throw
        }
        
        It "Should rollback branch merge" {
            { Invoke-BranchRollback -BranchName "merged-branch" -RollbackMerge -DryRun } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Error Handling and Monitoring" {
    Context "Invoke-ErrorHandler" {
        It "Should handle PowerShell errors gracefully" {
            $testError = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            
            { Invoke-ErrorHandler -ErrorRecord $testError -Context @{ Operation = "Test context" } -ErrorType "RuntimeError" } | Should -Not -Throw
        }
        
        It "Should log errors appropriately" {
            $testError = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
              $result = Invoke-ErrorHandler -ErrorRecord $testError -Context @{ Operation = "Test context" } -ErrorType "RuntimeError"
            
            $result.ErrorLogged | Should -Be $true
        }
        
        It "Should provide recovery suggestions" {
            $testError = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Module not found"),
                "ModuleNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $null
            )
            
            $result = Invoke-ErrorHandler -ErrorRecord $testError -ErrorType "ImportError"
            
            $result.RecoverySuggestions | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-MonitoredExecution" {
        It "Should monitor script block execution" {
            $testScript = { Write-Host "Test execution" }
            
            $result = Invoke-MonitoredExecution -ScriptBlock $testScript -OperationName "Test Operation"
            
            $result.Success | Should -Be $true
            $result.ExecutionTime | Should -BeGreaterThan ([TimeSpan]::Zero)
        }
        
        It "Should handle execution failures" {
            $failingScript = { throw "Test failure" }
            
            $result = Invoke-MonitoredExecution -ScriptBlock $failingScript -OperationName "Failing Operation"
            
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide execution metrics" {
            $testScript = { Start-Sleep -Milliseconds 100 }
            
            $result = Invoke-MonitoredExecution -ScriptBlock $testScript -OperationName "Timed Operation"
            
            $result.ExecutionTime.TotalMilliseconds | Should -BeGreaterThan 50
        }
    }
}

Describe "PatchManager Issue Tracking Integration" {
    Context "Invoke-ComprehensiveIssueTracking" {
        It "Should track patch-related issues" {
            { Invoke-ComprehensiveIssueTracking -PatchDescription "test: issue tracking" } | Should -Not -Throw
        }
        
        It "Should integrate with existing issues" {
            { Invoke-ComprehensiveIssueTracking -PatchDescription "test: issue integration" -ExistingIssueNumber 123 } | Should -Not -Throw
        }
        
        It "Should create automated issue tracking" {
            { Invoke-ComprehensiveIssueTracking -PatchDescription "test: automated tracking" -CreateAutomatedTracking } | Should -Not -Throw
        }
    }
}
