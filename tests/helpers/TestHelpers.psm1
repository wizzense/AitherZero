# Test Helper Functions for OpenTofu Lab Automation
# Provides common utilities for test discovery and execution

# Import test configuration
$TestConfig = Import-PowerShellDataFile (Join-Path $PSScriptRoot "TestConfiguration.psd1")

function Get-TestConfiguration {
    <#
    .SYNOPSIS
    Get the current test configuration
    
    .DESCRIPTION
    Returns the test configuration loaded from TestConfiguration.psd1
    #>
    return $TestConfig
}

function Write-TestLog {
    <#
    .SYNOPSIS
    Write a test log message with consistent formatting
    
    .PARAMETER Message
    The message to log
    
    .PARAMETER Level
    The log level: INFO, WARN, ERROR, SUCCESS
    
    .PARAMETER NoNewline
    Don't add a newline after the message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [switch]$NoNewline
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
        default { 'White' }
    }
    
    $prefix = "[$timestamp] [$Level]"
    
    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

function Test-ModuleStructure {
    <#
    .SYNOPSIS
    Test if a module has the expected structure
    
    .PARAMETER ModulePath
    Path to the module directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )
    
    $result = @{
        Path = $ModulePath
        HasManifest = $false
        HasModuleFile = $false
        HasPublicFolder = $false
        HasPrivateFolder = $false
        IsValid = $false
        Issues = @()
    }
    
    if (-not (Test-Path $ModulePath)) {
        $result.Issues += "Module path does not exist: $ModulePath"
        return $result
    }
    
    # Check for manifest
    $manifestFiles = Get-ChildItem $ModulePath -Filter "*.psd1"
    if ($manifestFiles.Count -gt 0) {
        $result.HasManifest = $true
        
        # Test manifest validity
        try {
            Test-ModuleManifest $manifestFiles[0].FullName -ErrorAction Stop | Out-Null
        }
        catch {
            $result.Issues += "Invalid module manifest: $($_.Exception.Message)"
        }
    }
    
    # Check for module file
    $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
    if ($moduleFiles.Count -gt 0) {
        $result.HasModuleFile = $true
    }
    
    # Check for Public/Private folders
    $result.HasPublicFolder = Test-Path (Join-Path $ModulePath "Public")
    $result.HasPrivateFolder = Test-Path (Join-Path $ModulePath "Private")
    
    # Determine if valid
    $result.IsValid = ($result.HasManifest -or $result.HasModuleFile) -and ($result.Issues.Count -eq 0)
    
    return $result
}

function Get-ModuleFunctions {
    <#
    .SYNOPSIS
    Get all functions from a module
    
    .PARAMETER ModulePath
    Path to the module
    
    .PARAMETER IncludePrivate
    Include private functions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath,
        
        [switch]$IncludePrivate
    )
    
    $functions = @{
        Public = @()
        Private = @()
        Exported = @()
    }
    
    try {
        # Import module temporarily
        $module = Import-Module $ModulePath -Force -PassThru -ErrorAction Stop
        
        # Get exported functions
        $exportedCommands = Get-Command -Module $module.Name -CommandType Function -ErrorAction SilentlyContinue
        $functions.Exported = $exportedCommands | ForEach-Object { $_.Name }
        
        # Get public functions from files
        $publicPath = Join-Path $ModulePath "Public"
        if (Test-Path $publicPath) {
            $publicFiles = Get-ChildItem $publicPath -Filter "*.ps1"
            $functions.Public = $publicFiles | ForEach-Object { $_.BaseName }
        }
        
        # Get private functions from files
        if ($IncludePrivate) {
            $privatePath = Join-Path $ModulePath "Private"
            if (Test-Path $privatePath) {
                $privateFiles = Get-ChildItem $privatePath -Filter "*.ps1"
                $functions.Private = $privateFiles | ForEach-Object { $_.BaseName }
            }
        }
        
        # Clean up
        Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-TestLog "Error analyzing module $ModulePath`: $($_.Exception.Message)" -Level ERROR
    }
    
    return $functions
}

function Test-PowerShellSyntax {
    <#
    .SYNOPSIS
    Test PowerShell script syntax
    
    .PARAMETER FilePath
    Path to the PowerShell file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $result = @{
        File = $FilePath
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $FilePath, 
            [ref]$tokens, 
            [ref]$errors
        )
        
        if ($errors.Count -gt 0) {
            $result.IsValid = $false
            $result.Errors = $errors | ForEach-Object { $_.ToString() }
        }
        
        # Additional syntax checks can be added here
        
    }
    catch {
        $result.IsValid = $false
        $result.Errors += "Parse error: $($_.Exception.Message)"
    }
    
    return $result
}

function New-TestResultSummary {
    <#
    .SYNOPSIS
    Create a standardized test result summary
    
    .PARAMETER TestName
    Name of the test
    
    .PARAMETER Status
    Test status: PASSED, FAILED, SKIPPED, ERROR
    
    .PARAMETER Details
    Additional details about the test
    
    .PARAMETER Duration
    Test execution duration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestName,
        
        [Parameter(Mandatory)]
        [ValidateSet('PASSED', 'FAILED', 'SKIPPED', 'ERROR')]
        [string]$Status,
        
        [string]$Details = '',
        
        [timespan]$Duration = [timespan]::Zero
    )
    
    return [PSCustomObject]@{
        TestName = $TestName
        Status = $Status
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date
    }
}

function Format-TestDuration {
    <#
    .SYNOPSIS
    Format a timespan for test duration display
    
    .PARAMETER Duration
    The timespan to format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [timespan]$Duration
    )
    
    if ($Duration.TotalSeconds -lt 1) {
        return "$($Duration.TotalMilliseconds.ToString('0'))ms"
    } elseif ($Duration.TotalMinutes -lt 1) {
        return "$($Duration.TotalSeconds.ToString('0.0'))s"
    } else {
        return "$($Duration.TotalMinutes.ToString('0'))m $($Duration.Seconds)s"
    }
}

# Auto-export functions when module is imported
Export-ModuleMember -Function @(
    'Get-TestConfiguration',
    'Write-TestLog',
    'Test-ModuleStructure',
    'Get-ModuleFunctions',
    'Test-PowerShellSyntax',
    'New-TestResultSummary',
    'Format-TestDuration'
)