#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Go programming language
# Tags: development, go, golang, programming

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting Go installation check"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Go installation is enabled
    $shouldInstall = $false
    $goConfig = @{
        Install = $false
        Version = 'latest'
        InstallerUrl = ''
    }

    if ($config.InstallationOptions -and $config.InstallationOptions.Go) {
        $goConfig = $config.InstallationOptions.Go
        $shouldInstall = $goConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Go installation is not enabled in configuration"
        exit 0
    }

    # Check if Go is already installed
    try {
        $goVersion = & go version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Go is already installed: $goVersion"

            # Check GOPATH
            $goPath = & go env GOPATH 2>&1
            if ($goPath) {
                Write-ScriptLog "GOPATH: $goPath" -Level 'Debug'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Go not found, proceeding with installation"
    }

    # Determine version to install
    $version = if ($goConfig.Version -and $goConfig.Version -ne 'latest') {
        $goConfig.Version
    } else {
        # Get latest version from Go website
        try {
            $latestPage = Invoke-WebRequest -Uri 'https://go.dev/VERSION?m=text' -UseBasicParsing
            $latestVersion = $latestPage.Content.Trim()
            $latestVersion -replace '^go', ''
        } catch {
            Write-ScriptLog "Could not fetch latest version, using default" -Level 'Warning'
            '1.22.0'  # Fallback version
        }
    }
    
    Write-ScriptLog "Installing Go version: $version"

    # Install Go based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Go for Windows..."
        
        # Use configured URL or build default
        $downloadUrl = if ($goConfig.InstallerUrl) {
            $goConfig.InstallerUrl
        } else {
            "https://go.dev/dl/go$version.windows-amd64.msi"
        }
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir "go-installer.msi"
        
        # Download installer
        Write-ScriptLog "Downloading Go installer from $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Go installer: $_" -Level 'Error'
            throw
        }
        
        # Install Go
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Go')) {
            Write-ScriptLog "Running Go installer..."
            $installArgs = @('/i', $installerPath, '/quiet', '/norestart')
            
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Go installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Go installation failed"
            }

            # Set up environment variables
            $goRoot = "$env:ProgramFiles\Go"
            $goPath = "$env:USERPROFILE\go"

            # Update PATH
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -notlike "*$goRoot\bin*") {
                [Environment]::SetEnvironmentVariable('PATH', "$userPath;$goRoot\bin", 'User')
            }
            if ($userPath -notlike "*$goPath\bin*") {
                [Environment]::SetEnvironmentVariable('PATH', "$userPath;$goPath\bin", 'User')
            }

            # Set GOPATH
            [Environment]::SetEnvironmentVariable('GOPATH', $goPath, 'User')

            # Update current session
            $env:PATH = "$env:PATH;$goRoot\bin;$goPath\bin"
            $env:GOPATH = $goPath
            
            Write-ScriptLog "Go environment variables configured"
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Go for Linux..."
        
        $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
            'X64' { 'amd64' }
            'Arm64' { 'arm64' }
            'Arm' { 'armv6l' }
            default { 'amd64' }
        }
        
        $downloadUrl = "https://go.dev/dl/go$version.linux-$arch.tar.gz"
        $tarPath = "/tmp/go$version.tar.gz"
        
        # Download
        Write-ScriptLog "Downloading Go from $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tarPath -UseBasicParsing
        
        # Remove old installation
        if (Test-Path '/usr/local/go') {
            sudo rm -rf /usr/local/go
        }
        
        # Extract
        sudo tar -C /usr/local -xzf $tarPath
        
        # Set up environment
        $profilePath = "$HOME/.profile"
        if (Test-Path "$HOME/.bashrc") {
            $profilePath = "$HOME/.bashrc"
        }
        
        # Add to PATH if not already there
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -notmatch 'export PATH.*\/usr\/local\/go\/bin') {
            @"

# Go programming language
export PATH=`$PATH:/usr/local/go/bin
export GOPATH=`$HOME/go
export PATH=`$PATH:`$GOPATH/bin
"@ | Add-Content $profilePath
        }
        
        # Update current session
        $env:PATH = "$env:PATH:/usr/local/go/bin:$HOME/go/bin"
        $env:GOPATH = "$HOME/go"
        
        # Clean up
        Remove-Item $tarPath -Force
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Go for macOS..."
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            # Install using Homebrew
            brew install go
        } else {
            # Manual installation
            $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'amd64' }
            $downloadUrl = "https://go.dev/dl/go$version.darwin-$arch.pkg"
            $pkgPath = "/tmp/go-installer.pkg"

            # Download
            Write-ScriptLog "Downloading Go installer..."
            curl -o $pkgPath $downloadUrl

            # Install
            sudo installer -pkg $pkgPath -target /

            # Clean up
            rm $pkgPath
        }
        
        # Set up environment
        $profilePath = "$HOME/.zshrc"
        if (-not (Test-Path $profilePath)) {
            $profilePath = "$HOME/.bash_profile"
        }
        
        # Add to PATH if not already there
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch 'export PATH.*\/usr\/local\/go\/bin') {
            @"

# Go programming language
export PATH=`$PATH:/usr/local/go/bin
export GOPATH=`$HOME/go
export PATH=`$PATH:`$GOPATH/bin
"@ | Add-Content $profilePath
        }
        
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Go on this platform"
    }

    # Verify installation
    try {
        # Need to use full path on first run
        $goCmd = if ($IsWindows) { "$env:ProgramFiles\Go\bin\go.exe" } else { '/usr/local/go/bin/go' }
        $goVersion = & $goCmd version 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Go installed successfully: $goVersion"

            # Create Go workspace directories
            $goPath = if ($IsWindows) { "$env:USERPROFILE\go" } else { "$HOME/go" }
            
            @('bin', 'src', 'pkg') | ForEach-Object {
                $dir = Join-Path $goPath $_
                if (-not (Test-Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                    Write-ScriptLog "Created Go directory: $dir" -Level 'Debug'
                }
            }

            # Install common Go tools if specified
            if ($goConfig.Tools -and $goConfig.Tools.Count -gt 0) {
                Write-ScriptLog "Installing Go tools..."
                
                foreach ($tool in $goConfig.Tools) {
                    try {
                        Write-ScriptLog "Installing tool: $tool"
                        & $goCmd install $tool
                        
                        if ($LASTEXITCODE -ne 0) {
                            Write-ScriptLog "Failed to install $tool" -Level 'Warning'
                        }
                    } catch {
                        Write-ScriptLog "Error installing $tool : $_" -Level 'Warning'
                    }
                }
            }
            
        } else {
            throw "Go command failed after installation"
        }
    } catch {
        Write-ScriptLog "Go installation verification failed: $_" -Level 'Error'
        throw
    }
    
    Write-ScriptLog "Go installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Go installation failed: $_" -Level 'Error'
    exit 1
}