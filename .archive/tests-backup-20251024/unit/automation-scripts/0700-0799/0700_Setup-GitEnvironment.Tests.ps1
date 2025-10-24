#Requires -Version 7.0

BeforeAll {
    # Mock the GitAutomation module functions
    $script:MockCalls = @{}
    
    # Create mock module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Set-GitConfiguration {
            param($Key, $Value, $Level = 'Local')
            if (-not $script:MockCalls['Set-GitConfiguration']) {
                $script:MockCalls['Set-GitConfiguration'] = @()
            }
            $script:MockCalls['Set-GitConfiguration'] += @{ Key = $Key; Value = $Value; Level = $Level }
        }
        
        function Get-GitRepository {
            return @{
                Path = '/mock/repo'
                Branch = 'main'
                RemoteUrl = 'https://github.com/test/repo'
                Status = @('M file1.txt', 'A file2.txt')
            }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git { 
        switch ($arguments[0]) {
            'config' { return '' }
            'status' { return 'On branch main' }
            'diff' { return '' }
            default { return '' }
        }
    }
    
    Mock Test-Path { return $true }
    Mock Set-Content { }
    Mock chmod { }
    Mock Write-Host { }
    Mock Write-Error { }
    Mock Join-Path { return "/mock/path/$($arguments[1])" }
    Mock Split-Path { return "/mock" }
    Mock Get-Content { return "mock content" }
    Mock Get-Item { return @{ Length = 1024 } }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'Set-GitConfiguration' = @()
    }
}

Describe "0700_Setup-GitEnvironment" {
    Context "Parameter Validation" {
        It "Should accept UserName parameter" {
            $params = @{ UserName = "testuser" }
            { & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" @params -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept UserEmail parameter" {
            $params = @{ UserEmail = "test@example.com" }
            { & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" @params -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept Global switch" {
            $params = @{ Global = $true }
            { & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" @params -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Git Configuration" {
        BeforeEach {
            $script:MockCalls['Set-GitConfiguration'] = @()
        }
        
        It "Should set user name when provided" {
            & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" -UserName "testuser" -WhatIf
            
            $userNameCall = $script:MockCalls['Set-GitConfiguration'] | Where-Object { $_.Key -eq 'user.name' }
            $userNameCall.Value | Should -Be "testuser"
            $userNameCall.Level | Should -Be "Local"
        }
        
        It "Should set user email when provided" {
            & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" -UserEmail "test@example.com" -WhatIf
            
            $userEmailCall = $script:MockCalls['Set-GitConfiguration'] | Where-Object { $_.Key -eq 'user.email' }
            $userEmailCall.Value | Should -Be "test@example.com"
            $userEmailCall.Level | Should -Be "Local"
        }
        
        It "Should use Global level when Global switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" -UserName "testuser" -Global -WhatIf
            
            $userNameCall = $script:MockCalls['Set-GitConfiguration'] | Where-Object { $_.Key -eq 'user.name' }
            $userNameCall.Level | Should -Be "Global"
        }
    }
    
    Context "WhatIf Support" {
        It "Should show git operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1" -UserName "test" -WhatIf
            
            # Should not actually call git config in whatif mode
            Should -Not -Invoke git -ParameterFilter { $arguments[0] -eq 'config' }
        }
    }
}
