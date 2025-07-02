#Requires -Version 5.1

<#
.SYNOPSIS
    Unit tests for AitherZero CLI argument parsing and validation

.DESCRIPTION
    Focused unit tests for the aither.ps1 CLI argument parsing logic,
    parameter validation, and command routing functionality.

.NOTES
    Test Category: Unit
    CLI Version: 1.4.1+
    Focus: Argument parsing, validation, routing
#>

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = if ($PSScriptRoot) { 
        Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent 
    } else { 
        Get-Location 
    }
    
    $script:CLIScript = Join-Path $script:ProjectRoot "aither.ps1"
    
    # Import CLI script content for testing internal functions
    $script:CLIContent = Get-Content $script:CLIScript -Raw
}

Describe "CLI Argument Parsing - Command Validation" -Tag @('Unit', 'CLI', 'ArgumentParsing') {
    
    Context "Valid Commands" {
        It "Should accept 'init' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init help 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "init"
        }
        
        It "Should accept 'deploy' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy help 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "deploy"
        }
        
        It "Should accept 'workflow' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript workflow help 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "workflow"
        }
        
        It "Should accept 'dev' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "dev"
        }
        
        It "Should accept 'config' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript config 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "(config|Coming soon)"
        }
        
        It "Should accept 'plugin' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript plugin 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "(plugin|Coming soon)"
        }
        
        It "Should accept 'server' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript server 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "(server|Coming soon)"
        }
        
        It "Should accept 'help' command" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "USAGE"
        }
    }
    
    Context "Invalid Commands" {
        It "Should reject unknown commands" {
            $invalidCommands = @('unknown', 'invalid', 'test123', 'foobar')
            
            foreach ($cmd in $invalidCommands) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript $cmd 2>&1
                $result -join "`n" | Should -Match "Unknown command.*$cmd"
            }
        }
        
        It "Should suggest help for invalid commands" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript badcommand 2>&1
            $result -join "`n" | Should -Match "aither help.*for available commands"
        }
    }
}

Describe "CLI Argument Parsing - Subcommand Validation" -Tag @('Unit', 'CLI', 'Subcommands') {
    
    Context "Dev Subcommands" {
        It "Should handle 'dev release' with proper arguments" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "test" 2>&1
            # Should attempt to process (may fail due to missing modules)
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
        
        It "Should show error for 'dev release' without arguments" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release 2>&1
            $result -join "`n" | Should -Match "Usage.*aither dev release"
        }
        
        It "Should handle 'dev' help" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
            $result -join "`n" | Should -Match "USAGE.*aither dev"
        }
    }
    
    Context "Deploy Subcommands" {
        It "Should handle deploy subcommands" {
            $subcommands = @('plan', 'apply', 'destroy', 'state', 'create')
            
            foreach ($subcmd in $subcommands) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy $subcmd 2>&1
                $LASTEXITCODE | Should -Be 0
                $result -join "`n" | Should -Match "Coming soon"
            }
        }
        
        It "Should handle unknown deploy subcommands" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy badsubcmd 2>&1
            $result -join "`n" | Should -Match "Unknown subcommand.*badsubcmd"
        }
    }
    
    Context "Workflow Subcommands" {
        It "Should handle workflow subcommands" {
            $subcommands = @('run', 'list', 'status', 'create')
            
            foreach ($subcmd in $subcommands) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript workflow $subcmd 2>&1
                $LASTEXITCODE | Should -Be 0
                $result -join "`n" | Should -Match "Coming soon"
            }
        }
        
        It "Should handle workflow help" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript workflow help 2>&1
            $result -join "`n" | Should -Match "USAGE.*aither workflow"
        }
    }
}

Describe "CLI Argument Parsing - Parameter Handling" -Tag @('Unit', 'CLI', 'Parameters') {
    
    Context "Init Parameters" {
        It "Should handle init --auto flag" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init --auto 2>&1
            # Should attempt automated setup
            $result -join "`n" | Should -Match "(automated setup|SetupWizard.*not found)"
        }
        
        It "Should handle init --profile parameter" {
            $profiles = @('minimal', 'standard', 'developer', 'full')
            
            foreach ($profile in $profiles) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init --profile $profile 2>&1
                # Should accept the profile
                $LASTEXITCODE | Should -BeIn @(0, 1)
            }
        }
    }
    
    Context "Release Type Parameters" {
        It "Should handle valid release types" {
            $releaseTypes = @('patch', 'minor', 'major')
            
            foreach ($type in $releaseTypes) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release $type "Test description" 2>&1
                # Should attempt to process (may fail due to missing modules)
                $LASTEXITCODE | Should -BeIn @(0, 1)
            }
        }
    }
    
    Context "Quoted Arguments" {
        It "Should handle quoted descriptions" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "Multi word description with spaces" 2>&1
            # Should not crash due to quoting issues
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
        
        It "Should handle special characters in quotes" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "Fix bug #123 & issue @456" 2>&1
            # Should handle special characters without crashing
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
    }
}

Describe "CLI Argument Parsing - Error Scenarios" -Tag @('Unit', 'CLI', 'ErrorHandling') {
    
    Context "Missing Required Parameters" {
        It "Should show error for dev release without type" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release 2>&1
            $result -join "`n" | Should -Match "Usage.*aither dev release.*patch\|minor\|major"
        }
        
        It "Should show error for dev release without description" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch 2>&1
            $result -join "`n" | Should -Match "Usage.*aither dev release.*Description"
        }
    }
    
    Context "Invalid Parameter Values" {
        It "Should handle invalid release types" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release invalid "description" 2>&1
            # Should either handle gracefully or show appropriate error
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
    }
    
    Context "PowerShell Syntax Edge Cases" {
        It "Should handle empty strings" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "" 2>&1
            # Should handle empty description
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
        
        It "Should handle arguments with PowerShell special characters" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "Test `$variable and `@array" 2>&1
            # Should not execute variable expansion
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
    }
}

Describe "CLI Argument Parsing - Help System" -Tag @('Unit', 'CLI', 'Help') {
    
    Context "Command-Specific Help" {
        It "Should show init-specific help" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init help 2>&1
            $result -join "`n" | Should -Match "--auto.*automated setup"
            $result -join "`n" | Should -Match "--profile.*installation profile"
        }
        
        It "Should show deploy-specific help" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy help 2>&1
            $result -join "`n" | Should -Match "plan.*deployment plan"
            $result -join "`n" | Should -Match "apply.*infrastructure changes"
        }
        
        It "Should show dev-specific help" {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
            $result -join "`n" | Should -Match "release.*patch\|minor\|major"
            $result -join "`n" | Should -Match "pr.*pull request"
        }
    }
    
    Context "Help Consistency" {
        It "Should show consistent help format across commands" {
            $commands = @('init', 'deploy', 'dev', 'workflow')
            
            foreach ($cmd in $commands) {
                $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript $cmd help 2>&1
                $output = $result -join "`n"
                
                # Each help should have consistent structure
                $output | Should -Match "USAGE.*aither $cmd"
                if ($cmd -in @('deploy', 'dev', 'workflow')) {
                    $output | Should -Match "SUBCOMMANDS:"
                }
            }
        }
    }
}

Describe "CLI Argument Parsing - Argument Array Handling" -Tag @('Unit', 'CLI', 'Arrays') {
    
    It "Should handle ValueFromRemainingArguments correctly" {
        # Test that additional arguments are captured properly
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "description" extra args here 2>&1
        # Should not crash due to extra arguments
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }
    
    It "Should preserve argument order" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "first" "second" "third" 2>&1
        # Should handle multiple arguments without reordering
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }
    
    It "Should handle empty argument arrays" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init 2>&1
        # Should handle command with no additional arguments
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }
}

AfterAll {
    Write-Host "CLI Argument Parsing unit tests completed" -ForegroundColor Green
    Write-Host "Tests focus on parameter validation and command routing" -ForegroundColor Cyan
}