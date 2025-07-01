#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Import-ProjectModule'
}

Describe 'Logging.Import-ProjectModule' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original environment variables
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalModulesPath = $env:PWSH_MODULES_PATH
        
        # Set test environment
        $script:TestModulesPath = Join-Path $TestDrive 'modules'
        New-Item -Path $script:TestModulesPath -ItemType Directory -Force | Out-Null
        $env:PWSH_MODULES_PATH = $script:TestModulesPath
    }
    
    AfterAll {
        # Restore environment variables
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:PWSH_MODULES_PATH = $script:OriginalModulesPath
        
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Clear PROJECT_ROOT for some tests
        $env:PROJECT_ROOT = $null
        
        # Mock Write-Host and Write-Error
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Write-Error { } -ModuleName $script:ModuleName
        Mock Import-Module { } -ModuleName $script:ModuleName
    }
    
    Context 'Parameter Validation' {
        It 'Should require ModuleName parameter' {
            { Import-ProjectModule } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed'
        }
        
        It 'Should accept ModuleName as positional parameter' {
            { Import-ProjectModule "TestModule" } | Should -Not -Throw
        }
        
        It 'Should accept Force switch' {
            { Import-ProjectModule -ModuleName "TestModule" -Force } | Should -Not -Throw
        }
        
        It 'Should accept ShowDetails switch' {
            { Import-ProjectModule -ModuleName "TestModule" -ShowDetails } | Should -Not -Throw
        }
        
        It 'Should accept all parameters together' {
            { Import-ProjectModule -ModuleName "TestModule" -Force -ShowDetails } | Should -Not -Throw
        }
    }
    
    Context 'Environment Setup' {
        It 'Should set PROJECT_ROOT if not already set' {
            $env:PROJECT_ROOT = $null
            Mock Get-Location { [PSCustomObject]@{ Path = 'C:\TestProject' } } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "TestModule"
            
            $env:PROJECT_ROOT | Should -Be 'C:\TestProject'
        }
        
        It 'Should not override existing PROJECT_ROOT' {
            $env:PROJECT_ROOT = 'C:\ExistingProject'
            Mock Get-Location { [PSCustomObject]@{ Path = 'C:\NewProject' } } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "TestModule"
            
            $env:PROJECT_ROOT | Should -Be 'C:\ExistingProject'
        }
        
        It 'Should show PROJECT_ROOT setup message when ShowDetails is enabled' {
            $env:PROJECT_ROOT = $null
            Mock Get-Location { [PSCustomObject]@{ Path = 'C:\TestPath' } } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "TestModule" -ShowDetails
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match "Setting PROJECT_ROOT to" -and
                $ForegroundColor -eq "Yellow"
            }
        }
    }
    
    Context 'Module Import' {
        It 'Should construct correct module path' {
            $env:PWSH_MODULES_PATH = 'C:\Modules'
            
            Import-ProjectModule -ModuleName "TestModule"
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq (Join-Path 'C:\Modules' 'TestModule')
            }
        }
        
        It 'Should use ErrorAction Stop' {
            Import-ProjectModule -ModuleName "TestModule"
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $ErrorAction -eq 'Stop'
            }
        }
        
        It 'Should pass Force parameter when specified' {
            Import-ProjectModule -ModuleName "TestModule" -Force
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Force -eq $true
            }
        }
        
        It 'Should not pass Force parameter when not specified' {
            Import-ProjectModule -ModuleName "TestModule"
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('Force')
            }
        }
        
        It 'Should pass Verbose parameter when ShowDetails is specified' {
            Import-ProjectModule -ModuleName "TestModule" -ShowDetails
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Verbose -eq $true
            }
        }
    }
    
    Context 'Success Handling' {
        It 'Should return true on successful import' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            
            $result = Import-ProjectModule -ModuleName "TestModule"
            
            $result | Should -Be $true
        }
        
        It 'Should show success message when ShowDetails is enabled' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "TestModule" -ShowDetails
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match "✅ Successfully imported module: TestModule" -and
                $ForegroundColor -eq "Green"
            }
        }
        
        It 'Should not show success message when ShowDetails is not enabled' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            Mock Write-Host { } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "TestModule"
            
            Should -Not -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match "Successfully imported"
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should return false on import failure' {
            Mock Import-Module { throw "Module not found" } -ModuleName $script:ModuleName
            
            $result = Import-ProjectModule -ModuleName "NonExistentModule"
            
            $result | Should -Be $false
        }
        
        It 'Should write error message on failure' {
            Mock Import-Module { throw "Test error" } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "FailModule"
            
            Should -Invoke Write-Error -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Failed to import module 'FailModule'" -and
                $Message -match "Test error"
            }
        }
        
        It 'Should handle different error types gracefully' {
            $errorTypes = @(
                [System.IO.FileNotFoundException]::new("File not found"),
                [System.UnauthorizedAccessException]::new("Access denied"),
                [System.Exception]::new("Generic error")
            )
            
            foreach ($error in $errorTypes) {
                Mock Import-Module { throw $error } -ModuleName $script:ModuleName
                
                { Import-ProjectModule -ModuleName "ErrorModule" } | Should -Not -Throw
                Import-ProjectModule -ModuleName "ErrorModule" | Should -Be $false
            }
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        It 'Should use Join-Path for path construction' {
            $env:PWSH_MODULES_PATH = if ($IsWindows) { 'C:\Modules' } else { '/usr/modules' }
            
            Import-ProjectModule -ModuleName "CrossPlatform"
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $expectedPath = Join-Path $env:PWSH_MODULES_PATH "CrossPlatform"
                $Name -eq $expectedPath
            }
        }
        
        It 'Should handle paths with spaces' {
            $env:PWSH_MODULES_PATH = Join-Path $TestDrive 'Program Files\Modules'
            New-Item -Path $env:PWSH_MODULES_PATH -ItemType Directory -Force | Out-Null
            
            Import-ProjectModule -ModuleName "SpacedModule"
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq (Join-Path $env:PWSH_MODULES_PATH "SpacedModule")
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle module names with special characters' {
            $specialNames = @(
                "Module-With-Dashes",
                "Module.With.Dots",
                "Module_With_Underscores"
            )
            
            foreach ($name in $specialNames) {
                { Import-ProjectModule -ModuleName $name } | Should -Not -Throw
            }
        }
        
        It 'Should handle empty PWSH_MODULES_PATH gracefully' {
            $env:PWSH_MODULES_PATH = ""
            
            { Import-ProjectModule -ModuleName "TestModule" } | Should -Not -Throw
        }
        
        It 'Should handle null PWSH_MODULES_PATH' {
            $env:PWSH_MODULES_PATH = $null
            
            { Import-ProjectModule -ModuleName "TestModule" } | Should -Not -Throw
        }
        
        It 'Should handle very long module names' {
            $longName = "Module" + ("A" * 200)
            
            { Import-ProjectModule -ModuleName $longName } | Should -Not -Throw
        }
    }
    
    Context 'Multiple Calls' {
        It 'Should handle importing same module multiple times' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            
            $result1 = Import-ProjectModule -ModuleName "SameModule"
            $result2 = Import-ProjectModule -ModuleName "SameModule"
            
            $result1 | Should -Be $true
            $result2 | Should -Be $true
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -Times 2
        }
        
        It 'Should force reload when Force is specified' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            
            Import-ProjectModule -ModuleName "ReloadModule"
            Import-ProjectModule -ModuleName "ReloadModule" -Force
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('Force')
            }
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }
    }
}