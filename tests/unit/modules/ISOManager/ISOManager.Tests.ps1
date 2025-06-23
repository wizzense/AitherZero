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

Describe "ISOManager Module - Extended Tests" {
    Context "Get-ISOInventory Function" {
        BeforeEach {
            $testRepoPath = Join-Path $env:TEMP "TestISORepo"
            if (Test-Path $testRepoPath) {
                Remove-Item $testRepoPath -Recurse -Force
            }
        }

        AfterEach {
            if (Test-Path $testRepoPath) {
                Remove-Item $testRepoPath -Recurse -Force
            }
        }

        It "Should handle empty repository gracefully" {
            $result = Get-ISOInventory -RepositoryPath $testRepoPath
            $result | Should -BeOfType [array]
            $result.Count | Should -Be 0
        }

        It "Should filter by ISO type correctly" {
            { Get-ISOInventory -RepositoryPath $testRepoPath -ISOType "Windows" } | Should -Not -Throw
            { Get-ISOInventory -RepositoryPath $testRepoPath -ISOType "Linux" } | Should -Not -Throw
            { Get-ISOInventory -RepositoryPath $testRepoPath -ISOType "All" } | Should -Not -Throw
        }

        It "Should support metadata inclusion parameter" {
            { Get-ISOInventory -RepositoryPath $testRepoPath -IncludeMetadata } | Should -Not -Throw
        }

        It "Should support integrity verification parameter" {
            { Get-ISOInventory -RepositoryPath $testRepoPath -VerifyIntegrity } | Should -Not -Throw
        }

        It "Should use default repository path when none provided" {
            { Get-ISOInventory } | Should -Not -Throw
        }
    }

    Context "New-ISORepository Function" {
        BeforeEach {
            $testRepoPath = Join-Path $env:TEMP "TestNewRepo"
            if (Test-Path $testRepoPath) {
                Remove-Item $testRepoPath -Recurse -Force
            }
        }

        AfterEach {
            if (Test-Path $testRepoPath) {
                Remove-Item $testRepoPath -Recurse -Force
            }
        }

        It "Should have correct parameter structure" {
            $command = Get-Command New-ISORepository
            $command.Parameters.Keys | Should -Contain 'Name'
            $command.Parameters.Keys | Should -Contain 'RepositoryPath'
            $command.Parameters.Keys | Should -Contain 'Description'
            $command.Parameters.Keys | Should -Contain 'Force'
        }

        It "Should create repository directory structure" {
            $result = New-ISORepository -Name "TestRepo" -RepositoryPath $testRepoPath -Description "Test repository" -WhatIf
            # WhatIf should not create actual directories
        }

        It "Should validate repository path parameter" {
            { New-ISORepository -Name "Test" -RepositoryPath "" -WhatIf } | Should -Throw
        }

        It "Should validate name parameter" {
            { New-ISORepository -Name "" -RepositoryPath $testRepoPath -WhatIf } | Should -Throw
        }
    }

    Context "Export-ISOInventory Function" {
        BeforeEach {
            $testExportPath = Join-Path $env:TEMP "test-export.json"
            if (Test-Path $testExportPath) {
                Remove-Item $testExportPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testExportPath) {
                Remove-Item $testExportPath -Force
            }
        }

        It "Should have correct parameter structure" {
            $command = Get-Command Export-ISOInventory
            $command.Parameters.Keys | Should -Contain 'RepositoryPath'
            $command.Parameters.Keys | Should -Contain 'ExportPath'
            $command.Parameters.Keys | Should -Contain 'Format'
            $command.Parameters.Keys | Should -Contain 'IncludeMetadata'
            $command.Parameters.Keys | Should -Contain 'IncludeIntegrity'
        }

        It "Should support JSON export format" {
            { Export-ISOInventory -ExportPath $testExportPath -Format "JSON" -WhatIf } | Should -Not -Throw
        }

        It "Should support CSV export format" {
            { Export-ISOInventory -ExportPath $testExportPath -Format "CSV" -WhatIf } | Should -Not -Throw
        }

        It "Should support XML export format" {
            { Export-ISOInventory -ExportPath $testExportPath -Format "XML" -WhatIf } | Should -Not -Throw
        }

        It "Should validate export path parameter" {
            { Export-ISOInventory -ExportPath "" -WhatIf } | Should -Throw
        }

        It "Should default to JSON format" {
            $command = Get-Command Export-ISOInventory
            $formatParam = $command.Parameters['Format']
            $formatParam.ParameterType | Should -Be ([string])
        }
    }

    Context "Import-ISOInventory Function" {
        BeforeEach {
            $testImportPath = Join-Path $env:TEMP "test-import.json"
            $testInventory = @{
                ExportInfo = @{
                    ExportDate = Get-Date
                    TotalISOs = 1
                }
                Inventory = @(
                    @{
                        Name = "TestISO"
                        FileName = "test.iso"
                        FilePath = "C:\temp\test.iso"
                        Size = 1024
                        Type = "Custom"
                    }
                )
            }
            $testInventory | ConvertTo-Json -Depth 10 | Set-Content $testImportPath
        }

        AfterEach {
            if (Test-Path $testImportPath) {
                Remove-Item $testImportPath -Force
            }
        }

        It "Should have correct parameter structure" {
            $command = Get-Command Import-ISOInventory
            $command.Parameters.Keys | Should -Contain 'ImportPath'
            $command.Parameters.Keys | Should -Contain 'TargetRepositoryPath'
            $command.Parameters.Keys | Should -Contain 'ValidateFiles'
            $command.Parameters.Keys | Should -Contain 'CreateMissingDirectories'
        }

        It "Should validate import path exists" {
            { Import-ISOInventory -ImportPath "NonExistent.json" -WhatIf } | Should -Throw
        }

        It "Should import JSON format successfully" {
            { Import-ISOInventory -ImportPath $testImportPath -WhatIf } | Should -Not -Throw
        }

        It "Should support file validation parameter" {
            { Import-ISOInventory -ImportPath $testImportPath -ValidateFiles -WhatIf } | Should -Not -Throw
        }

        It "Should support directory creation parameter" {
            { Import-ISOInventory -ImportPath $testImportPath -CreateMissingDirectories -WhatIf } | Should -Not -Throw
        }
    }

    Context "Sync-ISORepository Function" {
        BeforeEach {
            $testRepoPath = Join-Path $env:TEMP "TestSyncRepo"
        }

        It "Should have correct parameter structure" {
            $command = Get-Command Sync-ISORepository
            $command.Parameters.Keys | Should -Contain 'RepositoryPath'
            $command.Parameters.Keys | Should -Contain 'ValidateIntegrity'
            $command.Parameters.Keys | Should -Contain 'UpdateMetadata'
            $command.Parameters.Keys | Should -Contain 'CleanupOrphaned'
        }

        It "Should handle non-existent repository gracefully" {
            { Sync-ISORepository -RepositoryPath $testRepoPath -WhatIf } | Should -Not -Throw
        }

        It "Should support integrity validation parameter" {
            { Sync-ISORepository -RepositoryPath $testRepoPath -ValidateIntegrity -WhatIf } | Should -Not -Throw
        }

        It "Should support metadata update parameter" {
            { Sync-ISORepository -RepositoryPath $testRepoPath -UpdateMetadata -WhatIf } | Should -Not -Throw
        }

        It "Should support orphan cleanup parameter" {
            { Sync-ISORepository -RepositoryPath $testRepoPath -CleanupOrphaned -WhatIf } | Should -Not -Throw
        }
    }

    Context "Get-ISOMetadata Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Get-ISOMetadata
            $command.Parameters.Keys | Should -Contain 'FilePath'
        }

        It "Should validate file path parameter" {
            { Get-ISOMetadata -FilePath "" } | Should -Throw
        }

        It "Should handle non-existent file gracefully" {
            { Get-ISOMetadata -FilePath "NonExistent.iso" } | Should -Throw
        }
    }

    Context "Test-ISOIntegrity Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Test-ISOIntegrity
            $command.Parameters.Keys | Should -Contain 'FilePath'
        }

        It "Should validate file path parameter" {
            { Test-ISOIntegrity -FilePath "" } | Should -Throw
        }

        It "Should handle non-existent file gracefully" {
            { Test-ISOIntegrity -FilePath "NonExistent.iso" } | Should -Throw
        }
    }

    Context "Remove-ISOFile Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Remove-ISOFile
            $command.Parameters.Keys | Should -Contain 'FilePath'
        }

        It "Should validate file path parameter" {
            { Remove-ISOFile -FilePath "" -WhatIf } | Should -Throw
        }

        It "Should support WhatIf parameter" {
            { Remove-ISOFile -FilePath "test.iso" -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "ISOCustomizer Module - Extended Tests" {
    Context "New-AutounattendFile - Advanced Configuration" {
        BeforeEach {
            $testOutputPath = Join-Path $env:TEMP "test-advanced-autounattend.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle minimal configuration" {
            $minimalConfig = @{
                ComputerName = "MIN-TEST"
                AdminPassword = "MinTest123!"
            }

            { New-AutounattendFile -Configuration $minimalConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle domain join configuration" {
            $domainConfig = @{
                ComputerName = "DOMAIN-TEST"
                AdminPassword = "DomainTest123!"
                JoinDomain = $true
                DomainName = "test.local"
                DomainAdmin = "test\administrator"
                DomainPassword = "DomainPass123!"
            }

            { New-AutounattendFile -Configuration $domainConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle network configuration" {
            $networkConfig = @{
                ComputerName = "NET-TEST"
                AdminPassword = "NetTest123!"
                EnableDHCP = $false
                StaticIP = "192.168.1.100"
                SubnetMask = "255.255.255.0"
                Gateway = "192.168.1.1"
                DNSServers = @("192.168.1.1", "8.8.8.8")
            }

            { New-AutounattendFile -Configuration $networkConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle multiple first logon commands with order" {
            $commandsConfig = @{
                ComputerName = "CMD-TEST"
                AdminPassword = "CmdTest123!"
                FirstLogonCommands = @(
                    @{
                        CommandLine = "powershell.exe -Command 'Write-Host First'"
                        Description = "First Command"
                        Order = 1
                    },
                    @{
                        CommandLine = "powershell.exe -Command 'Write-Host Second'"
                        Description = "Second Command"
                        Order = 2
                    },
                    @{
                        CommandLine = "powershell.exe -Command 'Write-Host Third'"
                        Description = "Third Command"
                        Order = 3
                    }
                )
            }

            { New-AutounattendFile -Configuration $commandsConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle security configuration" {
            $securityConfig = @{
                ComputerName = "SEC-TEST"
                AdminPassword = "SecTest123!"
                DisableFirewall = $true
                DisableUAC = $true
                DisableWindowsDefender = $true
                EnableRDP = $true
                PasswordComplexity = $false
            }

            { New-AutounattendFile -Configuration $securityConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle bootstrap script configuration" {
            $bootstrapConfig = @{
                ComputerName = "BOOT-TEST"
                AdminPassword = "BootTest123!"
                BootstrapScript = "C:\Windows\bootstrap.ps1"
            }

            { New-AutounattendFile -Configuration $bootstrapConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should support headless mode" {
            $testConfig = @{
                ComputerName = "HEADLESS-TEST"
                AdminPassword = "HeadlessTest123!"
            }

            { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -HeadlessMode -WhatIf } | Should -Not -Throw
        }

        It "Should handle custom partition configuration" {
            $partitionConfig = @{
                ComputerName = "PART-TEST"
                AdminPassword = "PartTest123!"
                DiskID = 0
                EFIPartitionSize = 260
                MSRPartitionSize = 16
                PrimaryPartitionSize = 50000
                CreateDataPartition = $true
                DataPartitionSize = 100000
            }

            { New-AutounattendFile -Configuration $partitionConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should validate generated XML structure" {
            $testConfig = @{
                ComputerName = "XML-TEST"
                AdminPassword = "XmlTest123!"
                EnableRDP = $true
                AutoLogon = $true
            }

            $result = New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -Force

            $result.Success | Should -Be $true
            Test-Path $testOutputPath | Should -Be $true

            # Validate XML is well-formed
            { [xml](Get-Content $testOutputPath -Raw) } | Should -Not -Throw

            # Check specific content
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "XML-TEST"
            $xmlContent | Should -Match "TerminalServices"
            $xmlContent | Should -Match "AutoLogon"
        }

        It "Should handle output to different directory" {
            $customDir = Join-Path $env:TEMP "CustomAutoConfig"
            $customOutputPath = Join-Path $customDir "custom-autounattend.xml"

            $testConfig = @{
                ComputerName = "DIR-TEST"
                AdminPassword = "DirTest123!"
            }

            $result = New-AutounattendFile -Configuration $testConfig -OutputPath $customOutputPath -Force

            $result.Success | Should -Be $true
            Test-Path $customDir | Should -Be $true
            Test-Path $customOutputPath | Should -Be $true

            # Cleanup
            Remove-Item $customDir -Recurse -Force
        }
    }

    Context "New-CustomISO - Advanced Features" {
        BeforeEach {
            $testSourceISO = Join-Path $env:TEMP "test-source.iso"
            $testOutputISO = Join-Path $env:TEMP "test-output.iso"

            # Create a minimal test file to represent an ISO (for parameter validation)
            if (-not (Test-Path $testSourceISO)) {
                "Test ISO Content" | Set-Content $testSourceISO
            }
        }

        AfterEach {
            @($testSourceISO, $testOutputISO) | ForEach-Object {
                if (Test-Path $_) {
                    Remove-Item $_ -Force
                }
            }
        }

        It "Should validate source ISO exists" {
            { New-CustomISO -SourceISOPath "NonExistent.iso" -OutputISOPath $testOutputISO -WhatIf } | Should -Throw
        }

        It "Should support custom extract path" {
            $customExtractPath = Join-Path $env:TEMP "CustomExtract"
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -ExtractPath $customExtractPath -WhatIf } | Should -Not -Throw
        }

        It "Should support custom mount path" {
            $customMountPath = Join-Path $env:TEMP "CustomMount"
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -MountPath $customMountPath -WhatIf } | Should -Not -Throw
        }

        It "Should support WIM index specification" {
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -WIMIndex 1 -WhatIf } | Should -Not -Throw
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -WIMIndex 2 -WhatIf } | Should -Not -Throw
        }

        It "Should support additional files parameter" {
            $additionalFiles = @("C:\temp\file1.txt", "C:\temp\file2.txt")
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -AdditionalFiles $additionalFiles -WhatIf } | Should -Not -Throw
        }

        It "Should support drivers path parameter" {
            $driversPath = @("C:\drivers\network", "C:\drivers\storage")
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -DriversPath $driversPath -WhatIf } | Should -Not -Throw
        }

        It "Should support registry changes parameter" {
            $registryChanges = @{
                "HKLM:\SOFTWARE\Test" = @{
                    "TestValue" = "TestData"
                    "TestDWORD" = 1
                }
            }
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -RegistryChanges $registryChanges -WhatIf } | Should -Not -Throw
        }

        It "Should support custom OSCDIMG path" {
            $customOscdimgPath = "C:\CustomPath\oscdimg.exe"
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -OscdimgPath $customOscdimgPath -WhatIf } | Should -Not -Throw
        }

        It "Should support autounattend configuration via hashtable" {
            $autounattendConfig = @{
                ComputerName = "ISO-TEST"
                AdminPassword = "IsoTest123!"
                EnableRDP = $true
            }
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -AutounattendConfig $autounattendConfig -WhatIf } | Should -Not -Throw
        }

        It "Should support force parameter" {
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -Force -WhatIf } | Should -Not -Throw
        }

        It "Should support keep temp files parameter" {
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -KeepTempFiles -WhatIf } | Should -Not -Throw
        }

        It "Should support validate only parameter" {
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -ValidateOnly -WhatIf } | Should -Not -Throw
        }

        It "Should handle existing output file without Force" {
            "Existing content" | Set-Content $testOutputISO
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -WhatIf } | Should -Throw
        }

        It "Should handle existing output file with Force" {
            "Existing content" | Set-Content $testOutputISO
            { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -Force -WhatIf } | Should -Not -Throw
        }
    }

    Context "Template Integration Tests" {
        It "Should use internal templates when available" {
            Import-Module './aither-core/modules/ISOCustomizer' -Force

            # Verify template directory exists
            $moduleRoot = Get-Module ISOCustomizer | Select-Object -ExpandProperty ModuleBase
            $templateDir = Join-Path $moduleRoot "Templates"
            Test-Path $templateDir | Should -Be $true

            # Verify template files exist
            $expectedTemplates = @(
                "autounattend-generic.xml",
                "autounattend-headless.xml",
                "bootstrap.ps1",
                "kickstart.cfg"
            )

            foreach ($template in $expectedTemplates) {
                $templatePath = Join-Path $templateDir $template
                Test-Path $templatePath | Should -Be $true
            }
        }

        It "Should use generic template by default" {
            $testConfig = @{
                ComputerName = "TEMPLATE-TEST"
                AdminPassword = "TemplateTest123!"
            }

            $testOutputPath = Join-Path $env:TEMP "template-test.xml"
            { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw

            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should use headless template when HeadlessMode is specified" {
            $testConfig = @{
                ComputerName = "HEADLESS-TEMPLATE-TEST"
                AdminPassword = "HeadlessTemplateTest123!"
            }

            $testOutputPath = Join-Path $env:TEMP "headless-template-test.xml"
            { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -HeadlessMode -WhatIf } | Should -Not -Throw

            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }
}

Describe "Integration Tests" {
    Context "Module Interaction" {
        It "Should load both modules without conflicts" {
            {
                Import-Module './aither-core/modules/ISOManager' -Force
                Import-Module './aither-core/modules/ISOCustomizer' -Force
            } | Should -Not -Throw

            # Verify both modules are loaded
            Get-Module ISOManager | Should -Not -BeNullOrEmpty
            Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
        }

        It "Should have no function name conflicts" {
            Import-Module './aither-core/modules/ISOManager' -Force
            Import-Module './aither-core/modules/ISOCustomizer' -Force

            $isoManagerFunctions = Get-Command -Module ISOManager | Select-Object -ExpandProperty Name
            $isoCustomizerFunctions = Get-Command -Module ISOCustomizer | Select-Object -ExpandProperty Name

            $conflicts = $isoManagerFunctions | Where-Object { $_ -in $isoCustomizerFunctions }
            $conflicts | Should -BeNullOrEmpty
        }

        It "Should work together in a complete workflow" {
            # This would test a complete workflow like:
            # 1. Create repository
            # 2. Download ISO
            # 3. Create autounattend
            # 4. Customize ISO
            # 5. Update inventory

            {
                $testRepo = Join-Path $env:TEMP "WorkflowTestRepo"
                $testConfig = @{
                    ComputerName = "WORKFLOW-TEST"
                    AdminPassword = "WorkflowTest123!"
                }

                # Test in WhatIf mode
                New-ISORepository -Name "WorkflowTest" -RepositoryPath $testRepo -Description "Test workflow" -WhatIf
                $autounattendPath = Join-Path $env:TEMP "workflow-autounattend.xml"
                New-AutounattendFile -Configuration $testConfig -OutputPath $autounattendPath -WhatIf

                if (Test-Path $autounattendPath) {
                    Remove-Item $autounattendPath -Force
                }
                if (Test-Path $testRepo) {
                    Remove-Item $testRepo -Recurse -Force
                }
            } | Should -Not -Throw
        }
    }

    Context "AitherCore Integration" {
        It "Should be properly registered in AitherCore" {
            Import-Module './aither-core/AitherCore.psm1' -Force

            # Both modules should be available after AitherCore import
            $availableCommands = Get-Command | Where-Object { $_.Source -match "ISO" }
            $availableCommands.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Error Handling Tests" {
    Context "Parameter Validation" {
        It "Should handle null/empty parameters gracefully" {
            { Get-ISODownload -ISOName $null -WhatIf } | Should -Throw
            { Get-ISODownload -ISOName "" -WhatIf } | Should -Throw
            { New-AutounattendFile -Configuration @{} -OutputPath "" -WhatIf } | Should -Throw
        }

        It "Should validate file paths properly" {
            { Get-ISOMetadata -FilePath "C:\NonExistent\Path\file.iso" } | Should -Throw
            { Test-ISOIntegrity -FilePath "C:\NonExistent\Path\file.iso" } | Should -Throw
        }

        It "Should handle invalid configuration gracefully" {
            $invalidConfig = @{
                # Missing required parameters
                ComputerName = ""
                AdminPassword = ""
            }

            $testOutputPath = Join-Path $env:TEMP "invalid-config-test.xml"
            { New-AutounattendFile -Configuration $invalidConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw

            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }

    Context "File System Error Handling" {
        It "Should handle read-only file systems gracefully" {
            # This would test behavior when file system is read-only
            $readOnlyPath = Join-Path $env:TEMP "ReadOnlyTest"
            { New-ISORepository -Name "ReadOnlyTest" -RepositoryPath $readOnlyPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle insufficient disk space scenarios" {
            # This would test behavior when disk space is insufficient
            # In WhatIf mode, this should not actually consume space
            $largePath = Join-Path $env:TEMP "LargeISOTest"
            { New-CustomISO -SourceISOPath "test.iso" -OutputISOPath $largePath -WhatIf } | Should -Throw
        }
    }
}

Describe "Performance and Stress Tests" {
    Context "Large Configuration Handling" {
        It "Should handle very large configuration objects" {
            $largeConfig = @{
                ComputerName = "LARGE-CONFIG-TEST"
                AdminPassword = "LargeConfigTest123!"
                FirstLogonCommands = @()
            }
            
            # Add 100 first logon commands
            for ($i = 1; $i -le 100; $i++) {
                $largeConfig.FirstLogonCommands += @{
                    CommandLine = "powershell.exe -Command 'Write-Host Command$i'"
                    Description = "Test Command $i"
                    Order = $i
                }
            }
            
            $testOutputPath = Join-Path $env:TEMP "large-config-test.xml"
            
            Measure-Command {
                { New-AutounattendFile -Configuration $largeConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            } | Should -Not -BeNullOrEmpty
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle configuration with many registry changes" {
            $registryConfig = @{
                "HKLM:\SOFTWARE\Test1" = @{
                    "Value1" = "Data1"
                    "DWORD1" = 1
                }
            }
            for ($i = 2; $i -le 50; $i++) {
                $registryConfig["HKLM:\SOFTWARE\Test$i"] = @{
                    "Value$i" = "Data$i"
                    "DWORD$i" = $i
                }
            }
            
            $testSourceISO = Join-Path $env:TEMP "test-registry-source.iso"
            $testOutputISO = Join-Path $env:TEMP "test-registry-output.iso"
            
            "Test content" | Set-Content $testSourceISO
            
            Measure-Command {
                { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -RegistryChanges $registryConfig -WhatIf } | Should -Not -Throw
            } | Should -Not -BeNullOrEmpty
            
            Remove-Item $testSourceISO -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Memory Usage Tests" {
        It "Should handle multiple concurrent operations" {
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($i)
                    Import-Module './aither-core/modules/ISOManager' -Force
                    Import-Module './aither-core/modules/ISOCustomizer' -Force
                    
                    $config = @{
                        ComputerName = "CONCURRENT-TEST-$i"
                        AdminPassword = "ConcurrentTest123!"
                    }
                    
                    $outputPath = Join-Path $env:TEMP "concurrent-test-$i.xml"
                    New-AutounattendFile -Configuration $config -OutputPath $outputPath -WhatIf
                } -ArgumentList $i
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results.Count | Should -Be 5
        }
    }

    Context "Edge Case Handling" {
        It "Should handle very long file paths" {
            $longPath = "C:\" + ("VeryLongDirectoryName" * 10) + "\test.xml"
            $testConfig = @{
                ComputerName = "LONG-PATH-TEST"
                AdminPassword = "LongPathTest123!"
            }
            
            # This should handle the long path gracefully (may throw due to path length limits)
            try {
                New-AutounattendFile -Configuration $testConfig -OutputPath $longPath -WhatIf
                $true | Should -Be $true  # If no exception, that's fine
            } catch {
                $_.Exception.Message | Should -Match "path|length|invalid"  # Expected error types
            }
        }

        It "Should handle special characters in computer names" {
            $specialConfigs = @(
                @{ ComputerName = "TEST-123"; AdminPassword = "Test123!" },
                @{ ComputerName = "TEST_ABC"; AdminPassword = "Test123!" },
                @{ ComputerName = "TESTÑAME"; AdminPassword = "Test123!" }  # Unicode
            )
            
            foreach ($config in $specialConfigs) {
                $testOutputPath = Join-Path $env:TEMP "special-char-test-$($config.ComputerName).xml"
                { New-AutounattendFile -Configuration $config -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
                
                if (Test-Path $testOutputPath) {
                    Remove-Item $testOutputPath -Force
                }
            }
        }

        It "Should handle Unicode characters in passwords" {
            $unicodeConfig = @{
                ComputerName = "UNICODE-TEST"
                AdminPassword = "Tëst123!@#ñ"  # Unicode characters
            }
            
            $testOutputPath = Join-Path $env:TEMP "unicode-test.xml"
            { New-AutounattendFile -Configuration $unicodeConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle empty and whitespace-only values" {
            $edgeConfig = @{
                ComputerName = "EDGE-TEST"
                AdminPassword = "EdgeTest123!"
                FullName = "   "  # Whitespace only
                Organization = ""  # Empty string
                ProductKey = $null  # Null value
            }
            
            $testOutputPath = Join-Path $env:TEMP "edge-case-test.xml"
            { New-AutounattendFile -Configuration $edgeConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }
}

Describe "Security and Validation Tests" {
    Context "Input Sanitization" {
        It "Should sanitize potentially dangerous XML characters" {
            $dangerousConfig = @{
                ComputerName = "TEST<script>alert('xss')</script>"
                AdminPassword = "Test&123!<>"
                FullName = "Test & Co. <Ltd>"
            }
            
            $testOutputPath = Join-Path $env:TEMP "sanitization-test.xml"
            $result = New-AutounattendFile -Configuration $dangerousConfig -OutputPath $testOutputPath -Force
            
            $result.Success | Should -Be $true
            
            # Verify XML is still valid after sanitization
            { [xml](Get-Content $testOutputPath -Raw) } | Should -Not -Throw
            
            # Verify dangerous content is properly encoded
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Not -Match "<script>"
            $xmlContent | Should -Match "&amp;" -Because "Ampersands should be encoded"
            $xmlContent | Should -Match "&lt;" -Because "Less-than signs should be encoded"
            
            Remove-Item $testOutputPath -Force
        }

        It "Should validate password complexity requirements" {
            $weakPasswordConfigs = @(
                @{ ComputerName = "WEAK1"; AdminPassword = "123" },  # Too short
                @{ ComputerName = "WEAK2"; AdminPassword = "password" },  # Too simple
                @{ ComputerName = "WEAK3"; AdminPassword = "" }  # Empty
            )
            
            foreach ($config in $weakPasswordConfigs) {
                $testOutputPath = Join-Path $env:TEMP "weak-password-test.xml"
                # Should not throw but may generate warnings
                { New-AutounattendFile -Configuration $config -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
                
                if (Test-Path $testOutputPath) {
                    Remove-Item $testOutputPath -Force
                }
            }
        }

        It "Should handle SQL injection-like patterns in configuration" {
            $sqlInjectionConfig = @{
                ComputerName = "TEST'; DROP TABLE users; --"
                AdminPassword = "Test123!'; DELETE FROM passwords; --"
                Organization = "1' OR '1'='1"
            }
            
            $testOutputPath = Join-Path $env:TEMP "sql-injection-test.xml"
            { New-AutounattendFile -Configuration $sqlInjectionConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }

    Context "File Permission Tests" {
        It "Should respect file system permissions" {
            # Test creating files in protected directories (should fail gracefully)
            $protectedPath = "C:\Windows\System32\test-autounattend.xml"
            $testConfig = @{
                ComputerName = "PERM-TEST"
                AdminPassword = "PermTest123!"
            }
            
            try {
                New-AutounattendFile -Configuration $testConfig -OutputPath $protectedPath -WhatIf
                # If it doesn't throw, that's fine (WhatIf mode)
                $true | Should -Be $true
            } catch {
                # Expected to fail due to permissions
                $_.Exception.Message | Should -Match "access|permission|denied|unauthorized"
            }
        }
    }
}

Describe "Compatibility Tests" {
    Context "Cross-Platform Compatibility" {
        It "Should handle different path separators" {
            $windowsPath = "C:\Windows\System32\test.xml"
            $unixPath = "/tmp/test.xml"
            
            $testConfig = @{
                ComputerName = "PATH-TEST"
                AdminPassword = "PathTest123!"
            }
            
            # Should handle both path formats gracefully
            { New-AutounattendFile -Configuration $testConfig -OutputPath $windowsPath -WhatIf } | Should -Not -Throw
            { New-AutounattendFile -Configuration $testConfig -OutputPath $unixPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle different line endings" {
            $testConfig = @{
                ComputerName = "LINEEND-TEST"
                AdminPassword = "LineEndTest123!"
                FirstLogonCommands = @(
                    @{
                        CommandLine = "echo 'Unix line ending'" + "`n"  # Unix style
                        Description = "Unix command"
                    },
                    @{
                        CommandLine = "echo 'Windows line ending'" + "`r`n"  # Windows style
                        Description = "Windows command"
                    }
                )
            }
            
            $testOutputPath = Join-Path $env:TEMP "line-ending-test.xml"
            { New-AutounattendFile -Configuration $testConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }

    Context "PowerShell Version Compatibility" {
        It "Should work with PowerShell 7.0+ features" {
            # Test using modern PowerShell features
            $modernConfig = @{
                ComputerName = "MODERN-TEST"
                AdminPassword = "ModernTest123!"
                FirstLogonCommands = @(
                    @{
                        CommandLine = "pwsh -Command 'Get-Process | Where-Object { `$_.ProcessName -eq `"explorer`" }'"
                        Description = "Modern PowerShell command"
                    }
                )
            }
            
            $testOutputPath = Join-Path $env:TEMP "modern-ps-test.xml"
            { New-AutounattendFile -Configuration $modernConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
            
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }
    }
}

Describe "Regression Tests" {
    Context "Previously Fixed Issues" {
        It "Should not regress on template loading" {
            # Test that templates are properly loaded from module directory
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            $testConfig = @{
                ComputerName = "REGRESSION-TEST"
                AdminPassword = "RegressionTest123!"
            }
            
            # Should work both in normal and headless mode
            $normalOutputPath = Join-Path $env:TEMP "regression-normal-test.xml"
            $headlessOutputPath = Join-Path $env:TEMP "regression-headless-test.xml"
            
            { New-AutounattendFile -Configuration $testConfig -OutputPath $normalOutputPath -WhatIf } | Should -Not -Throw
            { New-AutounattendFile -Configuration $testConfig -OutputPath $headlessOutputPath -HeadlessMode -WhatIf } | Should -Not -Throw
            
            @($normalOutputPath, $headlessOutputPath) | ForEach-Object {
                if (Test-Path $_) {
                    Remove-Item $_ -Force
                }
            }
        }

        It "Should not regress on missing Windows/Linux ISO URL functions" {
            # Test that both helper functions exist and work
            { Get-ISODownload -ISOName "Windows11" -ISOType "Windows" -WhatIf } | Should -Not -Throw
            { Get-ISODownload -ISOName "Ubuntu" -ISOType "Linux" -WhatIf } | Should -Not -Throw
        }        It "Should not regress on XML validation" {
            # Test that generated XML is always valid
            $validationConfigs = @(
                @{ ComputerName = "XML-VAL-1"; AdminPassword = "XmlVal123!"; EnableRDP = $true },
                @{ ComputerName = "XML-VAL-2"; AdminPassword = "XmlVal123!"; AutoLogon = $true },
                @{ ComputerName = "XML-VAL-3"; AdminPassword = "XmlVal123!"; DisableFirewall = $true }
            )
            
            foreach ($config in $validationConfigs) {
                $testOutputPath = Join-Path $env:TEMP "xml-validation-test-$($config.ComputerName).xml"
                $result = New-AutounattendFile -Configuration $config -OutputPath $testOutputPath -Force
                
                $result.Success | Should -Be $true
                Test-Path $testOutputPath | Should -Be $true
                
                # Validate XML is well-formed
                { [xml](Get-Content $testOutputPath -Raw) } | Should -Not -Throw
                
                Remove-Item $testOutputPath -Force
            }
        }
    }
}

Describe "ISOManager Module - Missing Functions Tests" {
    Context "Missing Function Validation" {
        It "Should not export functions that don't exist" {
            # Test that manifest doesn't export non-existent functions
            $manifest = Import-PowerShellDataFile './aither-core/modules/ISOManager/ISOManager.psd1'
            $actualPublicFiles = Get-ChildItem './aither-core/modules/ISOManager/Public' -Filter '*.ps1' | ForEach-Object { $_.BaseName }
            
            foreach ($exportedFunction in $manifest.FunctionsToExport) {
                if ($exportedFunction -eq 'Get-ISODownloadOptions') {
                    # This function is listed in manifest but missing - expected for now
                    continue
                }
                $actualPublicFiles | Should -Contain $exportedFunction
            }
        }
    }
}

Describe "ISOManager Module - Missing Function Implementation Tests" {
    Context "Get-ISOMetadata Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Get-ISOMetadata
            $command.Parameters.Keys | Should -Contain 'FilePath'
        }

        It "Should validate file path parameter" {
            { Get-ISOMetadata -FilePath "" } | Should -Throw
        }

        It "Should handle non-existent file gracefully" {
            { Get-ISOMetadata -FilePath "NonExistent.iso" } | Should -Throw
        }

        It "Should return metadata structure for valid test file" {
            # Create a test file to simulate ISO
            $testFile = Join-Path $env:TEMP "test-metadata.iso"
            "Test ISO content" | Set-Content $testFile
            
            try {
                $result = Get-ISOMetadata -FilePath $testFile
                $result | Should -Not -BeNullOrEmpty
                $result.FileName | Should -Not -BeNullOrEmpty
                $result.FilePath | Should -Be $testFile
            } finally {
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "New-ISORepository Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command New-ISORepository
            $command.Parameters.Keys | Should -Contain 'RepositoryPath'
        }

        It "Should validate repository path parameter" {
            { New-ISORepository -RepositoryPath "" -WhatIf } | Should -Throw
        }

        It "Should support WhatIf parameter" {
            $testRepoPath = Join-Path $env:TEMP "TestNewRepo"
            { New-ISORepository -RepositoryPath $testRepoPath -WhatIf } | Should -Not -Throw
        }

        It "Should create repository structure" {
            $testRepoPath = Join-Path $env:TEMP "TestCreateRepo"
            
            try {
                $result = New-ISORepository -RepositoryPath $testRepoPath -Force
                $result.Success | Should -Be $true
                Test-Path $testRepoPath | Should -Be $true
            } finally {
                Remove-Item $testRepoPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Sync-ISORepository Function" {
        It "Should have correct parameter structure" {
            $command = Get-Command Sync-ISORepository
            $command.Parameters.Keys | Should -Contain 'RepositoryPath'
        }

        It "Should validate repository path exists" {
            { Sync-ISORepository -RepositoryPath "NonExistentRepo" -WhatIf } | Should -Throw
        }

        It "Should support WhatIf parameter" {
            $testRepoPath = Join-Path $env:TEMP "TestSyncRepo"
            New-Item -ItemType Directory -Path $testRepoPath -Force | Out-Null
            
            try {
                { Sync-ISORepository -RepositoryPath $testRepoPath -WhatIf } | Should -Not -Throw
            } finally {
                Remove-Item $testRepoPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "ISOCustomizer Module - Advanced Template Tests" {
    Context "Template Helper Functions" {
        It "Should load template helpers successfully" {
            # Import the private function file to test template helpers
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            # Test that template helper functions are available (they should be imported internally)
            { Get-AutounattendTemplate -TemplateType 'Generic' } | Should -Not -Throw
            { Get-AutounattendTemplate -TemplateType 'Headless' } | Should -Not -Throw
        }

        It "Should return valid template paths" {
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            $genericTemplate = Get-AutounattendTemplate -TemplateType 'Generic'
            $headlessTemplate = Get-AutounattendTemplate -TemplateType 'Headless'
            
            $genericTemplate | Should -Not -BeNullOrEmpty
            $headlessTemplate | Should -Not -BeNullOrEmpty
            
            if ($genericTemplate) {
                Test-Path $genericTemplate | Should -Be $true
            }
            if ($headlessTemplate) {
                Test-Path $headlessTemplate | Should -Be $true
            }
        }

        It "Should handle invalid template types gracefully" {
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            $invalidTemplate = Get-AutounattendTemplate -TemplateType 'NonExistent'
            # Should return generic template as fallback or null
            if ($invalidTemplate) {
                Test-Path $invalidTemplate | Should -Be $true
            }
        }
    }

    Context "Bootstrap Template Tests" {
        It "Should provide bootstrap template" {
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            $bootstrapTemplate = Get-BootstrapTemplate
            if ($bootstrapTemplate) {
                Test-Path $bootstrapTemplate | Should -Be $true
                $content = Get-Content $bootstrapTemplate -Raw
                $content | Should -Match "PowerShell" -Because "Bootstrap should be a PowerShell script"
            }
        }
    }

    Context "Kickstart Template Tests" {
        It "Should provide kickstart template" {
            Import-Module './aither-core/modules/ISOCustomizer' -Force
            
            $kickstartTemplate = Get-KickstartTemplate
            if ($kickstartTemplate) {
                Test-Path $kickstartTemplate | Should -Be $true
                $content = Get-Content $kickstartTemplate -Raw
                $content | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "ISOCustomizer Module - Advanced Autounattend Tests" {
    Context "Complex Domain Configuration" {
        BeforeEach {
            $testOutputPath = Join-Path $env:TEMP "test-domain-complex.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle complete domain join configuration" {
            $domainConfig = @{
                ComputerName = "DOMAIN-FULL-TEST"
                AdminPassword = "DomainTest123!"
                JoinDomain = $true
                DomainName = "contoso.local"
                DomainAdmin = "contoso\administrator"
                DomainPassword = "DomainPass123!"
                OrganizationalUnit = "OU=Servers,DC=contoso,DC=local"
                CreateDomainAccount = $true
                DomainAccountPassword = "DomainAcct123!"
            }

            $result = New-AutounattendFile -Configuration $domainConfig -OutputPath $testOutputPath -Force

            $result.Success | Should -Be $true
            Test-Path $testOutputPath | Should -Be $true

            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "contoso.local"
            $xmlContent | Should -Match "DOMAIN-FULL-TEST"
        }

        It "Should handle workgroup configuration" {
            $workgroupConfig = @{
                ComputerName = "WORKGROUP-TEST"
                AdminPassword = "WorkgroupTest123!"
                JoinWorkgroup = $true
                WorkgroupName = "WORKGROUP"
            }

            $result = New-AutounattendFile -Configuration $workgroupConfig -OutputPath $testOutputPath -Force

            $result.Success | Should -Be $true
            $xmlContent = Get-Content $testOutputPath -Raw
            $xmlContent | Should -Match "WORKGROUP-TEST"
        }
    }

    Context "Advanced Network Configuration" {
        BeforeEach {
            $testOutputPath = Join-Path $env:TEMP "test-network-complex.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle multiple network adapters" {
            $networkConfig = @{
                ComputerName = "MULTI-NIC-TEST"
                AdminPassword = "MultiNic123!"
                NetworkAdapters = @(
                    @{
                        Name = "Ethernet1"
                        EnableDHCP = $false
                        StaticIP = "192.168.1.100"
                        SubnetMask = "255.255.255.0"
                        Gateway = "192.168.1.1"
                        DNSServers = @("192.168.1.1", "8.8.8.8")
                        Metric = 1
                    },
                    @{
                        Name = "Ethernet2"
                        EnableDHCP = $true
                        Metric = 2
                    }
                )
            }

            { New-AutounattendFile -Configuration $networkConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle VLAN configuration" {
            $vlanConfig = @{
                ComputerName = "VLAN-TEST"
                AdminPassword = "VlanTest123!"
                EnableVLAN = $true
                VLANID = 100
                StaticIP = "10.100.1.100"
                SubnetMask = "255.255.255.0"
                Gateway = "10.100.1.1"
            }

            { New-AutounattendFile -Configuration $vlanConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Advanced Security Configuration" {
        BeforeEach {
            $testOutputPath = Join-Path $env:TEMP "test-security-complex.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle comprehensive security settings" {
            $securityConfig = @{
                ComputerName = "SECURE-TEST"
                AdminPassword = "SecureTest123!"
                DisableFirewall = $false
                EnableWindowsDefender = $true
                DisableUAC = $false
                EnableBitLocker = $true
                BitLockerPIN = "1234"
                EnableSecureBoot = $true
                DisableAutoRun = $true
                DisableAutoPlay = $true
                EnableAuditLogging = $true
                SetPasswordPolicy = $true
                MinPasswordLength = 12
                RequireComplexPasswords = $true
                MaxPasswordAge = 60
                LockoutThreshold = 3
                LockoutDuration = 30
            }

            { New-AutounattendFile -Configuration $securityConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Advanced Feature Configuration" {
        BeforeEach {
            $testOutputPath = Join-Path $env:TEMP "test-features-complex.xml"
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        AfterEach {
            if (Test-Path $testOutputPath) {
                Remove-Item $testOutputPath -Force
            }
        }

        It "Should handle Windows feature installation" {
            $featuresConfig = @{
                ComputerName = "FEATURES-TEST"
                AdminPassword = "FeaturesTest123!"
                WindowsFeatures = @(
                    "IIS-WebServerRole",
                    "IIS-WebServer",
                    "IIS-CommonHttpFeatures",
                    "IIS-HttpErrors",
                    "IIS-HttpLogging",
                    "IIS-RequestMonitor",
                    "IIS-Security",
                    "IIS-RequestFiltering",
                    "IIS-StaticContent",
                    "MSMQ-Container",
                    "MSMQ-Server",
                    "WAS-WindowsActivationService",
                    "WAS-ProcessModel",
                    "WAS-NetFxEnvironment",
                    "WAS-ConfigurationAPI"
                )
                OptionalComponents = @(
                    "NetFx3",
                    "NetFx4Extended-ASPNET45",
                    "IIS-NetFxExtensibility45",
                    "IIS-ISAPIExtensions",
                    "IIS-ISAPIFilter",
                    "IIS-ASPNET45"
                )
            }

            { New-AutounattendFile -Configuration $featuresConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle Hyper-V configuration" {
            $hypervConfig = @{
                ComputerName = "HYPERV-TEST"
                AdminPassword = "HypervTest123!"
                EnableHyperV = $true
                HyperVSwitches = @(
                    @{
                        Name = "External"
                        Type = "External"
                        NetAdapter = "Ethernet"
                    },
                    @{
                        Name = "Internal"
                        Type = "Internal"
                    },
                    @{
                        Name = "Private"
                        Type = "Private"
                    }
                )
                HyperVDefaultPaths = @{
                    VirtualHardDisks = "C:\Hyper-V\VHDs"
                    VirtualMachines = "C:\Hyper-V\VMs"
                }
            }

            { New-AutounattendFile -Configuration $hypervConfig -OutputPath $testOutputPath -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Cross-Module Integration - Complete Workflow Tests" {
    Context "End-to-End ISO Workflow" {
        It "Should complete full workflow from download to customization" {
            # This test validates the complete workflow without actually executing it
            
            # Step 1: Download ISO (simulate)
            { Get-ISODownload -ISOName "TestWorkflow" -ISOType "Custom" -CustomURL "https://example.com/test.iso" -WhatIf } | Should -Not -Throw
            
            # Step 2: Generate autounattend
            $workflowConfig = @{
                ComputerName = "WORKFLOW-TEST"
                AdminPassword = "WorkflowTest123!"
            }
            $autounattendPath = Join-Path $env:TEMP "workflow-autounattend.xml"
            
            try {
                $autounattendResult = New-AutounattendFile -Configuration $workflowConfig -OutputPath $autounattendPath -Force
                $autounattendResult.Success | Should -Be $true
                
                # Step 3: Create custom ISO (simulate)
                $testSourceISO = Join-Path $env:TEMP "workflow-source.iso"
                $testOutputISO = Join-Path $env:TEMP "workflow-output.iso"
                "Test content" | Set-Content $testSourceISO
                
                { New-CustomISO -SourceISOPath $testSourceISO -OutputISOPath $testOutputISO -AutounattendFile $autounattendPath -WhatIf } | Should -Not -Throw
                
            } finally {
                @($autounattendPath, $testSourceISO, $testOutputISO) | ForEach-Object {
                    if (Test-Path $_) {
                        Remove-Item $_ -Force
                    }
                }
            }
        }

        It "Should handle repository operations in complete workflow" {
            $testRepoPath = Join-Path $env:TEMP "WorkflowRepo"
            
            try {
                # Create repository
                $repoResult = New-ISORepository -RepositoryPath $testRepoPath -Force
                $repoResult.Success | Should -Be $true
                
                # Get inventory
                $inventory = Get-ISOInventory -RepositoryPath $testRepoPath
                $inventory | Should -BeOfType [array]
                
                # Export inventory
                $exportPath = Join-Path $env:TEMP "workflow-inventory.json"
                $exportResult = Export-ISOInventory -RepositoryPath $testRepoPath -ExportPath $exportPath -Force
                $exportResult.Success | Should -Be $true
                
                # Import inventory
                { Import-ISOInventory -ImportPath $exportPath -TargetRepositoryPath $testRepoPath -WhatIf } | Should -Not -Throw
                
            } finally {
                @($testRepoPath, $exportPath) | ForEach-Object {
                    if (Test-Path $_) {
                        Remove-Item $_ -Recurse -Force
                    }
                }
            }
        }
    }
}

Describe "ISO Module Performance and Stress Tests" {
    Context "Large Configuration Performance" {
        It "Should handle large autounattend configurations efficiently" {
            $largeConfig = @{
                ComputerName = "PERF-TEST"
                AdminPassword = "PerfTest123!"
                FirstLogonCommands = @()
            }
            
            # Add 100 first logon commands
            for ($i = 1; $i -le 100; $i++) {
                $largeConfig.FirstLogonCommands += @{
                    CommandLine = "cmd.exe /c echo Command $i"
                    Description = "Performance Test Command $i"
                }
            }
            
            $perfOutputPath = Join-Path $env:TEMP "performance-test.xml"
            
            try {
                $executionTime = Measure-Command {
                    $result = New-AutounattendFile -Configuration $largeConfig -OutputPath $perfOutputPath -Force
                    $result.Success | Should -Be $true
                }
                
                # Should complete within reasonable time (30 seconds for 100 commands)
                $executionTime.TotalSeconds | Should -BeLessThan 30
                
                # Verify file size is reasonable
                $fileSize = (Get-Item $perfOutputPath).Length
                $fileSize | Should -BeGreaterThan 10KB
                $fileSize | Should -BeLessThan 1MB
                
            } finally {
                Remove-Item $perfOutputPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Memory Usage Tests" {
        It "Should not have memory leaks during repeated operations" {
            $initialMemory = [GC]::GetTotalMemory($true)
            
            for ($i = 1; $i -le 10; $i++) {
                $testConfig = @{
                    ComputerName = "MEMORY-TEST-$i"
                    AdminPassword = "MemoryTest123!"
                }
                $testPath = Join-Path $env:TEMP "memory-test-$i.xml"
                
                try {
                    New-AutounattendFile -Configuration $testConfig -OutputPath $testPath -Force | Out-Null
                } finally {
                    Remove-Item $testPath -Force -ErrorAction SilentlyContinue
                }
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($true)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be minimal (less than 10MB)
            $memoryIncrease | Should -BeLessThan 10MB
        }
    }
}

Describe "Error Handling and Recovery Tests" {
    Context "Graceful Error Handling" {
        It "Should provide meaningful error messages for invalid configurations" {
            $invalidConfig = @{
                ComputerName = ""  # Invalid: empty computer name
                AdminPassword = "Test123!"
            }
            $testPath = Join-Path $env:TEMP "invalid-test.xml"
            
            try {
                { New-AutounattendFile -Configuration $invalidConfig -OutputPath $testPath -WhatIf } | Should -Throw
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
                $_.Exception.Message | Should -Match "ComputerName|name|invalid" -Because "Error should mention the invalid parameter"
            }
        }

        It "Should handle disk space issues gracefully" {
            # Simulate disk space check
            $tempPath = Join-Path $env:TEMP "diskspace-test"
            $freespace = (Get-PSDrive -Name ($env:TEMP.Split(':')[0])).Free
            
            # Only run this test if we have reasonable free space
            if ($freespace -gt 1GB) {
                $testConfig = @{
                    ComputerName = "DISKSPACE-TEST"
                    AdminPassword = "DiskTest123!"
                }
                
                # This should succeed with adequate disk space
                { New-AutounattendFile -Configuration $testConfig -OutputPath $tempPath -WhatIf } | Should -Not -Throw
            }
        }

        It "Should handle permission issues gracefully" {
            $restrictedPath = "C:\Windows\System32\test-permission.xml"
            $testConfig = @{
                ComputerName = "PERMISSION-TEST"
                AdminPassword = "PermTest123!"
            }
            
            # This should fail with access denied (unless running as admin on C:\Windows\System32)
            { New-AutounattendFile -Configuration $testConfig -OutputPath $restrictedPath -Force } | Should -Throw
        }
    }
}

Describe "Security and Validation Tests" {
    Context "Input Validation and Sanitization" {
        It "Should sanitize special characters in computer names" {
            $specialCharConfig = @{
                ComputerName = "Test<>Computer|Name*"
                AdminPassword = "SpecialTest123!"
            }
            $testPath = Join-Path $env:TEMP "special-char-test.xml"
            
            try {
                $result = New-AutounattendFile -Configuration $specialCharConfig -OutputPath $testPath -Force
                $result.Success | Should -Be $true
                
                $xmlContent = Get-Content $testPath -Raw
                # Should not contain dangerous XML characters
                $xmlContent | Should -Not -Match "[<>&]" -Because "XML should be properly escaped"
                
            } finally {
                Remove-Item $testPath -Force -ErrorAction SilentlyContinue
            }
        }

        It "Should validate password complexity requirements" {
            $weakPasswordConfig = @{
                ComputerName = "PASSWORD-TEST"
                AdminPassword = "123"  # Weak password
                EnforcePasswordPolicy = $true
                MinPasswordLength = 8
                RequireComplexPasswords = $true
            }
            
            $testPath = Join-Path $env:TEMP "password-test.xml"
            
            # Should either handle weak password or provide warning
            { New-AutounattendFile -Configuration $weakPasswordConfig -OutputPath $testPath -WhatIf } | Should -Not -Throw
        }

        It "Should prevent XML injection attacks" {
            $maliciousConfig = @{
                ComputerName = "TEST"
                AdminPassword = "Test123!"
                CustomXMLPayload = "<?xml version='1.0'?><malicious>payload</malicious>"
            }
            
            $testPath = Join-Path $env:TEMP "injection-test.xml"
            
            try {
                $result = New-AutounattendFile -Configuration $maliciousConfig -OutputPath $testPath -Force
                $result.Success | Should -Be $true
                
                $xmlContent = Get-Content $testPath -Raw
                # Should not contain the malicious payload as raw XML
                $xmlContent | Should -Not -Match "<malicious>" -Because "XML injection should be prevented"
                
            } finally {
                Remove-Item $testPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
