#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for core-runner scripts
    
.DESCRIPTION
    Comprehensive unit tests for all core-runner scripts including:
    - core-runner.ps1
    - Validation of script structure and functionality
    - Parameter validation
    - Cross-platform compatibility
#>

BeforeAll { 
    # Set up environment variables if not already set
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    }
    
    # Set up test environment - ensure Pester detection works
    $env:PESTER_RUN = 'true'
    
    # Set up test environment
    $script:CoreRunnerPath = "$env:PROJECT_ROOT/aither-core"
    $script:CoreRunnerScript = "$script:CoreRunnerPath/core-runner.ps1"

    
    # Mock Write-CustomLog to avoid dependencies
    function Write-CustomLog {
        param(
            [string]$Message,
            [string]$Level = 'INFO',
            [string]$Component = 'Test'
        )
        Write-Host "[$Level] [$Component] $Message"
    }
}

Describe 'Core Runner Script Validation Tests' -Tag @('Unit', 'CoreRunner', 'Validation') {
    
    Context 'Script file existence and basic validation' {
        
        It 'should have core-runner.ps1 script' {
            $script:CoreRunnerScript | Should -Exist
        }
        
        It 'should have valid PowerShell syntax in core-runner.ps1' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:CoreRunnerScript, [ref]$null, [ref]$errors) | Out-Null
            
            $errorCount = if ($errors) { $errors.Count } else { 0 }
            $errorCount | Should -Be 0 -Because 'core-runner.ps1 should have valid PowerShell syntax'
        }
    }
}

Describe 'Core Runner Script Structure Tests' -Tag @('Unit', 'CoreRunner', 'Structure') {
    
    Context 'core-runner.ps1 structure validation' {
        
        BeforeAll {
            $script:CoreRunnerContent = Get-Content $script:CoreRunnerScript -Raw
        }
        
        It 'should require PowerShell 7.0 or later' {
            $script:CoreRunnerContent | Should -Match '#Requires -Version 7\.0' -Because 'Script should require PowerShell 7.0+'
        }
        
        It 'should have proper CmdletBinding with SupportsShouldProcess' {
            $script:CoreRunnerContent | Should -Match '\[CmdletBinding\([^)]*SupportsShouldProcess[^)]*\)\]' -Because 'Script should support -WhatIf parameter'
        }
        
        It 'should have comprehensive parameter definitions' {
            $script:CoreRunnerContent | Should -Match 'param\s*\(' -Because 'Script should have parameter block'
        }
        
        It 'should have expected parameters' {
            $expectedParams = @(
                'Quiet',
                'Verbosity',
                'ConfigFile',
                'Auto',
                'Scripts',
                'Force'
            )
            
            foreach ($param in $expectedParams) {
                $script:CoreRunnerContent | Should -Match "\`$$param" -Because "Script should have $param parameter"
            }
        }
        
        It 'should have parameter validation attributes' {
            $script:CoreRunnerContent | Should -Match '\[ValidateSet\(' -Because 'Script should use ValidateSet for constrained parameters'
        }
        
        It 'should have comprehensive help documentation' {
            $script:CoreRunnerContent | Should -Match '\.SYNOPSIS' -Because 'Script should have synopsis documentation'
            $script:CoreRunnerContent | Should -Match '\.DESCRIPTION' -Because 'Script should have description documentation'
            $script:CoreRunnerContent | Should -Match '\.PARAMETER' -Because 'Script should have parameter documentation'
            $script:CoreRunnerContent | Should -Match '\.EXAMPLE' -Because 'Script should have usage examples'
        }
    }
}
Describe 'Core Runner Parameter Validation Tests' -Tag @('Unit', 'CoreRunner', 'Parameters') {
    
    Context 'core-runner.ps1 parameter validation' {        It 'should accept Quiet parameter as switch' {
            { & $script:CoreRunnerScript -Quiet -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
        }
        
        It 'should accept valid Verbosity values' {
            $validVerbosity = @('silent', 'normal', 'detailed')
            
            foreach ($level in $validVerbosity) {
                { & $script:CoreRunnerScript -Verbosity $level -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw -Because "Should accept verbosity level: $level"
            }
        }
        
        It 'should reject invalid Verbosity values' {
            { & $script:CoreRunnerScript -Verbosity 'invalid' -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Throw -Because 'Should reject invalid verbosity level'
        }
        
        It 'should accept ConfigFile parameter' {
            $tempConfig = New-TemporaryFile
            @{test = 'value' } | ConvertTo-Json | Set-Content -Path $tempConfig.FullName
            
            try {
                { & $script:CoreRunnerScript -ConfigFile $tempConfig.FullName -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
            } finally {
                Remove-Item $tempConfig.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'should accept Auto parameter as switch' {
            { & $script:CoreRunnerScript -Auto -WhatIf } | Should -Not -Throw
        }
        
        It 'should accept Scripts parameter' {
            { & $script:CoreRunnerScript -Scripts 'test-script' -WhatIf } | Should -Not -Throw
        }
        
        It 'should accept Force parameter as switch' {
            { & $script:CoreRunnerScript -Force -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
        }
        
        It 'should accept NonInteractive parameter as switch' {
            { & $script:CoreRunnerScript -NonInteractive -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
        }
        
        It 'should support parameter sets correctly' {
            # Test Quiet parameter set
            { & $script:CoreRunnerScript -Quiet -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
            
            # Test Verbose parameter set
            { & $script:CoreRunnerScript -Verbosity detailed -Scripts "0200_Get-SystemInfo" -WhatIf } | Should -Not -Throw
        }
    }
}

Describe 'Core Runner Cross-Platform Compatibility Tests' -Tag @('Unit', 'CoreRunner', 'CrossPlatform') {
    
    Context 'Path handling and platform-specific code' {
        
        It 'should not use Windows-specific path formats in core-runner.ps1' {
            $content = Get-Content $script:CoreRunnerScript -Raw
            $content | Should -Not -Match '[A-Z]:\\|\\\\' -Because 'Script should not use Windows-specific path formats'
        }
        
        It 'should use environment variables for paths' {
            $content = Get-Content $script:CoreRunnerScript -Raw
            if ($content -match '\$env:') {
                $content | Should -Match '\$env:PROJECT_ROOT|\$env:PWSH_MODULES_PATH' -Because 'Script should use standard environment variables'
            }
        }
        
        It 'should not use Windows-specific cmdlets' {
            $content = Get-Content $script:CoreRunnerScript -Raw
            
            $windowsSpecific = @(
                'Get-WmiObject',
                'Get-CimInstance.*Win32',
                'New-PSDrive.*-Persist',
                'Start-Process.*-WindowStyle'
            )
            
            foreach ($pattern in $windowsSpecific) {
                $content | Should -Not -Match $pattern -Because "Script should avoid Windows-specific cmdlets: $pattern"
            }
        }
    }
    
    Context 'PowerShell version compatibility' {
        
        It 'should use PowerShell 7.0+ compatible syntax' {
            $content = Get-Content $script:CoreRunnerScript -Raw
            
            # Check for PowerShell 7.0+ features if used
            if ($content -match '\?\?') {
                # Null coalescing operator is PowerShell 7.0+
                $content | Should -Match '#Requires -Version 7\.0' -Because 'Script using null coalescing should require PowerShell 7.0+'
            }
        }
    }
}

Describe 'Core Runner Error Handling Tests' -Tag @('Unit', 'CoreRunner', 'ErrorHandling') {
    
    Context 'Error handling patterns' {
          It 'should handle missing configuration files gracefully' {
            $nonExistentConfig = Join-Path ([System.IO.Path]::GetTempPath()) 'nonexistent-config.json'
            
            # Should exit gracefully in non-interactive mode, not throw an error
            { & $script:CoreRunnerScript -ConfigFile $nonExistentConfig -WhatIf } | Should -Not -Throw -Because 'Should handle missing config files gracefully in non-interactive mode'
        }
        
        It 'should validate input parameters' {
            # Test empty string for ConfigFile - should exit gracefully in non-interactive mode
            { & $script:CoreRunnerScript -ConfigFile '' -WhatIf } | Should -Not -Throw -Because 'Should handle empty ConfigFile parameter gracefully in non-interactive mode'
        }
        
        It 'should set appropriate error action preference' {
            $content = Get-Content $script:CoreRunnerScript -Raw
            
            if ($content -match '\$ErrorActionPreference') {
                $content | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]' -Because 'Script should use strict error handling'
            }
        }
    }
}

Describe 'Core Runner Integration Tests' -Tag @('Integration', 'CoreRunner', 'Functionality') {
    
    Context 'Basic functionality testing' {
        It 'should execute with WhatIf parameter successfully' {
            { & $script:CoreRunnerScript -WhatIf } | Should -Not -Throw -Because 'Script should support WhatIf execution'
        }
        
        It 'should accept and process multiple parameters' {
            $tempConfig = New-TemporaryFile
            @{test = 'value' } | ConvertTo-Json | Set-Content -Path $tempConfig.FullName
            
            try {
                { & $script:CoreRunnerScript -ConfigFile $tempConfig.FullName -Verbosity detailed -Auto -WhatIf } | Should -Not -Throw
            } finally {
                Remove-Item $tempConfig.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'should handle default configuration when no ConfigFile specified' {
            { & $script:CoreRunnerScript -WhatIf } | Should -Not -Throw -Because 'Script should handle default configuration'
        }
    }
}

Describe 'Core Runner Performance Tests' -Tag @('Performance', 'CoreRunner') {
    
    Context 'Execution performance' {
        
        It 'should load and validate parameters quickly' {
            $executionTime = Measure-Command {
                & $script:CoreRunnerScript -WhatIf
            }
            $executionTime.TotalSeconds | Should -BeLessOrEqual 10 -Because 'Script should load and validate parameters within 10 seconds'
        }
        
        It 'should handle multiple parameter validations efficiently' {
            $tempConfig = New-TemporaryFile
            @{test = 'value' } | ConvertTo-Json | Set-Content -Path $tempConfig.FullName
            
            try {
                $executionTime = Measure-Command {
                    & $script:CoreRunnerScript -ConfigFile $tempConfig.FullName -Verbosity detailed -Auto -Scripts 'test' -Force -WhatIf
                }
                
                $executionTime.TotalSeconds | Should -BeLessOrEqual 15 -Because 'Script should handle complex parameter validation within 15 seconds'
            } finally {
                Remove-Item $tempConfig.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}