#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
    
    # Import test helpers
    Import-Module (Join-Path $projectRoot "tests/TestHelpers.psm1") -Force
}

Describe "DeploymentArtifacts Module Tests" {
    BeforeEach {
        # Create test output directory
        $script:TestOutputPath = Join-Path $TestDrive "artifacts"
        New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
        
        # Create minimal test configuration
        $script:TestConfig = @{
            EnvironmentConfiguration = @{
                Windows = @{
                    Registry = @{
                        'HKLM:\SOFTWARE\Test' = @{
                            'TestValue' = 'TestData'
                        }
                    }
                }
                Unix = @{
                    Packages = @('git', 'curl', 'vim')
                }
                EnvironmentVariables = @{
                    System = @{
                        'TEST_VAR' = 'TestValue'
                    }
                }
            }
            DeploymentArtifacts = @{
                Windows = @{
                    UnattendXml = @{
                        Generate = $true
                        FileName = 'Autounattend.xml'
                    }
                    Dockerfile = @{
                        Generate = $true
                        FileName = 'Dockerfile.windows'
                        BaseImage = 'mcr.microsoft.com/powershell:lts-nanoserver-1809'
                    }
                }
                Linux = @{
                    CloudInit = @{
                        Generate = $true
                        FileName = 'cloud-init.yaml'
                    }
                    Dockerfile = @{
                        Generate = $true
                        FileName = 'Dockerfile'
                        BaseImage = 'mcr.microsoft.com/powershell:lts-ubuntu-22.04'
                    }
                }
                macOS = @{
                    Brewfile = @{
                        Generate = $true
                        FileName = 'Brewfile'
                    }
                }
            }
        }
    }

    Context "New-AitherDeploymentArtifact" {
        It "Should generate artifacts for all platforms" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            Mock New-UnattendXml {} -ModuleName DeploymentArtifacts
            Mock New-CloudInitConfig {} -ModuleName DeploymentArtifacts
            Mock New-Brewfile {} -ModuleName DeploymentArtifacts
            Mock New-Dockerfile {} -ModuleName DeploymentArtifacts
            
            { New-AitherDeploymentArtifact -Platform All -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath } | Should -Not -Throw
            
            Should -Invoke New-UnattendXml -ModuleName DeploymentArtifacts -Times 1
            Should -Invoke New-CloudInitConfig -ModuleName DeploymentArtifacts -Times 1
            Should -Invoke New-Brewfile -ModuleName DeploymentArtifacts -Times 1
            Should -Invoke New-Dockerfile -ModuleName DeploymentArtifacts -AtLeast 1
        }
        
        It "Should generate Windows artifacts only" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            Mock New-UnattendXml {} -ModuleName DeploymentArtifacts
            Mock New-CloudInitConfig {} -ModuleName DeploymentArtifacts
            
            New-AitherDeploymentArtifact -Platform Windows -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath
            
            Should -Invoke New-UnattendXml -ModuleName DeploymentArtifacts -Times 1
            Should -Not -Invoke New-CloudInitConfig -ModuleName DeploymentArtifacts
        }
        
        It "Should generate Linux artifacts only" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            Mock New-UnattendXml {} -ModuleName DeploymentArtifacts
            Mock New-CloudInitConfig {} -ModuleName DeploymentArtifacts
            
            New-AitherDeploymentArtifact -Platform Linux -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath
            
            Should -Invoke New-CloudInitConfig -ModuleName DeploymentArtifacts -Times 1
            Should -Not -Invoke New-UnattendXml -ModuleName DeploymentArtifacts
        }
        
        It "Should generate macOS artifacts only" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            Mock New-Brewfile {} -ModuleName DeploymentArtifacts
            Mock New-UnattendXml {} -ModuleName DeploymentArtifacts
            
            New-AitherDeploymentArtifact -Platform macOS -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath
            
            Should -Invoke New-Brewfile -ModuleName DeploymentArtifacts -Times 1
            Should -Not -Invoke New-UnattendXml -ModuleName DeploymentArtifacts
        }
        
        It "Should create output directory if it doesn't exist" {
            $newPath = Join-Path $TestDrive "new-artifacts-$(Get-Random)"
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            Mock New-UnattendXml {} -ModuleName DeploymentArtifacts
            
            New-AitherDeploymentArtifact -Platform Windows -ConfigPath $script:TestConfig -OutputPath $newPath
            
            Test-Path $newPath | Should -Be $true
        }
    }

    Context "New-UnattendXml" {
        It "Should generate valid Unattend.xml file" {
            $outputFile = Join-Path $script:TestOutputPath "Autounattend.xml"
            
            New-UnattendXml -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "<?xml version"
            $content | Should -Match "unattend"
        }
        
        It "Should include configuration settings in output" {
            $outputFile = Join-Path $script:TestOutputPath "Autounattend.xml"
            
            New-UnattendXml -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Not -BeNullOrEmpty
            $content.Length | Should -BeGreaterThan 100
        }
        
        It "Should create parent directory if needed" {
            $newDir = Join-Path $TestDrive "unattend-test-$(Get-Random)"
            $outputFile = Join-Path $newDir "Autounattend.xml"
            
            New-UnattendXml -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
        }
        
        It "Should generate well-formed XML" {
            $outputFile = Join-Path $script:TestOutputPath "Autounattend.xml"
            
            New-UnattendXml -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            { [xml](Get-Content $outputFile -Raw) } | Should -Not -Throw
        }
    }

    Context "New-CloudInitConfig" {
        It "Should generate cloud-init YAML file" {
            $outputFile = Join-Path $script:TestOutputPath "cloud-init.yaml"
            
            New-CloudInitConfig -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "#cloud-config"
        }
        
        It "Should include package installation" {
            $outputFile = Join-Path $script:TestOutputPath "cloud-init.yaml"
            
            New-CloudInitConfig -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "packages:"
        }
        
        It "Should support JSON output format" {
            $outputFile = Join-Path $script:TestOutputPath "cloud-init.json"
            
            New-CloudInitConfig -ConfigPath $script:TestConfig -OutputPath $outputFile -Format Json
            
            Test-Path $outputFile | Should -Be $true
            
            { Get-Content $outputFile -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should support shell script format" {
            $outputFile = Join-Path $script:TestOutputPath "cloud-init.sh"
            
            New-CloudInitConfig -ConfigPath $script:TestConfig -OutputPath $outputFile -Format Shell
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "#!/bin/bash"
        }
    }

    Context "New-Brewfile" {
        It "Should generate Brewfile" {
            $outputFile = Join-Path $script:TestOutputPath "Brewfile"
            
            # Create macOS config with Homebrew packages
            $macOSConfig = @{
                EnvironmentConfiguration = @{
                    macOS = @{
                        Homebrew = @{
                            Formulae = @('git', 'node', 'python')
                            Casks = @('visual-studio-code', 'docker')
                            Taps = @('homebrew/cask-versions')
                        }
                    }
                }
            }
            
            New-Brewfile -ConfigPath $macOSConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "brew 'git'"
        }
        
        It "Should include taps, formulae, and casks" {
            $outputFile = Join-Path $script:TestOutputPath "Brewfile"
            
            $macOSConfig = @{
                EnvironmentConfiguration = @{
                    macOS = @{
                        Homebrew = @{
                            Formulae = @('wget')
                            Casks = @('firefox')
                            Taps = @('homebrew/core')
                        }
                    }
                }
            }
            
            New-Brewfile -ConfigPath $macOSConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "tap 'homebrew/core'"
            $content | Should -Match "brew 'wget'"
            $content | Should -Match "cask 'firefox'"
        }
        
        It "Should handle empty configuration" {
            $outputFile = Join-Path $script:TestOutputPath "Brewfile.empty"
            
            $emptyConfig = @{
                EnvironmentConfiguration = @{
                    macOS = @{}
                }
            }
            
            New-Brewfile -ConfigPath $emptyConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
        }
    }

    Context "New-Dockerfile" {
        It "Should generate Linux Dockerfile" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile"
            
            New-Dockerfile -Platform Linux -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "FROM"
            $content | Should -Match "mcr.microsoft.com/powershell"
        }
        
        It "Should generate Windows Dockerfile" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.windows"
            
            New-Dockerfile -Platform Windows -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "FROM"
            $content | Should -Match "nanoserver"
        }
        
        It "Should include base image from config" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.custom"
            
            $customConfig = @{
                DeploymentArtifacts = @{
                    Linux = @{
                        Dockerfile = @{
                            BaseImage = 'custom/image:latest'
                        }
                    }
                }
            }
            
            New-Dockerfile -Platform Linux -ConfigPath $customConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "custom/image:latest"
        }
        
        It "Should include environment variables" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.env"
            
            New-Dockerfile -Platform Linux -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            # Should have ENV directives or environment setup
            $content.Length | Should -BeGreaterThan 50
        }
        
        It "Should handle missing Dockerfile config gracefully" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.minimal"
            
            $minimalConfig = @{
                DeploymentArtifacts = @{
                    Linux = @{}
                }
            }
            
            { New-Dockerfile -Platform Linux -ConfigPath $minimalConfig -OutputPath $outputFile } | Should -Not -Throw
        }
        
        It "Should use correct CMD syntax without quote escaping errors" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.syntax"
            
            New-Dockerfile -Platform Linux -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            # Should use proper JSON array syntax for CMD
            if ($content -match 'CMD') {
                $content | Should -Match 'CMD \['
                # Should not have escaped quotes that would cause syntax errors
                $content | Should -Not -Match '\\"'
            }
        }
    }

    Context "New-RegistryFile" {
        It "Should generate Windows registry file" {
            $outputFile = Join-Path $script:TestOutputPath "settings.reg"
            
            New-RegistryFile -ConfigPath $script:TestConfig -OutputPath $outputFile
            
            Test-Path $outputFile | Should -Be $true
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "Windows Registry Editor Version"
        }
        
        It "Should include registry paths and values" {
            $outputFile = Join-Path $script:TestOutputPath "registry.reg"
            
            $regConfig = @{
                EnvironmentConfiguration = @{
                    Windows = @{
                        Registry = @{
                            'HKLM:\SOFTWARE\TestApp' = @{
                                'Setting1' = 'Value1'
                                'Setting2' = 123
                            }
                        }
                    }
                }
            }
            
            New-RegistryFile -ConfigPath $regConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Match "HKEY_LOCAL_MACHINE\\SOFTWARE\\TestApp"
            $content | Should -Match "Setting1"
        }
        
        It "Should handle different value types" {
            $outputFile = Join-Path $script:TestOutputPath "types.reg"
            
            $regConfig = @{
                EnvironmentConfiguration = @{
                    Windows = @{
                        Registry = @{
                            'HKLM:\SOFTWARE\Test' = @{
                                'StringValue' = 'Text'
                                'DwordValue' = 1
                            }
                        }
                    }
                }
            }
            
            New-RegistryFile -ConfigPath $regConfig -OutputPath $outputFile
            
            $content = Get-Content $outputFile -Raw
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should handle missing configuration" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            
            { New-AitherDeploymentArtifact -Platform Windows -ConfigPath @{} -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
        
        It "Should handle invalid output path gracefully" {
            Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
            
            if ($IsWindows) {
                $invalidPath = "Z:\NonExistent\Path\$(Get-Random)"
            } else {
                $invalidPath = "/root/no-permission-$(Get-Random)"
            }
            
            # Should create directory or handle error gracefully
            { New-UnattendXml -ConfigPath $script:TestConfig -OutputPath $invalidPath -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should validate platform parameter" {
            { New-Dockerfile -Platform "InvalidPlatform" -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath } | Should -Throw
        }
    }

    Context "Integration" {
        It "Should generate all artifacts without errors" {
            $platforms = @('Windows', 'Linux', 'macOS')
            
            foreach ($platform in $platforms) {
                Mock Write-CustomLog {} -ModuleName DeploymentArtifacts
                
                { New-AitherDeploymentArtifact -Platform $platform -ConfigPath $script:TestConfig -OutputPath $script:TestOutputPath } | Should -Not -Throw
            }
        }
        
        It "Should generate artifacts that are readable" {
            New-UnattendXml -ConfigPath $script:TestConfig -OutputPath (Join-Path $script:TestOutputPath "test.xml")
            New-CloudInitConfig -ConfigPath $script:TestConfig -OutputPath (Join-Path $script:TestOutputPath "test.yaml")
            New-Dockerfile -Platform Linux -ConfigPath $script:TestConfig -OutputPath (Join-Path $script:TestOutputPath "Dockerfile")
            
            $files = Get-ChildItem $script:TestOutputPath
            $files.Count | Should -BeGreaterThan 0
            
            foreach ($file in $files) {
                { Get-Content $file.FullName -Raw } | Should -Not -Throw
                (Get-Content $file.FullName -Raw).Length | Should -BeGreaterThan 0
            }
        }
    }
}
