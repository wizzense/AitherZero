#Requires -Version 7.0

<#
.SYNOPSIS
    Common test utilities and helpers for AitherZero test infrastructure

.DESCRIPTION
    This module provides common test utilities, helpers, and fixtures to reduce code duplication
    across test files and improve test quality and maintainability.

.NOTES
    - Compatible with PowerShell 7.0+ on Windows, Linux, and macOS
    - Integrates with Pester 5.0+ testing framework
    - Provides standardized test patterns and utilities
#>

# Initialize test environment
$script:TestEnvironment = @{
    ProjectRoot = $null
    TempDirectory = $null
    TestDataDirectory = $null
    MockObjects = @{}
    CleanupActions = @()
}

# Common test constants
$script:TestConstants = @{
    DefaultTimeout = 30
    MaxRetries = 3
    TempPrefix = "AitherZero-Test-"
    LogLevels = @('ERROR', 'WARN', 'INFO', 'DEBUG', 'SUCCESS')
}

# ============================================================================
# PROJECT SETUP AND ENVIRONMENT HELPERS
# ============================================================================

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initializes the test environment with project paths and utilities
    #>
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $null,
        [switch]$CreateTempDirectory
    )
    
    # Detect project root if not provided
    if (-not $ProjectRoot) {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $ProjectRoot = $currentPath
    }
    
    $script:TestEnvironment.ProjectRoot = $ProjectRoot
    $script:TestEnvironment.TestDataDirectory = Join-Path $ProjectRoot "tests/data"
    
    # Create temp directory if requested
    if ($CreateTempDirectory) {
        $script:TestEnvironment.TempDirectory = New-TestTempDirectory
    }
    
    # Register cleanup for temp directory
    Register-TestCleanup -Action {
        if ($script:TestEnvironment.TempDirectory -and (Test-Path $script:TestEnvironment.TempDirectory)) {
            Remove-Item -Path $script:TestEnvironment.TempDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host "Test environment initialized: $ProjectRoot" -ForegroundColor Green
}

function Get-TestProjectRoot {
    <#
    .SYNOPSIS
        Returns the project root directory for tests
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:TestEnvironment.ProjectRoot) {
        Initialize-TestEnvironment
    }
    
    return $script:TestEnvironment.ProjectRoot
}

function New-TestTempDirectory {
    <#
    .SYNOPSIS
        Creates a temporary directory for test use
    #>
    [CmdletBinding()]
    param(
        [string]$Prefix = $script:TestConstants.TempPrefix
    )
    
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix$(Get-Random)"
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    
    return $tempPath
}

function Register-TestCleanup {
    <#
    .SYNOPSIS
        Registers a cleanup action to be executed after tests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )
    
    $script:TestEnvironment.CleanupActions += $Action
}

function Invoke-TestCleanup {
    <#
    .SYNOPSIS
        Executes all registered cleanup actions
    #>
    [CmdletBinding()]
    param()
    
    foreach ($action in $script:TestEnvironment.CleanupActions) {
        try {
            & $action
        } catch {
            Write-Warning "Cleanup action failed: $($_.Exception.Message)"
        }
    }
    
    $script:TestEnvironment.CleanupActions = @()
}

# ============================================================================
# MODULE TESTING HELPERS
# ============================================================================

function Test-ModuleImport {
    <#
    .SYNOPSIS
        Tests if a module can be imported successfully
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [string]$ModulePath = $null,
        
        [switch]$Force
    )
    
    try {
        if ($ModulePath) {
            Import-Module $ModulePath -Force:$Force -ErrorAction Stop
        } else {
            Import-Module $ModuleName -Force:$Force -ErrorAction Stop
        }
        
        $module = Get-Module -Name $ModuleName
        return @{
            Success = $true
            Module = $module
            ExportedCommands = $module.ExportedCommands.Keys
            ModuleVersion = $module.Version
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Module = $null
            ExportedCommands = @()
        }
    }
}

function Test-ModuleFunction {
    <#
    .SYNOPSIS
        Tests if a module function exists and has basic help
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$FunctionName
    )
    
    try {
        $command = Get-Command -Name $FunctionName -Module $ModuleName -ErrorAction Stop
        $help = Get-Help -Name $FunctionName -ErrorAction SilentlyContinue
        
        return @{
            Success = $true
            Command = $command
            HasHelp = ($help -and $help.Synopsis -and $help.Synopsis -ne $FunctionName)
            Parameters = $command.Parameters.Keys
            CommandType = $command.CommandType
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Command = $null
            HasHelp = $false
            Parameters = @()
        }
    }
}

function Get-ModuleTestData {
    <#
    .SYNOPSIS
        Retrieves test data for a specific module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [string]$DataFile = "test-data.json"
    )
    
    $testDataPath = Join-Path $script:TestEnvironment.TestDataDirectory $ModuleName $DataFile
    
    if (Test-Path $testDataPath) {
        try {
            $content = Get-Content -Path $testDataPath -Raw
            return $content | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to load test data from $testDataPath`: $($_.Exception.Message)"
            return $null
        }
    }
    
    return $null
}

# ============================================================================
# MOCK AND STUB HELPERS
# ============================================================================

function New-TestMock {
    <#
    .SYNOPSIS
        Creates a mock object for testing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [hashtable]$Properties = @{},
        
        [hashtable]$Methods = @{}
    )
    
    $mock = New-Object -TypeName PSObject
    
    # Add properties
    foreach ($prop in $Properties.GetEnumerator()) {
        $mock | Add-Member -MemberType NoteProperty -Name $prop.Key -Value $prop.Value
    }
    
    # Add methods
    foreach ($method in $Methods.GetEnumerator()) {
        $mock | Add-Member -MemberType ScriptMethod -Name $method.Key -Value $method.Value
    }
    
    # Store mock for cleanup
    $script:TestEnvironment.MockObjects[$Name] = $mock
    
    return $mock
}

function Get-TestMock {
    <#
    .SYNOPSIS
        Retrieves a previously created mock object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    return $script:TestEnvironment.MockObjects[$Name]
}

function Remove-TestMock {
    <#
    .SYNOPSIS
        Removes a mock object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    if ($script:TestEnvironment.MockObjects.ContainsKey($Name)) {
        $script:TestEnvironment.MockObjects.Remove($Name)
    }
}

# ============================================================================
# ASSERTION HELPERS
# ============================================================================

function Assert-ModuleLoaded {
    <#
    .SYNOPSIS
        Asserts that a module is loaded
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )
    
    $module = Get-Module -Name $ModuleName
    if (-not $module) {
        throw "Module '$ModuleName' is not loaded"
    }
    
    return $module
}

function Assert-FunctionExists {
    <#
    .SYNOPSIS
        Asserts that a function exists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,
        
        [string]$ModuleName = $null
    )
    
    $command = if ($ModuleName) {
        Get-Command -Name $FunctionName -Module $ModuleName -ErrorAction SilentlyContinue
    } else {
        Get-Command -Name $FunctionName -ErrorAction SilentlyContinue
    }
    
    if (-not $command) {
        $moduleText = if ($ModuleName) { " in module '$ModuleName'" } else { "" }
        throw "Function '$FunctionName' does not exist$moduleText"
    }
    
    return $command
}

function Assert-PathExists {
    <#
    .SYNOPSIS
        Asserts that a path exists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$ItemType = $null
    )
    
    if (-not (Test-Path $Path)) {
        throw "Path '$Path' does not exist"
    }
    
    if ($ItemType) {
        $item = Get-Item -Path $Path
        if ($item.GetType().Name -ne $ItemType) {
            throw "Path '$Path' is not of type '$ItemType'"
        }
    }
    
    return $Path
}

function Assert-JsonValid {
    <#
    .SYNOPSIS
        Asserts that a string is valid JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JsonString
    )
    
    try {
        $parsed = $JsonString | ConvertFrom-Json
        return $parsed
    } catch {
        throw "Invalid JSON: $($_.Exception.Message)"
    }
}

# ============================================================================
# RETRY AND TIMEOUT HELPERS
# ============================================================================

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Invokes a script block with retry logic
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = $script:TestConstants.MaxRetries,
        
        [int]$DelaySeconds = 1,
        
        [string]$Operation = "Operation"
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            return & $ScriptBlock
        } catch {
            $lastError = $_
            if ($attempt -lt $MaxRetries) {
                Write-Host "Attempt $attempt failed, retrying in $DelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
    
    throw "Operation '$Operation' failed after $MaxRetries attempts. Last error: $($lastError.Exception.Message)"
}

function Invoke-WithTimeout {
    <#
    .SYNOPSIS
        Invokes a script block with timeout
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$TimeoutSeconds = $script:TestConstants.DefaultTimeout,
        
        [string]$Operation = "Operation"
    )
    
    $job = Start-Job -ScriptBlock $ScriptBlock
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    
    if ($completed) {
        $result = Receive-Job -Job $job
        Remove-Job -Job $job
        return $result
    } else {
        Stop-Job -Job $job
        Remove-Job -Job $job
        throw "Operation '$Operation' timed out after $TimeoutSeconds seconds"
    }
}

# ============================================================================
# CONFIGURATION TESTING HELPERS
# ============================================================================

function Test-ConfigurationFile {
    <#
    .SYNOPSIS
        Tests if a configuration file is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string[]]$RequiredKeys = @(),
        
        [string]$Format = "json"
    )
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $content = Get-Content -Path $ConfigPath -Raw
        
        $config = switch ($Format.ToLower()) {
            "json" { $content | ConvertFrom-Json }
            "xml" { [xml]$content }
            default { throw "Unsupported format: $Format" }
        }
        
        # Check required keys for JSON
        if ($Format -eq "json" -and $RequiredKeys) {
            foreach ($key in $RequiredKeys) {
                if (-not $config.PSObject.Properties.Name.Contains($key)) {
                    throw "Required key '$key' not found in configuration"
                }
            }
        }
        
        return @{
            Success = $true
            Config = $config
            Path = $ConfigPath
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Path = $ConfigPath
        }
    }
}

function New-TestConfiguration {
    <#
    .SYNOPSIS
        Creates a test configuration file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [string]$Format = "json",
        
        [string]$OutputPath = $null
    )
    
    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:TestEnvironment.TempDirectory "test-config.$Format"
    }
    
    try {
        $content = switch ($Format.ToLower()) {
            "json" { $Configuration | ConvertTo-Json -Depth 10 }
            default { throw "Unsupported format: $Format" }
        }
        
        $content | Out-File -FilePath $OutputPath -Encoding UTF8
        
        # Register for cleanup
        Register-TestCleanup -Action {
            if (Test-Path $OutputPath) {
                Remove-Item -Path $OutputPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        return $OutputPath
    } catch {
        throw "Failed to create test configuration: $($_.Exception.Message)"
    }
}

# ============================================================================
# PLATFORM TESTING HELPERS
# ============================================================================

function Test-PlatformSupport {
    <#
    .SYNOPSIS
        Tests if current platform is supported
    #>
    [CmdletBinding()]
    param(
        [string[]]$SupportedPlatforms = @('Windows', 'Linux', 'macOS')
    )
    
    $currentPlatform = if ($IsWindows) { 'Windows' }
                      elseif ($IsLinux) { 'Linux' }
                      elseif ($IsMacOS) { 'macOS' }
                      else { 'Unknown' }
    
    return @{
        CurrentPlatform = $currentPlatform
        IsSupported = $currentPlatform -in $SupportedPlatforms
        SupportedPlatforms = $SupportedPlatforms
    }
}

function Skip-IfPlatformNotSupported {
    <#
    .SYNOPSIS
        Skips test if current platform is not supported
    #>
    [CmdletBinding()]
    param(
        [string[]]$SupportedPlatforms = @('Windows', 'Linux', 'macOS')
    )
    
    $platformInfo = Test-PlatformSupport -SupportedPlatforms $SupportedPlatforms
    
    if (-not $platformInfo.IsSupported) {
        Write-Host "Skipping test - platform '$($platformInfo.CurrentPlatform)' not supported" -ForegroundColor Yellow
        return $true
    }
    
    return $false
}

# ============================================================================
# EXPORT MEMBERS
# ============================================================================

Export-ModuleMember -Function @(
    'Initialize-TestEnvironment',
    'Get-TestProjectRoot',
    'New-TestTempDirectory',
    'Register-TestCleanup',
    'Invoke-TestCleanup',
    'Test-ModuleImport',
    'Test-ModuleFunction',
    'Get-ModuleTestData',
    'New-TestMock',
    'Get-TestMock',
    'Remove-TestMock',
    'Assert-ModuleLoaded',
    'Assert-FunctionExists',
    'Assert-PathExists',
    'Assert-JsonValid',
    'Invoke-WithRetry',
    'Invoke-WithTimeout',
    'Test-ConfigurationFile',
    'New-TestConfiguration',
    'Test-PlatformSupport',
    'Skip-IfPlatformNotSupported'
)