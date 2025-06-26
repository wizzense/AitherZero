#!/usr/bin/env pwsh
# Cross-Platform Utility Functions for AitherZero
# These functions provide consistent behavior across Windows, Linux, and macOS

function Get-CrossPlatformTempPath {
    <#
    .SYNOPSIS
        Gets the appropriate temporary directory path for the current platform

    .DESCRIPTION
        Returns the correct temporary directory path for Windows, Linux, or macOS
        ensuring cross-platform compatibility

    .EXAMPLE
        $tempPath = Get-CrossPlatformTempPath
    #>
    [CmdletBinding()]
    param()

    try {
        if ($IsWindows) {
            return $env:TEMP
        } elseif ($IsLinux -or $IsMacOS) {
            return '/tmp'
        } else {
            # Fallback for other platforms or older PowerShell versions
            return [System.IO.Path]::GetTempPath()
        }
    } catch {
        # Ultimate fallback
        return [System.IO.Path]::GetTempPath()
    }
}

function Get-CrossPlatformUserProfile {
    <#
    .SYNOPSIS
        Gets the user profile directory path for the current platform

    .DESCRIPTION
        Returns the correct user profile/home directory path for Windows, Linux, or macOS

    .EXAMPLE
        $userProfile = Get-CrossPlatformUserProfile
    #>
    [CmdletBinding()]
    param()

    try {
        if ($IsWindows) {
            return $env:USERPROFILE
        } elseif ($IsLinux -or $IsMacOS) {
            return $env:HOME
        } else {
            # Fallback for other platforms
            return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
    } catch {
        # Ultimate fallback
        return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
    }
}

function Get-CrossPlatformPathSeparator {
    <#
    .SYNOPSIS
        Gets the path separator character for the current platform

    .DESCRIPTION
        Returns the correct path separator (\ for Windows, / for Unix-like systems)

    .EXAMPLE
        $separator = Get-CrossPlatformPathSeparator
    #>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::DirectorySeparatorChar
}

function Join-CrossPlatformPath {
    <#
    .SYNOPSIS
        Joins path components using the correct separator for the current platform

    .DESCRIPTION
        Combines path components into a single path using the appropriate separator

    .PARAMETER PathComponents
        Array of path components to join

    .EXAMPLE
        $fullPath = Join-CrossPlatformPath @('home', 'user', 'documents', 'file.txt')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$PathComponents
    )

    return [System.IO.Path]::Combine($PathComponents)
}

function Test-CrossPlatformCommand {
    <#
    .SYNOPSIS
        Tests if a command is available on the current platform

    .DESCRIPTION
        Checks if a command/executable is available in the PATH

    .PARAMETER CommandName
        Name of the command to test

    .EXAMPLE
        if (Test-CrossPlatformCommand 'git') { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    try {
        $null = Get-Command $CommandName -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Invoke-CrossPlatformCommand {
    <#
    .SYNOPSIS
        Executes a command with platform-appropriate handling

    .DESCRIPTION
        Runs a command with proper error handling and output capture

    .PARAMETER Command
        Command to execute

    .PARAMETER Arguments
        Arguments to pass to the command

    .EXAMPLE
        $result = Invoke-CrossPlatformCommand -Command 'git' -Arguments @('status', '--porcelain')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [string[]]$Arguments = @()
    )

    try {
        if ($Arguments.Count -gt 0) {
            $result = & $Command $Arguments 2>&1
        } else {
            $result = & $Command 2>&1
        }

        return @{
            Success = $LASTEXITCODE -eq 0
            ExitCode = $LASTEXITCODE
            Output = $result
        }
    } catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = $_.Exception.Message
            Error = $_
        }
    }
}

# Functions are now available in the global scope after dot-sourcing this file
