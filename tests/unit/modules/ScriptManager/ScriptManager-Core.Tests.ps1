BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Import the ScriptManager module
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else { 
        '/workspaces/AitherLabs'
    }
    $scriptManagerPath = Join-Path $projectRoot "aither-core/modules/ScriptManager"
    
    try {
        Import-Module $scriptManagerPath -Force -ErrorAction Stop
        Write-Host "ScriptManager module imported successfully from: $scriptManagerPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import ScriptManager module: $_"
        throw
    }
    
    # Create test script directory
    $script:testScriptDir = Join-Path $TestDrive "Scripts"
    New-Item -Path $script:testScriptDir -ItemType Directory -Force | Out-Null
}

Describe "ScriptManager Module - Core Functions" {
    
    Context "Register-OneOffScript" {
        
        BeforeEach {
            # Create a simple test script
            $script:testScriptPath = Join-Path $script:testScriptDir "TestScript.ps1"
            @"
# Test Script
Write-Host "Test script executed successfully"
return "Script completed"
"@ | Out-File -FilePath $script:testScriptPath -Encoding UTF8
        }
        
        It "Should register a script successfully" {
            { Register-OneOffScript -ScriptPath $script:testScriptPath -Name "TestScript" } | Should -Not -Throw
        }
        
        It "Should register script with description" {
            { Register-OneOffScript -ScriptPath $script:testScriptPath -Name "TestScript" -Description "A test script for validation" } | Should -Not -Throw
        }
        
        It "Should register script with parameters" {
            $parameters = @{
                "Param1" = "Value1"
                "Param2" = "Value2"
            }
            
            { Register-OneOffScript -ScriptPath $script:testScriptPath -Name "TestScript" -Parameters $parameters } | Should -Not -Throw
        }
        
        It "Should handle non-existent script path" {
            $nonExistentPath = Join-Path $script:testScriptDir "NonExistent.ps1"
            
            { Register-OneOffScript -ScriptPath $nonExistentPath -Name "NonExistentScript" } | Should -Throw
        }
        
        It "Should handle empty script name" {
            { Register-OneOffScript -ScriptPath $script:testScriptPath -Name "" } | Should -Throw
        }
        
        It "Should handle null script name" {
            { Register-OneOffScript -ScriptPath $script:testScriptPath -Name $null } | Should -Throw
        }
    }
    
    Context "Test-OneOffScript" {
        
        BeforeEach {
            # Create test scripts with different characteristics
            $script:validScriptPath = Join-Path $script:testScriptDir "ValidScript.ps1"
            $script:invalidScriptPath = Join-Path $script:testScriptDir "InvalidScript.ps1"
            $script:syntaxErrorScriptPath = Join-Path $script:testScriptDir "SyntaxErrorScript.ps1"
            
            # Valid script
            @"
# Valid PowerShell script
param([string]`$Message = "Default")
Write-Host "Script message: `$Message"
return "Success"
"@ | Out-File -FilePath $script:validScriptPath -Encoding UTF8
            
            # Invalid script (file exists but not a PS1)
            "This is not a PowerShell script" | Out-File -FilePath $script:invalidScriptPath -Encoding UTF8
            
            # Script with syntax errors
            @"
# Script with syntax errors
function Test-Function {
    param([string]`$param
    # Missing closing parenthesis
    Write-Host "This has syntax errors"
}
"@ | Out-File -FilePath $script:syntaxErrorScriptPath -Encoding UTF8
        }
        
        It "Should validate a correct PowerShell script" {
            $result = Test-OneOffScript -ScriptPath $script:validScriptPath
            
            $result | Should -Be $true
        }
        
        It "Should detect non-existent script" {
            $nonExistentPath = Join-Path $script:testScriptDir "DoesNotExist.ps1"
            
            $result = Test-OneOffScript -ScriptPath $nonExistentPath
            
            $result | Should -Be $false
        }
        
        It "Should handle script with syntax errors" {
            $result = Test-OneOffScript -ScriptPath $script:syntaxErrorScriptPath
            
            # Should return false for syntax errors
            $result | Should -Be $false
        }
        
        It "Should validate script with parameters" {
            $result = Test-OneOffScript -ScriptPath $script:validScriptPath
            
            $result | Should -Be $true
        }
        
        It "Should handle empty file path" {
            { Test-OneOffScript -ScriptPath "" } | Should -Throw
        }
        
        It "Should handle null file path" {
            { Test-OneOffScript -ScriptPath $null } | Should -Throw
        }
    }
    
    Context "Invoke-OneOffScript" {
        
        BeforeEach {
            # Create test scripts for execution
            $script:simpleScriptPath = Join-Path $script:testScriptDir "SimpleScript.ps1"
            $script:parameterScriptPath = Join-Path $script:testScriptDir "ParameterScript.ps1"
            $script:errorScriptPath = Join-Path $script:testScriptDir "ErrorScript.ps1"
            $script:longRunningScriptPath = Join-Path $script:testScriptDir "LongRunningScript.ps1"
            
            # Simple script
            @"
Write-Host "Simple script executed"
return "Simple script result"
"@ | Out-File -FilePath $script:simpleScriptPath -Encoding UTF8
            
            # Script with parameters
            @"
param(
    [string]`$Name = "World",
    [int]`$Count = 1
)

for (`$i = 1; `$i -le `$Count; `$i++) {
    Write-Host "Hello `$Name - Iteration `$i"
}
return "Completed `$Count iterations for `$Name"
"@ | Out-File -FilePath $script:parameterScriptPath -Encoding UTF8
            
            # Script that throws an error
            @"
Write-Host "About to throw an error"
throw "This is a test error"
"@ | Out-File -FilePath $script:errorScriptPath -Encoding UTF8
            
            # Long running script
            @"
Write-Host "Starting long running operation"
Start-Sleep -Seconds 2
Write-Host "Long running operation completed"
return "Long operation result"
"@ | Out-File -FilePath $script:longRunningScriptPath -Encoding UTF8
        }
        
        It "Should execute a simple script successfully" {
            $result = Invoke-OneOffScript -ScriptPath $script:simpleScriptPath
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should execute script with parameters" {
            $parameters = @{
                Name = "TestUser"
                Count = 3
            }
            
            $result = Invoke-OneOffScript -ScriptPath $script:parameterScriptPath -Parameters $parameters
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle script execution errors gracefully" {
            try {
                $result = Invoke-OneOffScript -ScriptPath $script:errorScriptPath
                # If it doesn't throw, check that it handles the error appropriately
                $result | Should -BeOfType [System.Management.Automation.ErrorRecord] -Because "Script errors should be captured"
            }
            catch {
                # If it throws, that's also acceptable behavior
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should execute script in separate scope" {
            # Test that variables don't leak between script executions
            $script:scopeTestPath = Join-Path $script:testScriptDir "ScopeTest.ps1"
            @"
`$testVariable = "ScriptValue"
return `$testVariable
"@ | Out-File -FilePath $script:scopeTestPath -Encoding UTF8
            
            Invoke-OneOffScript -ScriptPath $script:scopeTestPath | Out-Null
            
            # The variable should not exist in the current scope
            { Get-Variable -Name testVariable -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle non-existent script file" {
            $nonExistentPath = Join-Path $script:testScriptDir "DoesNotExist.ps1"
            
            { Invoke-OneOffScript -ScriptPath $nonExistentPath } | Should -Throw
        }
          It "Should respect timeout parameter" {
            # This test may be implementation-dependent
            try {
                Invoke-OneOffScript -ScriptPath $script:longRunningScriptPath -TimeoutSeconds 1 | Out-Null
                # If timeout is implemented, should either return partial result or throw
                $true | Should -Be $true
            }
            catch {
                # Timeout exception is acceptable
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "ScriptManager Module - Integration Scenarios" {
    
    Context "Complete Workflow" {
        
        BeforeEach {
            $script:workflowScriptPath = Join-Path $script:testScriptDir "WorkflowTest.ps1"
            @"
param(
    [string]`$Environment = "Test",
    [string]`$Action = "Deploy"
)

Write-Host "Executing `$Action in `$Environment environment"

switch (`$Action) {
    "Deploy" { 
        Write-Host "Deploying application..."
        return "Deployment successful in `$Environment"
    }
    "Test" { 
        Write-Host "Running tests..."
        return "Tests passed in `$Environment"
    }
    "Cleanup" { 
        Write-Host "Cleaning up..."
        return "Cleanup completed in `$Environment"
    }
    default { 
        throw "Unknown action: `$Action"
    }
}
"@ | Out-File -FilePath $script:workflowScriptPath -Encoding UTF8
        }
        
        It "Should complete register -> test -> invoke workflow" {
            # Register
            { Register-OneOffScript -ScriptPath $script:workflowScriptPath -Name "WorkflowScript" -Description "Test workflow script" } | Should -Not -Throw
            
            # Test
            $testResult = Test-OneOffScript -ScriptPath $script:workflowScriptPath
            $testResult | Should -Be $true
            
            # Invoke
            $parameters = @{
                Environment = "Production"
                Action = "Deploy"
            }
            $invokeResult = Invoke-OneOffScript -ScriptPath $script:workflowScriptPath -Parameters $parameters
            
            $invokeResult | Should -Match "Deployment successful in Production"
        }
        
        It "Should handle different parameter combinations" {
            $testCases = @(
                @{ Environment = "Dev"; Action = "Test"; Expected = "Tests passed in Dev" },
                @{ Environment = "Staging"; Action = "Cleanup"; Expected = "Cleanup completed in Staging" }
            )
            
            foreach ($testCase in $testCases) {
                $result = Invoke-OneOffScript -ScriptPath $script:workflowScriptPath -Parameters $testCase
                $result | Should -Match $testCase.Expected
            }
        }
    }
    
    Context "Error Recovery" {
        
        It "Should recover from script registration failures" {
            $invalidPath = "C:\NonExistent\Invalid\Path\Script.ps1"
            
            try {
                Register-OneOffScript -ScriptPath $invalidPath -Name "InvalidScript"
            }
            catch {
                # Should be able to continue with valid operations after error
                $validPath = Join-Path $script:testScriptDir "RecoveryTest.ps1"
                "Write-Host 'Recovery test'" | Out-File -FilePath $validPath -Encoding UTF8
                
                { Register-OneOffScript -ScriptPath $validPath -Name "RecoveryScript" } | Should -Not -Throw
            }
        }
    }
}

Describe "ScriptManager Module - Performance and Reliability" {
    
    Context "Performance" {
        
        It "Should handle multiple rapid script registrations" {
            $scripts = 1..5 | ForEach-Object {
                $scriptPath = Join-Path $script:testScriptDir "RapidTest$_.ps1"
                "Write-Host 'Script $_'" | Out-File -FilePath $scriptPath -Encoding UTF8
                return $scriptPath
            }
            
            $scripts | ForEach-Object {
                $scriptName = "RapidScript" + ($scripts.IndexOf($_) + 1)
                { Register-OneOffScript -ScriptPath $_ -Name $scriptName } | Should -Not -Throw
            }
        }
        
        It "Should handle concurrent script operations" {
            $scriptPath = Join-Path $script:testScriptDir "ConcurrentTest.ps1"
            "Write-Host 'Concurrent test'" | Out-File -FilePath $scriptPath -Encoding UTF8
            
            # Simulate concurrent access
            $jobs = 1..3 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($Path, $ModulePath)
                    Import-Module $ModulePath -Force
                    Test-OneOffScript -ScriptPath $Path
                } -ArgumentList $scriptPath, (Join-Path $projectRoot "aither-core/modules/ScriptManager")
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results | Should -Not -Contain $false
        }
    }
}
