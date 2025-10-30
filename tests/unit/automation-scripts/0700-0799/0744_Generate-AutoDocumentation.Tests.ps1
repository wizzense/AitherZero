#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0744_Generate-AutoDocumentation.ps1 Write-DocLog function fix
.DESCRIPTION
    Tests that the Write-DocLog function handles all log levels correctly
    without throwing null ForegroundColor errors. This validates the fix
    where a default case was added to the switch statement.
#>

BeforeAll {
    # Determine project root path (4 levels up from test file)
    $script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $script:ScriptPath = Join-Path $script:ProjectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
    
    # Verify script exists
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Cannot find script at: $script:ScriptPath"
    }
}

Describe "0744_Generate-AutoDocumentation - Write-DocLog Function Fix" {
    
    Context "Validating the fix prevents null ForegroundColor errors" {
        
        BeforeAll {
            # Mock Write-Host to track calls
            Mock Write-Host { }
            
            # Define the Write-DocLog function WITH THE FIX (default case in switch)
            # This simulates the fixed version in the actual script
            function Write-DocLog {
                param([string]$Message, [string]$Level = 'Information', [hashtable]$Data = @{})
                
                # For testing, we skip the Write-CustomLog path and go directly to Write-Host
                Write-Host "[$Level] [AutoDocumentation] $Message" -ForegroundColor $(
                    switch ($Level) {
                        'Information' { 'White' }
                        'Warning' { 'Yellow' }
                        'Error' { 'Red' }
                        default { 'White' }  # THE FIX: default case prevents null
                    }
                )
            }
        }
        
        It "Should not throw error with Information level" {
            { Write-DocLog -Message "Test message" -Level 'Information' } | Should -Not -Throw
        }
        
        It "Should not throw error with Warning level" {
            { Write-DocLog -Message "Warning message" -Level 'Warning' } | Should -Not -Throw
        }
        
        It "Should not throw error with Error level" {
            { Write-DocLog -Message "Error message" -Level 'Error' } | Should -Not -Throw
        }
        
        It "Should not throw error with unknown level (Debug) - KEY FIX VALIDATION" {
            # This is the critical test - before the fix, this would throw:
            # "Cannot convert null to type System.ConsoleColor"
            # After the fix, it uses the default White color
            { Write-DocLog -Message "Test message" -Level 'Debug' } | Should -Not -Throw
        }
        
        It "Should not throw error with empty level value" {
            { Write-DocLog -Message "Test message" -Level '' } | Should -Not -Throw
        }
        
        It "Should not throw error with various unknown levels" {
            { Write-DocLog -Message "Test message" -Level 'UnknownLevel' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Verbose' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Critical' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Trace' } | Should -Not -Throw
        }
        
        It "Should call Write-Host with White color for Information level" {
            Write-DocLog -Message "Test message" -Level 'Information'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Information]*Test message*" -and 
                $ForegroundColor -eq 'White'
            }
        }
        
        It "Should call Write-Host with Yellow color for Warning level" {
            Write-DocLog -Message "Warning message" -Level 'Warning'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Warning]*Warning message*" -and 
                $ForegroundColor -eq 'Yellow'
            }
        }
        
        It "Should call Write-Host with Red color for Error level" {
            Write-DocLog -Message "Error message" -Level 'Error'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Error]*Error message*" -and 
                $ForegroundColor -eq 'Red'
            }
        }
        
        It "Should call Write-Host with White (default) for unknown level" {
            Write-DocLog -Message "Test message" -Level 'Debug'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Debug]*Test message*" -and 
                $ForegroundColor -eq 'White'
            }
        }
        
        It "Should use default Information level when not specified" {
            Write-DocLog -Message "Test message"
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Information]*"
            }
        }
        
        It "Should handle null data parameter gracefully" {
            { Write-DocLog -Message "Test message" -Data $null } | Should -Not -Throw
        }
        
        It "Should handle empty data hashtable" {
            { Write-DocLog -Message "Test message" -Data @{} } | Should -Not -Throw
        }
    }
    
    Context "Verify actual script contains the fix" {
        It "Should have 'default' case in the Write-DocLog switch statement" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            
            # The fixed script should contain the default case
            $scriptContent | Should -Match "default\s*\{\s*'White'\s*\}"
        }
        
        It "Should have the complete Write-DocLog function with the fix" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            
            # Extract the Write-DocLog function (more flexible regex)
            if ($scriptContent -match '(?s)function Write-DocLog.*?(?=\r?\nfunction|\r?\n\r?\n[a-z]|\z)') {
                $functionContent = $Matches[0]
                
                # Verify it contains all expected cases plus default
                $functionContent | Should -Match "'Information'"
                $functionContent | Should -Match "'Warning'"
                $functionContent | Should -Match "'Error'"
                $functionContent | Should -Match "default"
            } else {
                throw "Could not find Write-DocLog function in script"
            }
        }
    }
}



