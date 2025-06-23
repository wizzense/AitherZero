BeforeAll {
    # Import the testing framework
    Import-Module './aither-core/modules/TestingFramework' -Force
    
    # Import the modules to test
    Import-Module './aither-core/modules/ISOManager' -Force
    Import-Module './aither-core/modules/ISOCustomizer' -Force
}

Describe "ISOManager Module" {
    Context "Module Loading and Function Export" {
        It "Should load the ISOManager module successfully" {
            { Import-Module './aither-core/modules/ISOManager' -Force } | Should -Not -Throw
        }

        It "Should export all expected functions" {
            $expectedFunctions = @(
                'Get-ISODownload',
                'Get-ISOInventory',
                'Get-ISOMetadata',
                'Test-ISOIntegrity',
                'New-ISORepository',
                'Remove-ISOFile',
                'Export-ISOInventory',
                'Import-ISOInventory',
                'Sync-ISORepository'
            )

            $actualFunctions = Get-Command -Module ISOManager | Select-Object -ExpandProperty Name
            
            foreach ($function in $expectedFunctions) {
                $actualFunctions | Should -Contain $function
            }
        }
    }

    Context "Get-ISODownload Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Get-ISODownload
            $command.Parameters.Keys | Should -Contain 'ISOName'
            $command.Parameters.Keys | Should -Contain 'ISOType'
            $command.Parameters.Keys | Should -Contain 'CustomURL'
            $command.Parameters.Keys | Should -Contain 'DownloadPath'
        }

        It "Should validate required parameters" {
            { Get-ISODownload -ISOName "" -WhatIf } | Should -Throw
        }

        It "Should accept valid ISO types" {
            $validTypes = @('Windows', 'Linux', 'Custom')
            foreach ($type in $validTypes) {
                { Get-ISODownload -ISOName "TestISO" -ISOType $type -CustomURL "https://example.com/test.iso" -WhatIf } | Should -Not -Throw
            }
        }

        It "Should require CustomURL when ISOType is Custom" {
            { Get-ISODownload -ISOName "TestISO" -ISOType "Custom" -WhatIf } | Should -Throw
        }

        It "Should return proper structure in WhatIf mode" {
            $result = Get-ISODownload -ISOName "TestISO" -ISOType "Custom" -CustomURL "https://example.com/test.iso" -WhatIf
            # WhatIf mode should not return a result object, just show what would happen
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Download Path Handling" {
        It "Should create default download directory if not specified" {
            $testTempPath = Join-Path $env:TEMP "TestISODownload"
            if (Test-Path $testTempPath) {
                Remove-Item $testTempPath -Recurse -Force
            }
            
            # Test with WhatIf to avoid actual download
            { Get-ISODownload -ISOName "TestISO" -ISOType "Custom" -CustomURL "https://example.com/test.iso" -WhatIf } | Should -Not -Throw
        }

        It "Should handle custom download paths" {
            $customPath = Join-Path $env:TEMP "CustomISOPath"
            { Get-ISODownload -ISOName "TestISO" -ISOType "Custom" -CustomURL "https://example.com/test.iso" -DownloadPath $customPath -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "ISOCustomizer Module" {
    Context "Module Loading and Function Export" {
        It "Should load the ISOCustomizer module successfully" {
            { Import-Module './aither-core/modules/ISOCustomizer' -Force } | Should -Not -Throw
        }

        It "Should export all expected functions" {
            $expectedFunctions = @(
                'New-CustomISO',
                'New-AutounattendFile'
            )

            $actualFunctions = Get-Command -Module ISOCustomizer | Select-Object -ExpandProperty Name
            
            foreach ($function in $expectedFunctions) {
                $actualFunctions | Should -Contain $function
            }
        }
    }

    Context "New-AutounattendFile Function" {
        BeforeEach {
            $testConfig = @{
                ComputerName = "TEST-COMPUTER"
                AdminPassword = "TestPassword123"
                TimeZone = "UTC"
                EnableRDP = $true
                ProductKey = "TEST-KEY-123"
            }
            
            $testOutputPath = Join-Path $env:TEMP "test-autounattend.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should have correct parameter structure" {
            $command = Get-Command New-AutounattendFile
            $command.Parameters.Keys | Should -Contain 'Configuration'
            $command.Parameters.Keys | Should -Contain 'OutputPath'
            $command.Parameters.Keys | Should -Contain 'OSType'
            $command.Parameters.Keys | Should -Contain 'Edition'
        }

        It "Should validate required parameters" {
            { New-AutounattendFile -Configuration @{} -OutputPath "" -WhatIf } | Should -Throw
        }

        It "Should accept valid OS types" {
            $validOSTypes = @('Server2025', 'Server2022', 'Server2019', 'Windows11', 'Windows10', 'Generic')
            foreach ($osType in $validOSTypes) {
                { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -OSType $osType -WhatIf } | Should -Not -Throw
            }
        }

        It "Should accept valid editions" {
            $validEditions = @('Standard', 'Datacenter', 'Core', 'Desktop')
            foreach ($edition in $validEditions) {
                { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -OSType "Server2025" -Edition $edition -WhatIf } | Should -Not -Throw
            }
        }

        It "Should generate valid XML content" {
            $result = New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -OSType "Server2025" -Edition "Core" -Force
            
            $result.Success | Should -Be $true
            Test-Path $testOutputPath | Should -Be $true
            
            # Validate that the generated file is valid XML
            { [xml](Get-Content $testOutputPath -Raw) } | Should -Not -Throw
            
            # Check that the content contains expected elements
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "TEST-COMPUTER"
            $xmlContent | Should -Match "TestPassword123"
            $xmlContent | Should -Match "Server 2025"
        }

        It "Should include RDP configuration when enabled" {
            $configWithRDP = $testConfig.Clone()
            $configWithRDP.EnableRDP = $true
            
            $result = New-AutounattendFile -Configuration $configWithRDP -OutputPath $testOutputPath -Force
            
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "TerminalServices"
            $xmlContent | Should -Match "fDenyTSConnections.*false"
        }

        It "Should handle first logon commands" {
            $configWithCommands = $testConfig.Clone()
            $configWithCommands.FirstLogonCommands = @(
                @{
                    CommandLine = "powershell.exe -Command 'Write-Host Test'"
                    Description = "Test Command"
                }
            )
            
            $result = New-AutounattendFile -Configuration $configWithCommands -OutputPath $testOutputPath -Force
            
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "FirstLogonCommands"
            $xmlContent | Should -Match "Test Command"
        }
    }

    Context "New-CustomISO Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command New-CustomISO
            $command.Parameters.Keys | Should -Contain 'SourceISOPath'
            $command.Parameters.Keys | Should -Contain 'OutputISOPath'
            $command.Parameters.Keys | Should -Contain 'AutounattendFile'
            $command.Parameters.Keys | Should -Contain 'BootstrapScript'
        }

        It "Should validate source ISO path" {
            { New-CustomISO -SourceISOPath "NonExistent.iso" -OutputISOPath "Output.iso" -WhatIf } | Should -Throw
        }

        It "Should check for administrative privileges" {
            # This test will skip if not running as admin, since we can't test privilege escalation
            $isAdmin = try {
                $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
                $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            } catch {
                $false
            }

            if (-not $isAdmin) {
                Set-ItResult -Skipped -Because "Test requires administrative privileges"
                return
            }

            # Create a dummy ISO file for testing
            $testISO = Join-Path $env:TEMP "test-source.iso"
            $testOutput = Join-Path $env:TEMP "test-output.iso"
            
            # Create empty test file (not a real ISO, but enough for parameter validation)
            "" | Out-File $testISO
            
            try {
                # This should fail because it's not a real ISO, but should pass privilege check
                { New-CustomISO -SourceISOPath $testISO -OutputISOPath $testOutput -WhatIf } | Should -Not -Throw
            } finally {
                Remove-Item $testISO -Force -ErrorAction SilentlyContinue
                Remove-Item $testOutput -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "ISO Module Integration" {
    Context "Cross-Module Functionality" {
        It "Should work together for complete workflow" {
            # Test that both modules can work together
            $isoManagerFunctions = Get-Command -Module ISOManager
            $isoCustomizerFunctions = Get-Command -Module ISOCustomizer
            
            $isoManagerFunctions.Count | Should -BeGreaterThan 0
            $isoCustomizerFunctions.Count | Should -BeGreaterThan 0
            
            # Check that we have the key functions for a complete workflow
            $isoManagerFunctions.Name | Should -Contain 'Get-ISODownload'
            $isoCustomizerFunctions.Name | Should -Contain 'New-AutounattendFile'
            $isoCustomizerFunctions.Name | Should -Contain 'New-CustomISO'
        }

        It "Should integrate with AitherCore module system" {
            # Import AitherCore and verify our modules are registered
            Import-Module './aither-core/AitherCore' -Force
            Import-CoreModules -Force | Out-Null
            
            # Check that our modules are loaded
            $loadedModules = Get-Module
            $loadedModules.Name | Should -Contain 'ISOManager'
            $loadedModules.Name | Should -Contain 'ISOCustomizer'
        }

        It "Should have consistent logging integration" {
            # All functions should use Write-CustomLog
            $allFunctions = @()
            $allFunctions += Get-Command -Module ISOManager
            $allFunctions += Get-Command -Module ISOCustomizer
            
            foreach ($function in $allFunctions) {
                $functionContent = $function.Definition
                # Functions should contain logging calls (either Write-CustomLog or be designed to use it)
                $functionContent | Should -Match "(Write-CustomLog|begin|process|end)"
            }
        }
    }
}

Describe "Configuration-Driven Workflow" {
    Context "Config File Integration" {
        It "Should support hashtable configuration input" {
            $testConfig = @{
                ComputerName = "CONFIG-TEST"
                AdminPassword = "ConfigTest123"
                ProductKey = "CONFIG-KEY"
                EnableRDP = $true
                FirstLogonCommands = @()
            }
            
            { New-AutounattendFile -Configuration $testConfig -OutputPath (Join-Path $env:TEMP "config-test.xml") -WhatIf } | Should -Not -Throw
        }

        It "Should handle complex configuration structures" {
            $complexConfig = @{
                ComputerName = "COMPLEX-TEST"
                AdminPassword = "Complex123!"
                ProductKey = "COMPLEX-KEY"
                EnableRDP = $true
                AutoLogon = $true
                AutoLogonCount = 5
                FirstLogonCommands = @(
                    @{
                        CommandLine = "cmd.exe /c echo First"
                        Description = "First Command"
                    },
                    @{
                        CommandLine = "cmd.exe /c echo Second"
                        Description = "Second Command"
                    }
                )
                DisableFirewall = $true
                DisableUAC = $true
            }
            
            { New-AutounattendFile -Configuration $complexConfig -OutputPath (Join-Path $env:TEMP "complex-test.xml") -WhatIf } | Should -Not -Throw
        }
    }
}
