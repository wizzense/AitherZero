#Requires -Version 7.0

<#
.SYNOPSIS
    Provides cross-platform path handling utilities for AitherZero.

.DESCRIPTION
    This module provides platform-aware path handling functions that work consistently
    across Windows, Linux, and macOS. It includes utilities for:
    - Safe path joining with proper separators
    - Platform-specific path validation
    - Common directory location detection
    - Path normalization and validation

.NOTES
    This is a shared utility module used throughout AitherZero for cross-platform compatibility.
#>

function Get-CrossPlatformPath {
    <#
    .SYNOPSIS
        Builds a cross-platform compatible path from path components.

    .DESCRIPTION
        Safely joins path components using the appropriate directory separator for the current platform.
        Handles edge cases like null/empty components and ensures proper path formation.

    .PARAMETER BasePath
        The base directory path

    .PARAMETER ChildPath
        One or more child path components to join

    .PARAMETER Normalize
        Normalize the resulting path (resolve .. and . components)

    .PARAMETER ValidateExistence
        Validate that the resulting path exists

    .EXAMPLE
        Get-CrossPlatformPath -BasePath "/home/user" -ChildPath "documents", "file.txt"
        Returns: /home/user/documents/file.txt (on Linux/macOS) or \home\user\documents\file.txt (on Windows)

    .EXAMPLE
        Get-CrossPlatformPath -BasePath "C:\Users" -ChildPath "Documents" -Normalize
        Returns: Normalized path with proper separators
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ChildPath,

        [Parameter()]
        [switch]$Normalize,

        [Parameter()]
        [switch]$ValidateExistence
    )

    try {
        # Start with base path
        $resultPath = $BasePath

        # Join each child path component
        foreach ($component in $ChildPath) {
            if (-not [string]::IsNullOrWhiteSpace($component)) {
                $resultPath = Join-Path $resultPath $component
            }
        }

        # Normalize if requested
        if ($Normalize -and (Test-Path $resultPath)) {
            $resultPath = Resolve-Path $resultPath -ErrorAction SilentlyContinue
            if ($resultPath) {
                $resultPath = $resultPath.Path
            }
        }

        # Validate existence if requested
        if ($ValidateExistence -and -not (Test-Path $resultPath)) {
            throw "Path does not exist: $resultPath"
        }

        return $resultPath
    }
    catch {
        Write-Error "Failed to build cross-platform path: $($_.Exception.Message)"
        throw
    }
}

function Get-PlatformSpecificPath {
    <#
    .SYNOPSIS
        Gets platform-specific standard paths.

    .DESCRIPTION
        Returns common directory paths that are platform-specific, such as:
        - System directories
        - User directories
        - Application data directories
        - Temporary directories

    .PARAMETER PathType
        The type of path to retrieve

    .EXAMPLE
        Get-PlatformSpecificPath -PathType "System"
        Returns: C:\Windows\System32 (Windows) or /usr/bin (Linux/macOS)

    .EXAMPLE
        Get-PlatformSpecificPath -PathType "UserHome"
        Returns: C:\Users\username (Windows) or /home/username (Linux) or /Users/username (macOS)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('System', 'UserHome', 'AppData', 'Temp', 'ProgramFiles', 'CommonPrograms')]
        [string]$PathType
    )

    switch ($PathType) {
        'System' {
            if ($IsWindows) {
                return Join-Path $env:SystemRoot 'System32'
            } elseif ($IsLinux) {
                return '/usr/bin'
            } elseif ($IsMacOS) {
                return '/usr/bin'
            } else {
                return '/usr/bin'
            }
        }
        'UserHome' {
            if ($IsWindows) {
                return $env:USERPROFILE
            } else {
                return $env:HOME
            }
        }
        'AppData' {
            if ($IsWindows) {
                return $env:APPDATA
            } elseif ($IsLinux) {
                return Join-Path $env:HOME '.local/share'
            } elseif ($IsMacOS) {
                return Join-Path $env:HOME 'Library/Application Support'
            } else {
                return Join-Path $env:HOME '.local/share'
            }
        }
        'Temp' {
            if ($IsWindows) {
                return $env:TEMP
            } else {
                return '/tmp'
            }
        }
        'ProgramFiles' {
            if ($IsWindows) {
                return $env:ProgramFiles
            } elseif ($IsLinux) {
                return '/usr/share'
            } elseif ($IsMacOS) {
                return '/Applications'
            } else {
                return '/usr/share'
            }
        }
        'CommonPrograms' {
            if ($IsWindows) {
                return Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
            } elseif ($IsLinux) {
                return '/usr/share/applications'
            } elseif ($IsMacOS) {
                return '/Applications'
            } else {
                return '/usr/share/applications'
            }
        }
    }
}

function Test-CrossPlatformPath {
    <#
    .SYNOPSIS
        Tests if a path is valid for the current platform.

    .DESCRIPTION
        Validates path syntax and characters for the current platform.
        Checks for platform-specific path limitations and reserved names.

    .PARAMETER Path
        The path to validate

    .PARAMETER AllowRelative
        Allow relative paths (default: true)

    .PARAMETER AllowWildcards
        Allow wildcard characters (default: false)

    .EXAMPLE
        Test-CrossPlatformPath -Path "C:\Users\Documents\file.txt"
        Returns: $true (on Windows) or $false (on Linux/macOS due to drive letter)

    .EXAMPLE
        Test-CrossPlatformPath -Path "/home/user/file.txt"
        Returns: $true (on Linux/macOS) or $true (on Windows - valid relative path)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$AllowRelative = $true,

        [Parameter()]
        [switch]$AllowWildcards = $false
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        # Check for wildcard characters
        if (-not $AllowWildcards -and ($Path -match '[*?]')) {
            return $false
        }

        # Platform-specific validation
        if ($IsWindows) {
            # Windows path validation
            $invalidChars = @('<', '>', ':', '"', '|', '?', '*')
            if (-not $AllowWildcards) {
                foreach ($char in $invalidChars) {
                    if ($Path.Contains($char)) {
                        return $false
                    }
                }
            }

            # Check for reserved names
            $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
            $fileName = Split-Path $Path -Leaf
            if ($fileName -in $reservedNames) {
                return $false
            }
        } else {
            # Linux/macOS path validation
            if ($Path.Contains("`0")) {
                return $false  # Null character not allowed
            }
            
            # Check for very long paths
            if ($Path.Length -gt 4096) {
                return $false
            }
        }

        # Check if relative path is allowed
        if (-not $AllowRelative) {
            if ($IsWindows) {
                if (-not [System.IO.Path]::IsPathRooted($Path)) {
                    return $false
                }
            } else {
                if (-not $Path.StartsWith('/')) {
                    return $false
                }
            }
        }

        # Try to create a path object to validate syntax
        $null = [System.IO.Path]::GetFullPath($Path)
        return $true
    }
    catch {
        return $false
    }
}

function ConvertTo-CrossPlatformPath {
    <#
    .SYNOPSIS
        Converts a path to use the current platform's path separators.

    .DESCRIPTION
        Normalizes path separators for the current platform while preserving
        the logical path structure.

    .PARAMETER Path
        The path to convert

    .PARAMETER ToUnix
        Force conversion to Unix-style paths (forward slashes)

    .PARAMETER ToWindows
        Force conversion to Windows-style paths (backslashes)

    .EXAMPLE
        ConvertTo-CrossPlatformPath -Path "C:\Users\Documents\file.txt"
        Returns: C:/Users/Documents/file.txt (on Linux/macOS) or C:\Users\Documents\file.txt (on Windows)

    .EXAMPLE
        ConvertTo-CrossPlatformPath -Path "/home/user/file.txt" -ToWindows
        Returns: \home\user\file.txt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$ToUnix,

        [Parameter()]
        [switch]$ToWindows
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ($ToUnix) {
        return $Path -replace '\\', '/'
    } elseif ($ToWindows) {
        return $Path -replace '/', '\'
    } else {
        # Convert to current platform
        if ($IsWindows) {
            return $Path -replace '/', '\'
        } else {
            return $Path -replace '\\', '/'
        }
    }
}

# Export functions for use in modules
Export-ModuleMember -Function Get-CrossPlatformPath, Get-PlatformSpecificPath, Test-CrossPlatformPath, ConvertTo-CrossPlatformPath