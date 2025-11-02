#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0215_Configure-MCPServers
.DESCRIPTION
    Comprehensive tests for MCP server configuration script
    Script: 0215_Configure-MCPServers
    Stage: Development
    Description: Configure Model Context Protocol (MCP) servers for GitHub Copilot
#>

Describe '0215_Configure-MCPServers' -Tag 'Unit', 'AutomationScript', 'Development', 'MCP' {

    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../../../../automation-scripts/0215_Configure-MCPServers.ps1'
        $script:ScriptName = '0215_Configure-MCPServers'

        # Load the script content to test the Remove-JsonComment function
        $scriptContent = Get-Content $script:ScriptPath -Raw

        # Extract the Remove-JsonComment function
        $functionMatch = [regex]::Match($scriptContent, '(?s)function Remove-JsonComment \{.*?\n\}')
        if ($functionMatch.Success) {
            Invoke-Expression $functionMatch.Value
        }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should require PowerShell 7+' {
            $content = Get-Content $script:ScriptPath -First 5
            $content -join ' ' | Should -Match '#Requires -Version 7'
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: Scope' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Scope') | Should -Be $true
        }

        It 'Should have parameter: Verify' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Verify') | Should -Be $true
        }

        It 'Scope parameter should accept Workspace and User values' {
            $cmd = Get-Command $script:ScriptPath
            $scopeParam = $cmd.Parameters['Scope']
            $scopeParam.Attributes.ValidValues | Should -Contain 'Workspace'
            $scopeParam.Attributes.ValidValues | Should -Contain 'User'
        }
    }

    Context 'Remove-JsonComment Function' {
        It 'Should strip single-line comments (//)' {
            $json = @'
{
    // This is a comment
    "key": "value"
}
'@
            $result = Remove-JsonComment -JsonContent $json
            $result | Should -Not -Match '//'
            $result | ConvertFrom-Json | Should -Not -BeNullOrEmpty
        }

        It 'Should strip inline comments' {
            $json = @'
{
    "key": "value", // inline comment
    "other": "data"
}
'@
            $result = Remove-JsonComment -JsonContent $json
            $result | Should -Not -Match '// inline'
            $result | ConvertFrom-Json | Should -Not -BeNullOrEmpty
        }

        It 'Should strip multi-line comments (/* */)' {
            $json = @'
{
    /* Multi-line
       comment here */
    "key": "value"
}
'@
            $result = Remove-JsonComment -JsonContent $json
            $result | Should -Not -Match '/\*'
            $result | ConvertFrom-Json | Should -Not -BeNullOrEmpty
        }

        It 'Should preserve URLs with //' {
            $json = @'
{
    "url": "https://example.com",
    "other": "http://test.com"
}
'@
            $result = Remove-JsonComment -JsonContent $json
            $result | Should -Match 'https://'
            $result | Should -Match 'http://'
            $parsed = $result | ConvertFrom-Json
            $parsed.url | Should -Be 'https://example.com'
        }

        It 'Should remove trailing commas' {
            $json = @'
{
    "key": "value",
    "array": [1, 2, 3,],
}
'@
            $result = Remove-JsonComment -JsonContent $json
            $result | Should -Not -Match ',\s*\}'
            $result | Should -Not -Match ',\s*\]'
            $result | ConvertFrom-Json | Should -Not -BeNullOrEmpty
        }

        It 'Should handle complex JSON with multiple comment types' {
            $json = @'
{
    // Editor settings
    "editor.formatOnSave": true,
    "editor.tabSize": 4, // Use 4 spaces

    /* GitHub Copilot
       configuration */
    "github.copilot.enable": {
        "*": true,
        "yaml": true // YAML support
    },
    "github.copilot.chat.mcp.enabled": true,
    "url": "https://github.com/test/repo", // Repository URL
}
'@
            $result = Remove-JsonComment -JsonContent $json
            # Check that comments are removed but URL is preserved
            $result | Should -Not -Match '// Editor'
            $result | Should -Not -Match '// Use 4 spaces'
            $result | Should -Not -Match '/\*'
            $result | Should -Match 'https://github.com'
            $parsed = $result | ConvertFrom-Json
            $parsed.'editor.formatOnSave' | Should -Be $true
            $parsed.'github.copilot.chat.mcp.enabled' | Should -Be $true
            $parsed.url | Should -Be 'https://github.com/test/repo'
        }
    }

    Context 'MCP Configuration' {
        It 'Should configure correct MCP server keys' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'github\.copilot\.chat\.mcp\.enabled'
            $content | Should -Match 'github\.copilot\.chat\.mcp\.servers'
        }

        It 'Should not use incorrect MCP keys' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Not -Match 'github\.copilot\.chat\.advanced\.tools'
        }

        It 'Should not set debug proxy URL' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Not -Match 'overrideProxyUrl'
        }

        It 'Should configure filesystem server' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'filesystem.*=.*\[PSCustomObject\]'
        }

        It 'Should configure github server' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'github.*=.*\[PSCustomObject\]'
        }

        It 'Should configure git server' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git.*=.*\[PSCustomObject\]'
        }

        It 'Should configure sequential-thinking server' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'sequential-thinking.*=.*\[PSCustomObject\]'
        }
    }

    Context 'Error Handling' {
        It 'Should have error handling for JSON parsing' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'try\s*\{[\s\S]*ConvertFrom-Json[\s\S]*\}\s*catch'
        }

        It 'Should have graceful fallback for parse failures' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Failed to parse existing settings'
        }
    }

    Context 'Prerequisites Check' {
        It 'Should check for Node.js' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'node --version'
        }

        It 'Should check for GITHUB_TOKEN' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$env:GITHUB_TOKEN'
        }

        It 'Should check for VS Code' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'code --version'
        }
    }

    Context 'Documentation' {
        It 'Should have SYNOPSIS section' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match '\.SYNOPSIS'
        }

        It 'Should have DESCRIPTION section' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match '\.DESCRIPTION'
        }

        It 'Should have EXAMPLE sections' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match '\.EXAMPLE'
        }
    }
}
