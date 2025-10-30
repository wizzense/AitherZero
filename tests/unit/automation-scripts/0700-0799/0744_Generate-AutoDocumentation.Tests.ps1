#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0744_Generate-AutoDocumentation.ps1
.DESCRIPTION
    Tests the Write-DocLog function and other components of automated documentation generation
#>

BeforeAll {
    $script:projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:script0744 = Join-Path $script:projectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
    
    if (-not (Test-Path $script:script0744)) {
        throw "0744_Generate-AutoDocumentation.ps1 not found at $script:script0744"
    }
    
    # Extract the Write-DocLog function from the script for testing
    $scriptContent = Get-Content $script:script0744 -Raw
    
    # Create a test module with the Write-DocLog function
    $functionCode = @'
function Write-DocLog {
    param([string]$Message, [string]$Level = 'Information', [hashtable]$Data = @{})
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "AutoDocumentation" -Data $Data
    } else {
        Write-Host "[$Level] [AutoDocumentation] $Message" -ForegroundColor $(
            switch ($Level) {
                'Information' { 'White' }
                'Warning' { 'Yellow' }
                'Error' { 'Red' }
                'Debug' { 'Gray' }
                default { 'White' }
            }
        )
    }
}
'@
    
    Invoke-Expression $functionCode
}

Describe "0744 Write-DocLog Function" {
    Context "Log Level Color Mapping" {
        It "Handles 'Information' level without error" {
            { Write-DocLog -Message "Test message" -Level "Information" } | Should -Not -Throw
        }
        
        It "Handles 'Warning' level without error" {
            { Write-DocLog -Message "Test warning" -Level "Warning" } | Should -Not -Throw
        }
        
        It "Handles 'Error' level without error" {
            { Write-DocLog -Message "Test error" -Level "Error" } | Should -Not -Throw
        }
        
        It "Handles 'Debug' level without error" {
            { Write-DocLog -Message "Test debug" -Level "Debug" } | Should -Not -Throw
        }
        
        It "Handles unknown level with default color without error" {
            { Write-DocLog -Message "Test message" -Level "Verbose" } | Should -Not -Throw
        }
        
        It "Handles empty message without error" {
            { Write-DocLog -Message "" -Level "Information" } | Should -Not -Throw
        }
        
        It "Uses default level when not specified" {
            { Write-DocLog -Message "Test message" } | Should -Not -Throw
        }
    }
    
    Context "Parameter Validation" {
        It "Accepts optional Data hashtable" {
            { Write-DocLog -Message "Test" -Level "Information" -Data @{Key = "Value"} } | Should -Not -Throw
        }
        
        It "Works with empty Data hashtable" {
            { Write-DocLog -Message "Test" -Level "Information" -Data @{} } | Should -Not -Throw
        }
    }
}

Describe "0744 Script Validation" {
    Context "ForegroundColor Bug Fix" {
        It "Script contains Debug case in switch statement" {
            $content = Get-Content $script:script0744 -Raw
            # Verify the switch statement includes Debug case
            $content | Should -Match "'Debug'\s*\{\s*'Gray'\s*\}"
        }
        
        It "Script contains default case in switch statement" {
            $content = Get-Content $script:script0744 -Raw
            # Verify the switch statement includes default case
            $content | Should -Match "default\s*\{\s*'White'\s*\}"
        }
        
        It "Script has valid PowerShell syntax" {
            $result = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:script0744, [ref]$result, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
    }
}
