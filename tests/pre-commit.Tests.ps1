#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for Claude pre-commit hook
.DESCRIPTION
    Validates pre-commit hook functionality, including orchestration
    marker checking and CI environment detection.
#>

BeforeAll {
    $script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
    $script:ScriptPath = Join-Path $script:ProjectRoot ".claude/hooks/pre-commit.ps1"
    
    # Verify script exists
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Cannot find script at: $script:ScriptPath"
    }
    
    # Helper to run script in isolated process
    function Invoke-PreCommitScript {
        param(
            [hashtable]$EnvironmentVariables = @{},
            [string]$WorkingDirectory = $script:ProjectRoot
        )
        
        $envVars = $EnvironmentVariables.GetEnumerator() | ForEach-Object {
            "`$env:$($_.Key) = '$($_.Value)'"
        } | Join-String -Separator "; "
        
        $scriptCmd = if ($envVars) {
            "$envVars; & '$script:ScriptPath'"
        } else {
            "& '$script:ScriptPath'"
        }
        
        $result = pwsh -NoProfile -Command $scriptCmd 2>&1
        return @{
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    }
}

Describe "Pre-Commit Hook - Quality Validation" {
    
    Context "Script structure and metadata" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should have proper shebang" {
            $scriptContent | Should -Match '^#!/usr/bin/env pwsh'
        }
        
        It "Should require PowerShell 7.0 or higher" {
            $scriptContent | Should -Match '#Requires -Version 7\.0'
        }
        
        It "Should have CmdletBinding attribute" {
            $scriptContent | Should -Match '\[CmdletBinding\(\)\]'
        }
        
        It "Should set ErrorActionPreference to Stop" {
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
        }
        
        It "Should have try/catch for error handling" {
            $scriptContent | Should -Match '(?s)try\s*\{.*?\}\s*catch'
        }
        
        It "Should have logging implementation" {
            $scriptContent | Should -Match 'Write-HookLog'
        }
    }
    
    Context "Help documentation" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should have .SYNOPSIS section" {
            $scriptContent | Should -Match '\.SYNOPSIS'
        }
        
        It "Should have .DESCRIPTION section" {
            $scriptContent | Should -Match '\.DESCRIPTION'
        }
        
        It "Should have .PARAMETER sections" {
            $scriptContent | Should -Match '\.PARAMETER'
        }
        
        It "Should have .EXAMPLE sections" {
            $scriptContent | Should -Match '\.EXAMPLE'
        }
    }
    
    Context "Logging functionality" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should define Write-HookLog function" {
            $scriptContent | Should -Match 'function Write-HookLog'
        }
        
        It "Should log at different levels" {
            $scriptContent | Should -Match '-Level\s+Information'
            $scriptContent | Should -Match '-Level\s+Error'
        }
        
        It "Should have fallback logging when Write-CustomLog unavailable" {
            $scriptContent | Should -Match 'Get-Command Write-CustomLog -ErrorAction SilentlyContinue'
        }
    }
    
    Context "CI environment detection" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should check for CI environment variable" {
            $scriptContent | Should -Match '\$env:CI\s*-eq\s*[''"]true[''"]'
        }
        
        It "Should check for CLAUDE_CI environment variable" {
            $scriptContent | Should -Match '\$env:CLAUDE_CI\s*-eq\s*[''"]true[''"]'
        }
        
        It "Should skip orchestration check in CI" {
            $scriptContent | Should -Match 'CI environment detected.*skipping'
        }
    }
    
    Context "Orchestration marker validation" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should define orchestration marker path" {
            $scriptContent | Should -Match '\$orchestrationMarker\s*=\s*[''"]\.claude/\.orchestration-used[''"]'
        }
        
        It "Should test for orchestration marker" {
            $scriptContent | Should -Match 'Test-Path.*\$orchestrationMarker'
        }
        
        It "Should clean up marker file" {
            $scriptContent | Should -Match 'Remove-Item.*\$orchestrationMarker'
        }
        
        It "Should wrap Remove-Item in try/catch" {
            $scriptContent | Should -Match '(?s)try\s*\{[^}]*Remove-Item.*\}\s*catch'
        }
    }
    
    Context "Parameter definitions" {
        BeforeAll {
            # Parse AST to check parameters
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath,
                [ref]$null,
                [ref]$null
            )
            $paramBlock = $ast.ParamBlock
        }
        
        It "Should have parameter block" {
            $paramBlock | Should -Not -BeNullOrEmpty
        }
        
        It "Should define CommitMessage parameter" {
            $paramBlock.ToString() | Should -Match '\$CommitMessage'
        }
        
        It "Should define Branch parameter" {
            $paramBlock.ToString() | Should -Match '\$Branch'
        }
    }
}

Describe "Pre-Commit Hook - Functional Behavior" {
    
    Context "Error handling" {
        BeforeAll {
            $scriptContent = Get-Content $script:ScriptPath -Raw
        }
        
        It "Should have overall try/catch wrapper" {
            $scriptContent | Should -Match '(?s)try\s*\{.*exit 0.*\}\s*catch'
        }
        
        It "Should log errors in catch block" {
            $scriptContent | Should -Match '(?s)catch\s*\{[^}]*Write-HookLog.*Error'
        }
        
        It "Should exit with code 1 on error" {
            $scriptContent | Should -Match '(?s)catch\s*\{[^}]*exit 1'
        }
    }
}
