<#
.SYNOPSIS
Extensible Cross-Platform Testing Framework for OpenTofu Lab Automation

.DESCRIPTION
This framework provides standardized patterns for testing runner scripts across platforms.
It automatically handles platform detection, mock setup, and common test scenarios.

.FEATURES
- Cross-platform compatibility (Windows, Linux, macOS)
- Automatic script discovery and validation
- Standardized mock patterns
- Configuration-driven testing
- Extensible test templates
- Performance and integration testing support
#>

# List of known PowerShell built-in or external commands that should be mocked globally
$script:GlobalCommands = @(
    'Get-Command', 'Start-Process', 'Invoke-WebRequest', 'Invoke-RestMethod',
    'New-Item', 'Remove-Item', 'Copy-Item', 'Test-Path',
    'Get-Service', 'Start-Service', 'Stop-Service', 'Restart-Service',
    'Get-WindowsOptionalFeature', 'Enable-WindowsOptionalFeature',
    'Get-WindowsFeature', 'Install-WindowsFeature',
    'Get-ItemProperty', 'Set-ItemProperty',
    'New-NetFirewallRule', 'Get-NetFirewallRule', 'Remove-NetFirewallRule',
    'Set-DnsClientServerAddress', 'New-SelfSignedCertificate',
    'Enable-PSRemoting', 'Test-WSMan',
    'Write-Host', 'Write-Verbose', 'Write-Warning', 'Write-Error', 'Read-Host',
    # OS-specific external commands often checked with Get-Command or invoked directly
    'apt-get', 'yum', 'dnf', 'zypper', 'pacman', # Linux package managers
    'systemctl', 'service', # Linux service management
    'brew', 'launchctl', # macOS
    'choco', 'winget', 'msiexec' # Windows package managers / installers
)

# Framework Configuration
$script:TestFrameworkConfig = @{
    DefaultTimeout     = 30
    MaxRetries         = 3
    LogLevel           = 'Information'
    EnableCodeCoverage = $true
    PlatformSpecific   = @{
        Windows = @{
            RequiredModules = @('Hyper-V')
            SkippedFeatures = @()
        }
        Linux   = @{
            RequiredModules = @()
            SkippedFeatures = @('Hyper-V', 'WindowsFeatures')
        }
        macOS   = @{
            RequiredModules = @()
            SkippedFeatures = @('Hyper-V', 'WindowsFeatures')
        }
    }
}

# Platform Detection
$script:CurrentPlatform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
$script:IsCrossPlatform = $script:CurrentPlatform -ne 'Windows'

class TestScenario {
    [string]$Name
    [string]$Description
    [object]$Config
    [hashtable]$Mocks
    [hashtable]$ExpectedInvocations
    [bool]$ShouldThrow
    [string]$ExpectedError
    [string[]]$RequiredPlatforms
    [string[]]$ExcludedPlatforms
    [scriptblock]$CustomValidation

    TestScenario([string]$Name) {
        $this.Name = $Name
        $this.Mocks = @{}
        $this.ExpectedInvocations = @{}
        $this.RequiredPlatforms = @()
        $this.ExcludedPlatforms = @()
    }

    [bool] ShouldSkip() {
        if ($this.RequiredPlatforms.Count -gt 0 -and $script:CurrentPlatform -notin $this.RequiredPlatforms) {
            return $true
        }
        if ($this.ExcludedPlatforms.Count -gt 0 -and $script:CurrentPlatform -in $this.ExcludedPlatforms) {
            return $true
        }
        return $false
    }
}

function New-TestScenario {
    <#
    .SYNOPSIS
    Creates a new test scenario with standardized configuration
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description,

        [object]$Config,

        [hashtable]$Mocks = @{},

        [hashtable]$ExpectedInvocations = @{},

        [switch]$ShouldThrow,

        [string]$ExpectedError,

        [string[]]$RequiredPlatforms = @(),

        [string[]]$ExcludedPlatforms = @(),

        [scriptblock]$CustomValidation
    )

    $scenario = TestScenario::new($Name)
    $scenario.Description = $Description
    $scenario.Config = $Config
    $scenario.Mocks = $Mocks
    $scenario.ExpectedInvocations = $ExpectedInvocations
    $scenario.ShouldThrow = $ShouldThrow
    $scenario.ExpectedError = $ExpectedError
    $scenario.RequiredPlatforms = $RequiredPlatforms
    $scenario.ExcludedPlatforms = $ExcludedPlatforms
    $scenario.CustomValidation = $CustomValidation

    return $scenario
}

function Invoke-ScriptTest {
    <#
    .SYNOPSIS
    Executes a test scenario against a runner script with comprehensive validation
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [TestScenario]$Scenario,

        [switch]$EnableVerboseLogging
    )

    try {
        # Setup mocks for this scenario
        foreach ($mockName in $Scenario.Mocks.Keys) {
            if ($EnableVerboseLogging) {
                Write-Verbose "Setting up mock for: $mockName"
            }
            if ($script:GlobalCommands -contains $mockName) {
                Mock $mockName $Scenario.Mocks[$mockName]
            } else {
                # Assume it's a LabRunner function if not in global list
                Mock $mockName $Scenario.Mocks[$mockName] -ModuleName 'LabRunner'
            }
        }

        # Execute the script
        $result = $null
        $testError = $null

        if ($Scenario.ShouldThrow) {
            if ($Scenario.ExpectedError) {
                { $result = & $ScriptPath -Config $Scenario.Config } | Should -Throw "*$($Scenario.ExpectedError)*"
            } else {
                { $result = & $ScriptPath -Config $Scenario.Config } | Should -Throw
            }
        } else {
            try {
                $result = & $ScriptPath -Config $Scenario.Config
            } catch {
                $testError = $_
                if (-not $Scenario.ShouldThrow) {
                    throw "Script failed unexpectedly: $_"
                }
            }
        }

        # Verify expected invocations
        foreach ($funcName in $Scenario.ExpectedInvocations.Keys) {
            $expectedCount = $Scenario.ExpectedInvocations[$funcName]
            if ($EnableVerboseLogging) {
                Write-Verbose "Verifying invocation count for ${funcName}: expected $expectedCount"
            }

            $invokeArgs = @{ CommandName = $funcName; Times = $expectedCount }
            if (-not ($script:GlobalCommands -contains $funcName)) {
                # If not a known global command, assume it's part of LabRunner module
                $invokeArgs.Add('ModuleName', 'LabRunner')
            }

            Should -Invoke @invokeArgs
        }

        # Run custom validation if provided
        if ($Scenario.CustomValidation) {
            & $Scenario.CustomValidation $result $testError
        }

    } catch {
        Write-Error "Test scenario '$($Scenario.Name)' failed: $_"
        throw
    }
}

function New-StandardTestMocks {
    <#
    .SYNOPSIS
    Creates comprehensive standard mocks for cross-platform testing
    #>
    param(
        [string]$LabRunnerModuleName # Module name for LabRunner specific functions
    )

    # LabRunner specific mocks
    Mock Write-CustomLog -ModuleName $LabRunnerModuleName {}
    Mock Read-LoggedInput -ModuleName $LabRunnerModuleName { 'n' }
    Mock Get-MenuSelection -ModuleName $LabRunnerModuleName { @() }

    # Global mocks (PowerShell built-ins or external commands)
    # Default Get-Command returns null. Specific scenarios or platform mocks can override for specific commands.
    Mock Get-Command { param($Name) $null }
    Mock Start-Process {}
    Mock Invoke-WebRequest {}
    Mock Invoke-RestMethod { @{ download_url = 'https://example.com/file.zip' } } # Example, can be overridden
    Mock New-Item {}
    Mock Remove-Item {}
    Mock Copy-Item {}

    # Platform-specific mocks. These functions will also use LabRunnerModuleName for LabRunner specifics
    # and mock global commands globally.
    switch ($script:CurrentPlatform) {
        'Windows' {
            New-WindowsSpecificMocks -LabRunnerModuleName $LabRunnerModuleName
        }
        'Linux' {
            New-LinuxSpecificMocks -LabRunnerModuleName $LabRunnerModuleName
        }
        'macOS' {
            New-MacOSSpecificMocks -LabRunnerModuleName $LabRunnerModuleName
        }
    }
}

function New-WindowsSpecificMocks {
    param(
        [string]$LabRunnerModuleName # For LabRunner module specific mocks, if any
    )

    # Windows Services (Global cmdlets)
    Mock Get-Service {
        [PSCustomObject]@{ Name = 'MockService'; Status = 'Running' }
    }
    Mock Start-Service {}
    Mock Stop-Service {}
    Mock Restart-Service {}

    # Windows Features (Global cmdlets)
    Mock Get-WindowsOptionalFeature {
        [PSCustomObject]@{ FeatureName = 'MockFeature'; State = 'Enabled' }
    }
    Mock Enable-WindowsOptionalFeature {}
    Mock Get-WindowsFeature {
        [PSCustomObject]@{ Name = 'MockFeature'; InstallState = 'Installed' }
    }
    Mock Install-WindowsFeature {}

    # Registry operations (Global cmdlets)
    Mock Get-ItemProperty {
        [PSCustomObject]@{ fDenyTSConnections = 0 } # Example data
    }
    Mock Set-ItemProperty {}

    # Networking (Global cmdlets)
    Mock New-NetFirewallRule {
        [PSCustomObject]@{ DisplayName = 'Mock Rule'; Enabled = $true }
    }
    Mock New-SelfSignedCertificate {
        [PSCustomObject]@{ Thumbprint = 'ABCD1234567890'; Subject = 'CN=MockCert' }
    }

    # WSMan/PowerShell Remoting (Global cmdlets)
    Mock Enable-PSRemoting {}
    Mock Test-WSMan { $true }

    # Hyper-V specific mocks (Global cmdlets, if module is available)
    if (Get-Module -ListAvailable -Name 'Hyper-V') {
        Mock Get-VM { @() }
        Mock New-VM {}
        Mock Start-VM {}
        Mock Stop-VM {}
    }

    # Common Windows package managers/installers (Global commands)
    Mock Get-Command { [PSCustomObject]@{ Name = 'choco'; Source = 'C:\\ProgramData\\chocolatey\\bin\\choco.exe' } } -ParameterFilter { $Name -eq 'choco' }
    Mock choco {}
    Mock Get-Command { [PSCustomObject]@{ Name = 'winget'; Source = 'C:\\Program Files\\WindowsApps\\Microsoft.DesktopAppInstaller\\winget.exe' } } -ParameterFilter { $Name -eq 'winget' }
    Mock winget {}
}

function New-LinuxSpecificMocks {
    param(
        [string]$LabRunnerModuleName # For LabRunner module specific mocks, if any
    )

    # Linux package managers (Global Get-Command mocks for discoverability, and global mocks for the commands themselves)
    Mock Get-Command {
        [PSCustomObject]@{ Name = 'apt-get'; Source = '/usr/bin/apt-get'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'apt-get' }
    Mock apt-get {}

    Mock Get-Command {
        [PSCustomObject]@{ Name = 'yum'; Source = '/usr/bin/yum'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'yum' }
    Mock yum {}

    Mock Get-Command {
        [PSCustomObject]@{ Name = 'dnf'; Source = '/usr/bin/dnf'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'dnf' }
    Mock dnf {}

    # systemd services (Global Get-Command and command mock)
    Mock Get-Command {
        [PSCustomObject]@{ Name = 'systemctl'; Source = '/usr/bin/systemctl'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'systemctl' }
    Mock systemctl {}
}
}

function New-MacOSSpecificMocks {
    param(
        [string]$LabRunnerModuleName # For LabRunner module specific mocks, if any
    )

    # Homebrew (Global Get-Command and command mock)
    Mock Get-Command {
        [PSCustomObject]@{ Name = 'brew'; Source = '/usr/local/bin/brew'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'brew' }
    Mock brew {}

    # macOS system commands (Global Get-Command and command mock)
    Mock Get-Command {
        [PSCustomObject]@{ Name = 'launchctl'; Source = '/bin/launchctl'; CommandType = 'Application' }
    } -ParameterFilter { $Name -eq 'launchctl' }
    Mock launchctl {}
}

function Test-RunnerScript {
    <#
    .SYNOPSIS
    Comprehensive testing function for runner scripts with multiple scenarios
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [TestScenario[]]$Scenarios = @(),

        [switch]$IncludeStandardTests = $true,

        [switch]$EnableVerboseLogging
    )

    $scriptPath = Get-RunnerScriptPath $ScriptName # This is the local, resolved script path
    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        throw "Script under test not found: $ScriptName (resolved path: $scriptPath)"
    }

    Describe "Runner Script: $ScriptName" {
        BeforeAll {
            $script:ScriptPath = $scriptPath # Set the script-scoped variable from the local resolved one
            $script:ScriptName = $ScriptName

            # Validate the script path and log an error if invalid
            if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                throw "Script path is invalid: $script:ScriptPath"
            }
        }

        if ($IncludeStandardTests) {
            Context 'Standard Validation Tests' {
                It 'has valid PowerShell syntax' {
                    # Use the script-scoped $script:ScriptPath
                    if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                        throw "Script path is invalid: $script:ScriptPath"
                    }
                    $parseErrors = $null
                    [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$parseErrors) | Out-Null
                    $parseErrors.Count | Should -Be 0
                }

                It 'has required Config parameter' {
                    # Use the script-scoped $script:ScriptPath
                    if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                        throw "Script path is invalid: $script:ScriptPath"
                    }
                    $content = Get-Content $script:ScriptPath -Raw
                    $content | Should -Match 'Param\s*\([^)]*Config[^)]*\)'
                }

                It 'imports LabRunner module' {
                    # Use the script-scoped $script:ScriptPath
                    if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                        throw "Script path is invalid: $script:ScriptPath"
                    }
                    $content = Get-Content $script:ScriptPath -Raw
                    $content | Should -Match 'Import-Module.*LabRunner'
                }

                It 'contains Invoke-LabStep call' {
                    # Use the script-scoped $script:ScriptPath
                    if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                        throw "Script path is invalid: $script:ScriptPath"
                    }
                    $content = Get-Content $script:ScriptPath -Raw
                    $content | Should -Match 'Invoke-LabStep'
                }
            }
        }

        # Execute custom scenarios
        foreach ($scenario in $Scenarios) {
            $skipReason = if ($scenario.ShouldSkip()) {
                "Skipped on $script:CurrentPlatform platform"
            } else {
                $null
            }

            It "Scenario: $($scenario.Name)" -Skip:($null -ne $skipReason) {
                if ($skipReason) {
                    Set-ItResult -Skipped -Because $skipReason
                } else {
                    InModuleScope LabRunner {
                        # Use $script:ScriptPath, which is set in BeforeAll
                        Invoke-ScriptTest -ScriptPath $script:ScriptPath -Scenario $scenario -EnableVerboseLogging:$EnableVerboseLogging
                    }
                }
            }
        }
    }
}

function New-CommonTestScenarios {
    <#
    .SYNOPSIS
    Creates common test scenarios that apply to most runner scripts
    #>
    param(
        [object]$EnabledConfig,
        [object]$DisabledConfig,
        [string]$EnabledProperty,
        [hashtable]$AdditionalMocks = @()
    )

    $scenarios = @()

    if ($EnabledConfig) {
        $scenarios += New-TestScenario -Name 'Enabled' -Description "runs when $EnabledProperty is true" -Config $EnabledConfig -Mocks $AdditionalMocks
    }

    if ($DisabledConfig) {
        $scenarios += New-TestScenario -Name 'Disabled' -Description "skips when $EnabledProperty is false" -Config $DisabledConfig -Mocks $AdditionalMocks
    }

    return $scenarios
}

# Only export functions if running as a module
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Running as script - functions are already available
} else {
    # Running as module - export functions
    Export-ModuleMember -Function @(
        'New-TestScenario',
        'Invoke-ScriptTest',
        'New-StandardTestMocks',
        'Test-RunnerScript',
        'New-CommonTestScenarios'
    )
}
