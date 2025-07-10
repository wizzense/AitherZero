# Simplified PowerShell version checking utility
# Supports PowerShell 5.1+ for cross-platform compatibility

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests if the current PowerShell version meets requirements

    .DESCRIPTION
        Checks PowerShell version and provides upgrade guidance if needed.
        Supports PowerShell 5.1+ for cross-platform compatibility.

    .PARAMETER MinimumVersion
        Minimum required PowerShell version (default: 7.0)

    .PARAMETER Quiet
        Suppress all output, only return boolean

    .EXAMPLE
        Test-PowerShellVersion -MinimumVersion "7.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [version]$MinimumVersion = "7.0",

        [Parameter()]
        [switch]$Quiet
    )

    $currentVersion = $PSVersionTable.PSVersion
    $meetsRequirement = $currentVersion -ge $MinimumVersion

    if ($Quiet) {
        return $meetsRequirement
    }

    if (-not $meetsRequirement) {
        Write-Host "PowerShell $MinimumVersion or later is required." -ForegroundColor Yellow
        Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To install PowerShell 7:" -ForegroundColor Cyan

        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
            Write-Host "  winget install Microsoft.PowerShell" -ForegroundColor Green
            Write-Host "  or visit: https://aka.ms/powershell-release" -ForegroundColor Green
        } elseif ($IsLinux) {
            Write-Host "  Visit: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-linux" -ForegroundColor Green
        } elseif ($IsMacOS) {
            Write-Host "  brew install --cask powershell" -ForegroundColor Green
            Write-Host "  or visit: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-macos" -ForegroundColor Green
        }
    }

    return $meetsRequirement
}

function Find-PowerShell7 {
    <#
    .SYNOPSIS
        Enhanced PowerShell 7 detection with comprehensive path searching

    .DESCRIPTION
        Searches for PowerShell 7 installation using multiple methods:
        1. Get-Command (most reliable)
        2. Registry search (Windows)
        3. Common installation paths
        4. PATH environment variable
        5. User-specific installations

    .PARAMETER IncludePreview
        Include PowerShell 7 preview versions

    .EXAMPLE
        $pwsh7Path = Find-PowerShell7
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludePreview
    )

    $foundPaths = @()

    # Method 1: Get-Command (most reliable)
    try {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCmd -and $pwshCmd.Source) {
            $version = & $pwshCmd.Source --version 2>$null
            if ($version -and $version -match "PowerShell (\d+\.\d+\.\d+)") {
                $foundPaths += @{
                    Path = $pwshCmd.Source
                    Version = $matches[1]
                    Method = "Get-Command"
                    IsPreview = $version -match "preview"
                }
            }
        }
    } catch {
        Write-Verbose "Get-Command method failed: $_"
    }

    # Method 2: Registry search (Windows only)
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
        try {
            $registryPaths = @(
                "HKLM:\SOFTWARE\Microsoft\PowerShell\7\InstallPath",
                "HKCU:\SOFTWARE\Microsoft\PowerShell\7\InstallPath"
            )
            
            foreach ($regPath in $registryPaths) {
                if (Test-Path $regPath) {
                    $installPath = Get-ItemProperty -Path $regPath -Name "(default)" -ErrorAction SilentlyContinue
                    if ($installPath) {
                        $pwshPath = Join-Path $installPath."(default)" "pwsh.exe"
                        if (Test-Path $pwshPath) {
                            $version = & $pwshPath --version 2>$null
                            if ($version -and $version -match "PowerShell (\d+\.\d+\.\d+)") {
                                $foundPaths += @{
                                    Path = $pwshPath
                                    Version = $matches[1]
                                    Method = "Registry"
                                    IsPreview = $version -match "preview"
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "Registry search failed: $_"
        }
    }

    # Method 3: Common installation paths
    $searchPaths = @()

    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
        $searchPaths += @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",
            "$env:USERPROFILE\AppData\Local\Microsoft\PowerShell\7\pwsh.exe"
        )
        
        if ($IncludePreview) {
            $searchPaths += @(
                "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe",
                "${env:ProgramFiles(x86)}\PowerShell\7-preview\pwsh.exe",
                "$env:LOCALAPPDATA\Microsoft\PowerShell\7-preview\pwsh.exe"
            )
        }
    } else {
        $searchPaths += @(
            "/usr/local/bin/pwsh",
            "/usr/bin/pwsh",
            "/opt/microsoft/powershell/7/pwsh",
            "/snap/bin/pwsh",
            "$env:HOME/.local/bin/pwsh",
            "$env:HOME/bin/pwsh"
        )
        
        if ($IncludePreview) {
            $searchPaths += @(
                "/opt/microsoft/powershell/7-preview/pwsh",
                "/snap/bin/powershell-preview"
            )
        }
    }

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            try {
                $version = & $path --version 2>$null
                if ($version -and $version -match "PowerShell (\d+\.\d+\.\d+)") {
                    $foundPaths += @{
                        Path = $path
                        Version = $matches[1]
                        Method = "PathSearch"
                        IsPreview = $version -match "preview"
                    }
                }
            } catch {
                Write-Verbose "Failed to get version from $path`: $_"
            }
        }
    }

    # Method 4: Search PATH environment variable
    try {
        $pathDirs = $env:PATH -split [IO.Path]::PathSeparator
        foreach ($dir in $pathDirs) {
            if ([string]::IsNullOrWhiteSpace($dir)) { continue }
            
            $pwshPath = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
                Join-Path $dir "pwsh.exe"
            } else {
                Join-Path $dir "pwsh"
            }
            
            if (Test-Path $pwshPath) {
                try {
                    $version = & $pwshPath --version 2>$null
                    if ($version -and $version -match "PowerShell (\d+\.\d+\.\d+)") {
                        $foundPaths += @{
                            Path = $pwshPath
                            Version = $matches[1]
                            Method = "PATH"
                            IsPreview = $version -match "preview"
                        }
                    }
                } catch {
                    Write-Verbose "Failed to get version from $pwshPath`: $_"
                }
            }
        }
    } catch {
        Write-Verbose "PATH search failed: $_"
    }

    # Remove duplicates and filter preview versions if not requested
    $uniquePaths = @{}
    foreach ($pathInfo in $foundPaths) {
        $key = $pathInfo.Path.ToLower()
        if (-not $uniquePaths.ContainsKey($key)) {
            if ($IncludePreview -or -not $pathInfo.IsPreview) {
                $uniquePaths[$key] = $pathInfo
            }
        }
    }

    # Return the best match (prefer stable over preview, higher version)
    if ($uniquePaths.Count -gt 0) {
        $bestMatch = $uniquePaths.Values | Sort-Object @{
            Expression = { if ($_.IsPreview) { 0 } else { 1 } }; Descending = $true
        }, @{
            Expression = { [Version]$_.Version }; Descending = $true
        } | Select-Object -First 1
        
        return $bestMatch.Path
    }

    return $null
}

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Tests network connectivity for PowerShell installation
    
    .DESCRIPTION
        Checks if the system can reach Microsoft's PowerShell download servers
    
    .PARAMETER Timeout
        Connection timeout in seconds (default: 10)
    
    .EXAMPLE
        Test-NetworkConnectivity
    #>
    [CmdletBinding()]
    param(
        [int]$Timeout = 10
    )
    
    $testUrls = @(
        "https://github.com/PowerShell/PowerShell/releases",
        "https://aka.ms/powershell-release",
        "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    )
    
    $connectionResults = @()
    
    foreach ($url in $testUrls) {
        try {
            $result = @{
                Url = $url
                Success = $false
                ResponseTime = $null
                Error = $null
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec $Timeout -UseBasicParsing -ErrorAction Stop
            } else {
                # PowerShell 5.1 compatibility
                $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec $Timeout -UseBasicParsing -ErrorAction Stop
            }
            
            $stopwatch.Stop()
            
            if ($response.StatusCode -eq 200) {
                $result.Success = $true
                $result.ResponseTime = $stopwatch.ElapsedMilliseconds
            }
            
            $connectionResults += $result
        } catch {
            $result.Error = $_.Exception.Message
            $connectionResults += $result
        }
    }
    
    $successfulConnections = $connectionResults | Where-Object { $_.Success }
    
    return @{
        HasConnectivity = $successfulConnections.Count -gt 0
        Results = $connectionResults
        FastestResponse = if ($successfulConnections.Count -gt 0) { 
            ($successfulConnections | Sort-Object ResponseTime | Select-Object -First 1).ResponseTime 
        } else { 
            $null 
        }
    }
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
        Attempts to install PowerShell 7 with multiple methods
    
    .DESCRIPTION
        Tries multiple installation methods in order of preference:
        1. Windows Package Manager (winget)
        2. Chocolatey (if available)
        3. Direct download from GitHub
        4. Manual download prompt
    
    .PARAMETER Method
        Force specific installation method
    
    .PARAMETER SkipNetworkTest
        Skip network connectivity test
    
    .EXAMPLE
        Install-PowerShell7
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('auto', 'winget', 'chocolatey', 'direct', 'manual')]
        [string]$Method = 'auto',
        
        [switch]$SkipNetworkTest
    )
    
    # Test network connectivity first
    if (-not $SkipNetworkTest) {
        Write-Host "🔍 Testing network connectivity..." -ForegroundColor Cyan
        $networkTest = Test-NetworkConnectivity -Timeout 5
        
        if (-not $networkTest.HasConnectivity) {
            Write-Host "❌ No network connectivity to PowerShell download servers" -ForegroundColor Red
            Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
            Write-Host "Or download PowerShell 7 manually from: https://aka.ms/powershell-release" -ForegroundColor Cyan
            return $false
        }
        
        Write-Host "✅ Network connectivity confirmed (${networkTest.FastestResponse}ms)" -ForegroundColor Green
    }
    
    $isWindows = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop'
    
    if ($Method -eq 'auto') {
        # Determine best installation method
        if ($isWindows) {
            # Check for winget
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $Method = 'winget'
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                $Method = 'chocolatey'
            } else {
                $Method = 'direct'
            }
        } else {
            $Method = 'direct'
        }
    }
    
    Write-Host "🔄 Installing PowerShell 7 using method: $Method" -ForegroundColor Cyan
    
    switch ($Method) {
        'winget' {
            try {
                Write-Host "Installing via Windows Package Manager..." -ForegroundColor Yellow
                $result = Start-Process -FilePath "winget" -ArgumentList "install", "Microsoft.PowerShell", "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -PassThru -NoNewWindow
                if ($result.ExitCode -eq 0) {
                    Write-Host "✅ PowerShell 7 installed successfully via winget" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "❌ Winget installation failed with exit code: $($result.ExitCode)" -ForegroundColor Red
                    return $false
                }
            } catch {
                Write-Host "❌ Winget installation failed: $_" -ForegroundColor Red
                return $false
            }
        }
        
        'chocolatey' {
            try {
                Write-Host "Installing via Chocolatey..." -ForegroundColor Yellow
                $result = Start-Process -FilePath "choco" -ArgumentList "install", "powershell-core", "-y" -Wait -PassThru -NoNewWindow
                if ($result.ExitCode -eq 0) {
                    Write-Host "✅ PowerShell 7 installed successfully via Chocolatey" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "❌ Chocolatey installation failed with exit code: $($result.ExitCode)" -ForegroundColor Red
                    return $false
                }
            } catch {
                Write-Host "❌ Chocolatey installation failed: $_" -ForegroundColor Red
                return $false
            }
        }
        
        'direct' {
            Write-Host "❌ Direct download installation not implemented yet" -ForegroundColor Red
            Write-Host "Please use one of these methods:" -ForegroundColor Yellow
            if ($isWindows) {
                Write-Host "  • winget install Microsoft.PowerShell" -ForegroundColor Cyan
                Write-Host "  • choco install powershell-core" -ForegroundColor Cyan
            } else {
                Write-Host "  • Visit: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux" -ForegroundColor Cyan
            }
            return $false
        }
        
        'manual' {
            Write-Host "Opening manual download page..." -ForegroundColor Cyan
            if ($isWindows) {
                Start-Process "https://aka.ms/powershell-release"
            }
            return $false
        }
    }
    
    return $false
}

function Start-WithPowerShell7 {
    <#
    .SYNOPSIS
        Enhanced PowerShell 7 restart with installation support

    .DESCRIPTION
        Finds PowerShell 7 and relaunches the current script with all parameters preserved.
        If PowerShell 7 is not found, attempts to install it automatically.

    .PARAMETER ScriptPath
        Path to the script to restart (default: current script)

    .PARAMETER Parameters
        Parameters to pass to the script

    .PARAMETER AttemptInstall
        Attempt to install PowerShell 7 if not found

    .EXAMPLE
        Start-WithPowerShell7 -Parameters $PSBoundParameters -AttemptInstall
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ScriptPath = $MyInvocation.PSCommandPath,

        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [switch]$AttemptInstall
    )

    $pwsh7 = Find-PowerShell7

    if (-not $pwsh7) {
        Write-Host "❌ PowerShell 7 is not installed!" -ForegroundColor Red
        
        if ($AttemptInstall) {
            Write-Host "🔄 Attempting to install PowerShell 7 automatically..." -ForegroundColor Cyan
            
            $installResult = Install-PowerShell7
            
            if ($installResult) {
                # Try to find PowerShell 7 again after installation
                Start-Sleep -Seconds 2  # Give time for installation to complete
                $pwsh7 = Find-PowerShell7
                
                if (-not $pwsh7) {
                    Write-Host "❌ PowerShell 7 installation succeeded but executable not found" -ForegroundColor Red
                    Write-Host "Please restart your terminal and try again." -ForegroundColor Yellow
                    return $false
                }
            } else {
                Write-Host "❌ Failed to install PowerShell 7 automatically" -ForegroundColor Red
                Write-Host "Please install PowerShell 7 manually and try again." -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "Please install PowerShell 7 and try again." -ForegroundColor Yellow
            return $false
        }
    }

    Write-Host "✅ Found PowerShell 7 at: $pwsh7" -ForegroundColor Green
    Write-Host "🔄 Relaunching with PowerShell 7..." -ForegroundColor Cyan

    # Build argument list
    $argList = @('-NoProfile', '-File', $ScriptPath)

    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]

        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $argList += "-$key"
            }
        } elseif ($null -ne $value) {
            $argList += "-$key"
            $argList += $value
        }
    }

    # Start new process
    try {
        & $pwsh7 @argList
        exit $LASTEXITCODE
    } catch {
        Write-Host "❌ Failed to start PowerShell 7: $_" -ForegroundColor Red
        return $false
    }
}

# Export functions only if running as a module (not when dot-sourced)
# When dot-sourced, functions are automatically available in the caller's scope
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function @(
        'Test-PowerShellVersion',
        'Find-PowerShell7',
        'Test-NetworkConnectivity',
        'Install-PowerShell7',
        'Start-WithPowerShell7'
    )
}
