#Requires -Version 7.0

BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
      # Mock gh (GitHub CLI) command
    function global:gh {
        param()
        $allArgs = $args
        $script:ghCalls += ,@($allArgs)
        return ""
    }# Directly source the function file
    $projectRoot = $env:PROJECT_ROOT
    $functionPath = Join-Path $projectRoot "aither-core/modules/PatchManager/Public/ErrorHandling.ps1"
    if (Test-Path $functionPath) {
        . $functionPath
    } else {
        throw "Cannot find ErrorHandling.ps1 at $functionPath"
    }
}

Describe "ErrorHandling Module" {
    BeforeEach {
        $script:ghCalls = @()
    }
      Context "HandlePatchError function" {
        It "Should handle patch error with all parameters" {
            $errorRecord = try { throw "Test error" } catch { $_ }
            
            { HandlePatchError -ErrorMessage "Test error occurred" -ErrorRecord $errorRecord -ErrorCategory "Git" -IssueNumber 123 -Silent } | Should -Not -Throw
        }
        
        It "Should handle error without issue number" {
            $errorRecord = try { throw "Test error" } catch { $_ }
            
            { HandlePatchError -ErrorMessage "Test error occurred" -ErrorRecord $errorRecord -ErrorCategory "PatchValidation" -Silent } | Should -Not -Throw
        }
        
        It "Should handle error without error record" {
            { HandlePatchError -ErrorMessage "Simple test error" -ErrorCategory "General" -Silent } | Should -Not -Throw
        }
          It "Should return structured error object" {
            $result = HandlePatchError -ErrorMessage "Test error" -ErrorCategory "Git" -Silent
            
            $result | Should -Not -BeNullOrEmpty
            $result.Message | Should -Be "Test error"
            $result.Category | Should -Be "Git"
            $result.Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should send GitHub issue comment when IssueNumber provided" {
            $errorRecord = try { throw "Test error" } catch { $_ }
            
            HandlePatchError -ErrorMessage "Test GitHub integration" -ErrorRecord $errorRecord -ErrorCategory "Git" -IssueNumber 123 -Silent
            
            $script:ghCalls.Count | Should -BeGreaterThan 0
            $firstCall = $script:ghCalls[0]
            $firstCall | Should -Contain "issue"
            $firstCall | Should -Contain "123"
        }
        
        It "Should validate error categories" {
            $validCategories = @("Git", "PatchValidation", "BranchStrategy", "PullRequest", "Rollback", "General")
            
            foreach ($category in $validCategories) {
                { HandlePatchError -ErrorMessage "Test category $category" -ErrorCategory $category -Silent } | Should -Not -Throw
            }
        }    }
    
    Context "Write-PatchLog function" {
        It "Should write log message with default level" {
            { Write-PatchLog -Message "Test message" -NoConsole } | Should -Not -Throw
        }
        
        It "Should accept different log levels" {
            $levels = @("INFO", "WARNING", "ERROR", "DEBUG", "SUCCESS")
            
            foreach ($level in $levels) {
                { Write-PatchLog -Message "Test message" -LogLevel $level -NoConsole } | Should -Not -Throw
            }        }
        
        It "Should handle empty message" {
            { Write-PatchLog -Message " " -NoConsole } | Should -Not -Throw
        }
        
        It "Should handle null message gracefully" {
            { Write-PatchLog -Message "null test" -NoConsole } | Should -Not -Throw
        }
        
        It "Should accept custom log file path" {
            $tempLogFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-patch.log"
            try {
                { Write-PatchLog -Message "Test custom log" -LogFile $tempLogFile -NoConsole } | Should -Not -Throw
                $tempLogFile | Should -Exist
            } finally {
                Remove-Item $tempLogFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
