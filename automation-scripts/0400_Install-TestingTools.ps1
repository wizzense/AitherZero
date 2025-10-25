#Requires -Version 7.0

<#
.SYNOPSIS
    Install testing and validation tools for AitherZero
.DESCRIPTION
    Installs Pester, PSScriptAnalyzer, and other testing dependencies
    
    Exit Codes:
    0   - Success
    1   - General failure
    3010 - Success, restart required
    
.NOTES
    Stage: Testing
    Order: 0400
    Dependencies: 0001
    Tags: testing, pester, psscriptanalyzer, quality
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0400
    Dependencies = @('0001')
    Tags = @('testing', 'pester', 'psscriptanalyzer', 'quality')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import logging if available
$loggingModule = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0400_Install-TestingTools" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

try {
    Write-ScriptLog -Message "Starting testing tools installation"

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would install testing tools"
        Write-ScriptLog -Message "Tools to install: Pester 5.0+, PSScriptAnalyzer, Plaster"
        exit 0
    }

    # Load configuration
    $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.psd1"
    if (Test-Path $configPath) {
        $config = Import-PowerShellDataFile $configPath
        $testingConfig = $config.Testing
    } else {
        Write-ScriptLog -Level Warning -Message "Configuration file not found, using defaults"
        $testingConfig = @{
            Framework = 'Pester'
            MinVersion = '5.0.0'
        }
    }

    # Install PowerShellGet if needed
    Write-ScriptLog -Message "Checking PowerShellGet version"
    $psGetModule = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $psGetModule -or $psGetModule.Version -lt [Version]'2.2.5') {
        Write-ScriptLog -Message "Installing PowerShellGet 2.2.5+"
        if ($PSCmdlet.ShouldProcess("PowerShellGet module", "Install module version 2.2.5+")) {
            Install-Module -Name PowerShellGet -MinimumVersion 2.2.5 -Force -AllowClobber -Scope CurrentUser
        }
    }

    # Configure PSGallery as trusted
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Write-ScriptLog -Message "Setting PSGallery as trusted repository"
        if ($PSCmdlet.ShouldProcess("PSGallery repository", "Set installation policy to Trusted")) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
    }

    # Install Pester
    Write-ScriptLog -Message "Installing Pester $($testingConfig.MinVersion)+"
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge $testingConfig.MinVersion }

    if (-not $pesterModule -or $Force) {
        # Remove old Pester versions that ship with Windows
        $oldPester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -lt '5.0.0' }
        if ($oldPester) {
            Write-ScriptLog -Level Warning -Message "Removing old Pester versions"
            foreach ($module in $oldPester) {
                if ($module.Path -like "*\WindowsPowerShell\*") {
                    Write-ScriptLog -Level Warning -Message "Cannot remove built-in Pester from: $($module.Path)"
                } else {
                    if ($PSCmdlet.ShouldProcess("Old Pester module", "Remove module version < 5.0.0")) {
                        Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
                        Uninstall-Module -Name Pester -MaximumVersion 4.99.99 -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        if ($PSCmdlet.ShouldProcess("Pester module", "Install version $($testingConfig.MinVersion)+")) {
            Install-Module -Name Pester -MinimumVersion $testingConfig.MinVersion -Force -SkipPublisherCheck -Scope CurrentUser
        }
        Write-ScriptLog -Message "Pester installed successfully"
    } else {
        Write-ScriptLog -Message "Pester $($pesterModule.Version) already installed"
    }

    # Install PSScriptAnalyzer
    Write-ScriptLog -Message "Installing PSScriptAnalyzer"
    $psaModule = Get-Module -ListAvailable -Name PSScriptAnalyzer

    if (-not $psaModule -or $Force) {
        if ($PSCmdlet.ShouldProcess("PSScriptAnalyzer module", "Install module")) {
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
        }
        Write-ScriptLog -Message "PSScriptAnalyzer installed successfully"
    } else {
        Write-ScriptLog -Message "PSScriptAnalyzer $($psaModule.Version) already installed"
    }

    # Install Plaster (for test scaffolding)
    Write-ScriptLog -Message "Installing Plaster (test scaffolding)"
    $plasterModule = Get-Module -ListAvailable -Name Plaster

    if (-not $plasterModule -or $Force) {
        if ($PSCmdlet.ShouldProcess("Plaster module", "Install module")) {
            Install-Module -Name Plaster -Force -Scope CurrentUser
        }
        Write-ScriptLog -Message "Plaster installed successfully"
    } else {
        Write-ScriptLog -Message "Plaster $($plasterModule.Version) already installed"
    }

    # Verify installations
    Write-ScriptLog -Message "Verifying installations"
    
    $verificationResults = @{
        Pester = (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge $testingConfig.MinVersion }) -ne $null
        PSScriptAnalyzer = (Get-Module -ListAvailable -Name PSScriptAnalyzer) -ne $null
        Plaster = (Get-Module -ListAvailable -Name Plaster) -ne $null
    }
    
    $allInstalled = $verificationResults.Values -notcontains $false

    if ($allInstalled) {
        Write-ScriptLog -Message "All testing tools installed successfully" -Data $verificationResults
        
        # Import modules to verify they work
        Import-Module Pester -MinimumVersion $testingConfig.MinVersion -Force
        Import-Module PSScriptAnalyzer -Force
        Import-Module Plaster -Force
        
        Write-ScriptLog -Message "Testing tools verified and loaded"
    } else {
        Write-ScriptLog -Level Error -Message "Some tools failed to install" -Data $verificationResults
        exit 1
    }

    # Create PSScriptAnalyzer settings file if it doesn't exist
    $psaSettingsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "PSScriptAnalyzerSettings.psd1"
    if (-not (Test-Path $psaSettingsPath)) {
        Write-ScriptLog -Message "Creating PSScriptAnalyzer settings file"
        
        $psaSettings = @'
@{
    # Select which rules to run
    IncludeRules = @('*')

    # Exclude specific rules
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',  # We use Write-Host for UI output
        'PSUseShouldProcessForStateChangingFunctions'  # Not all functions need ShouldProcess
    )

    # Rule-specific settings
    Rules = @{
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            Placement = "begin"
        }
        
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('7.0')
        }
    }

    # Code formatting settings
    CodeFormatting = @{
        UseCorrectCasing = $true
        WhitespaceInsideBrace = $true
        WhitespaceAroundOperator = $true
        WhitespaceAfterSeparator = $true
        IgnoreOneLineBlock = $true
        NewLineAfterOpenBrace = $true
        NewLineAfterCloseBrace = $true
    }
}
'@
        
        if ($PSCmdlet.ShouldProcess($psaSettingsPath, "Create PSScriptAnalyzer settings file")) {
            $psaSettings | Set-Content -Path $psaSettingsPath -Force
        }
        Write-ScriptLog -Message "PSScriptAnalyzer settings created at: $psaSettingsPath"
    }
    
    Write-ScriptLog -Message "Testing tools installation completed successfully"
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to install testing tools: $_" -Data @{ Exception = $_.Exception.Message }
    exit 1
}
