#Requires -Version 7.0
# Stage: Development
# Dependencies: PowerShell7
# Description: Install Ollama runtime and vision models for AI-powered sheet music recognition
# Tags: development, ai, ollama, vision-models

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,
    
    [Parameter()]
    [string[]]$Models = @('llava', 'bakllava'),
    
    [Parameter()]
    [switch]$SkipModelPull,
    
    [Parameter()]
    [switch]$Force
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
    # Fallback to basic output - silently continue
    Write-Verbose "Could not load logging module"
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

function Test-OllamaInstalled {
    <#
    .SYNOPSIS
        Check if Ollama is installed and accessible
    #>
    try {
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        if ($ollamaCmd) {
            $version = & ollama --version 2>&1
            Write-ScriptLog "Ollama found: $version" -Level 'Debug'
            return $true
        }
        return $false
    } catch {
        Write-ScriptLog "Error checking Ollama installation: $_" -Level 'Debug'
        return $false
    }
}

function Get-OllamaVersion {
    <#
    .SYNOPSIS
        Get the installed Ollama version
    #>
    try {
        $version = & ollama --version 2>&1 | Select-Object -First 1
        return $version -replace 'ollama version is ', ''
    } catch {
        return $null
    }
}

function Install-OllamaWindows {
    <#
    .SYNOPSIS
        Install Ollama on Windows
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-ScriptLog "Installing Ollama on Windows..."
    
    $downloadUrl = 'https://ollama.ai/download/OllamaSetup.exe'
    $installerPath = Join-Path $env:TEMP 'OllamaSetup.exe'
    
    try {
        # Download installer
        Write-ScriptLog "Downloading Ollama installer..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -ErrorAction Stop
        
        # Run installer
        Write-ScriptLog "Running Ollama installer..."
        if ($PSCmdlet.ShouldProcess('Ollama', 'Install')) {
            $process = Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-ScriptLog "Ollama installed successfully"
                
                # Wait for installation to complete
                Start-Sleep -Seconds 5
                
                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                
                return $true
            } else {
                Write-ScriptLog "Ollama installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                return $false
            }
        }
    } catch {
        Write-ScriptLog "Error installing Ollama: $_" -Level 'Error'
        return $false
    } finally {
        # Cleanup installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-OllamaLinux {
    <#
    .SYNOPSIS
        Install Ollama on Linux
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-ScriptLog "Installing Ollama on Linux..."
    
    try {
        # Use official install script
        Write-ScriptLog "Downloading and running Ollama install script..."
        if ($PSCmdlet.ShouldProcess('Ollama', 'Install')) {
            $installScript = Invoke-WebRequest -Uri 'https://ollama.ai/install.sh' -UseBasicParsing
            
            # Run install script
            $scriptPath = '/tmp/ollama-install.sh'
            $installScript.Content | Set-Content -Path $scriptPath -Force
            
            & bash $scriptPath
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Ollama installed successfully"
                return $true
            } else {
                Write-ScriptLog "Ollama installation failed with exit code: $LASTEXITCODE" -Level 'Error'
                return $false
            }
        }
    } catch {
        Write-ScriptLog "Error installing Ollama: $_" -Level 'Error'
        return $false
    }
}

function Install-OllamaMacOS {
    <#
    .SYNOPSIS
        Install Ollama on macOS
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-ScriptLog "Installing Ollama on macOS..."
    
    # Check if Homebrew is available
    $brewCmd = Get-Command brew -ErrorAction SilentlyContinue
    
    if ($brewCmd) {
        Write-ScriptLog "Installing Ollama via Homebrew..."
        try {
            if ($PSCmdlet.ShouldProcess('Ollama', 'Install via Homebrew')) {
                & brew install ollama
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "Ollama installed successfully via Homebrew"
                    return $true
                }
            }
        } catch {
            Write-ScriptLog "Homebrew installation failed: $_" -Level 'Warning'
        }
    }
    
    # Fallback to direct download
    Write-ScriptLog "Installing Ollama via direct download..."
    $downloadUrl = 'https://ollama.ai/download/Ollama-darwin.zip'
    $downloadPath = Join-Path $env:HOME 'Downloads/Ollama-darwin.zip'
    
    try {
        Write-ScriptLog "Downloading Ollama..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -ErrorAction Stop
        
        Write-ScriptLog "Installing Ollama app..."
        if ($PSCmdlet.ShouldProcess('Ollama', 'Install')) {
            # Unzip and install
            & unzip -o $downloadPath -d /Applications/
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Ollama installed successfully"
                return $true
            } else {
                Write-ScriptLog "Ollama installation failed" -Level 'Error'
                return $false
            }
        }
    } catch {
        Write-ScriptLog "Error installing Ollama: $_" -Level 'Error'
        return $false
    } finally {
        # Cleanup
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-OllamaService {
    <#
    .SYNOPSIS
        Start the Ollama service if not running
    #>
    Write-ScriptLog "Starting Ollama service..."
    
    try {
        # Check if service is already running
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response) {
            Write-ScriptLog "Ollama service is already running"
            return $true
        }
    } catch {
        # Service not running, start it
        Write-ScriptLog "Ollama service not detected, will attempt to start" -Level 'Debug'
    }
    
    try {
        if ($IsWindows) {
            # On Windows, Ollama runs as a service
            Write-ScriptLog "Starting Ollama Windows service..."
            Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
        } else {
            # On Linux/macOS, start as background process
            Write-ScriptLog "Starting Ollama service..."
            Start-Process -FilePath "ollama" -ArgumentList "serve" -RedirectStandardOutput "/dev/null" -RedirectStandardError "/dev/null"
        }
        
        # Wait for service to start
        $maxAttempts = 10
        $attempt = 0
        $serviceStarted = $false
        
        while ($attempt -lt $maxAttempts -and -not $serviceStarted) {
            Start-Sleep -Seconds 2
            try {
                $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
                if ($response) {
                    $serviceStarted = $true
                    Write-ScriptLog "Ollama service started successfully"
                }
            } catch {
                $attempt++
            }
        }
        
        if (-not $serviceStarted) {
            Write-ScriptLog "Failed to start Ollama service after $maxAttempts attempts" -Level 'Warning'
            return $false
        }
        
        return $true
    } catch {
        Write-ScriptLog "Error starting Ollama service: $_" -Level 'Error'
        return $false
    }
}

function Test-OllamaAPI {
    <#
    .SYNOPSIS
        Test if Ollama API is accessible
    #>
    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -Method Get -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

function Get-OllamaModel {
    <#
    .SYNOPSIS
        Get list of installed Ollama models
    #>
    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -Method Get
        return $response.models | ForEach-Object { $_.name }
    } catch {
        Write-ScriptLog "Error getting Ollama models: $_" -Level 'Debug'
        return @()
    }
}

function Install-OllamaModel {
    <#
    .SYNOPSIS
        Pull and install an Ollama model
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ModelName
    )
    
    Write-ScriptLog "Pulling Ollama model: $ModelName"
    Write-ScriptLog "This may take several minutes depending on model size and network speed..."
    
    try {
        if ($PSCmdlet.ShouldProcess($ModelName, 'Pull Ollama model')) {
            # Use ollama pull command
            $process = Start-Process -FilePath "ollama" -ArgumentList "pull", $ModelName -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-ScriptLog "Model $ModelName pulled successfully"
                return $true
            } else {
                Write-ScriptLog "Failed to pull model $ModelName (exit code: $($process.ExitCode))" -Level 'Error'
                return $false
            }
        }
    } catch {
        Write-ScriptLog "Error pulling model $ModelName : $_" -Level 'Error'
        return $false
    }
}

# Main script execution
Write-ScriptLog "═══════════════════════════════════════════════════════"
Write-ScriptLog "Starting Ollama Installation"
Write-ScriptLog "═══════════════════════════════════════════════════════"

try {
    # Import Configuration module
    $configModule = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/configuration/Configuration.psm1"
    if (Test-Path $configModule) {
        Import-Module $configModule -Force -ErrorAction SilentlyContinue
    }

    # Get configuration
    $ollamaConfig = $null
    $shouldInstall = $false
    
    if (Get-Command Test-FeatureEnabled -ErrorAction SilentlyContinue) {
        # Use new configuration system
        $shouldInstall = Test-FeatureEnabled -FeatureName 'Ollama' -Category 'Development'
        if ($shouldInstall) {
            $ollamaConfig = Get-FeatureConfiguration -FeatureName 'Ollama' -Category 'Development'
            Write-ScriptLog "Ollama installation enabled via Features.Development.Ollama configuration"
        }
    } else {
        # Fallback to legacy configuration
        $config = if ($Configuration) { $Configuration } else { @{} }
        
        if ($config.Features -and $config.Features.Development -and $config.Features.Development.Ollama) {
            $ollamaConfig = $config.Features.Development.Ollama
            $shouldInstall = $ollamaConfig.Enabled -eq $true
        }
    }

    # Override if Force is specified
    if ($Force) {
        $shouldInstall = $true
        Write-ScriptLog "Force installation requested"
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Ollama installation is not enabled in configuration"
        Write-ScriptLog "To enable, set Features.Development.Ollama.Enabled = `$true in config.psd1"
        exit 0
    }

    # Get models to install
    if ($ollamaConfig -and $ollamaConfig.DefaultModels) {
        $Models = $ollamaConfig.DefaultModels
    }
    
    Write-ScriptLog "Models to install: $($Models -join ', ')"

    # Check if Ollama is already installed
    if (Test-OllamaInstalled) {
        $version = Get-OllamaVersion
        Write-ScriptLog "Ollama is already installed: $version"
        
        if (-not $Force) {
            Write-ScriptLog "Skipping installation (use -Force to reinstall)"
        } else {
            Write-ScriptLog "Force flag specified, will verify and update models"
        }
    } else {
        # Install Ollama based on platform
        Write-ScriptLog "Ollama is not installed, proceeding with installation..."
        
        $installSuccess = $false
        
        if ($IsWindows) {
            Write-ScriptLog "Detected platform: Windows"
            $installSuccess = Install-OllamaWindows
        } elseif ($IsLinux) {
            Write-ScriptLog "Detected platform: Linux"
            $installSuccess = Install-OllamaLinux
        } elseif ($IsMacOS) {
            Write-ScriptLog "Detected platform: macOS"
            $installSuccess = Install-OllamaMacOS
        } else {
            Write-ScriptLog "Unsupported platform" -Level 'Error'
            exit 1
        }
        
        if (-not $installSuccess) {
            Write-ScriptLog "Ollama installation failed" -Level 'Error'
            exit 1
        }
        
        # Verify installation
        if (-not (Test-OllamaInstalled)) {
            Write-ScriptLog "Ollama was installed but is not accessible in PATH" -Level 'Error'
            Write-ScriptLog "Please restart your terminal or add Ollama to your PATH" -Level 'Warning'
            exit 2
        }
        
        $version = Get-OllamaVersion
        Write-ScriptLog "Successfully installed Ollama version: $version"
    }

    # Start Ollama service
    if (-not (Test-OllamaAPI)) {
        Write-ScriptLog "Ollama API is not accessible, starting service..."
        if (-not (Start-OllamaService)) {
            Write-ScriptLog "Failed to start Ollama service" -Level 'Warning'
            Write-ScriptLog "You may need to start it manually with: ollama serve" -Level 'Warning'
        }
    } else {
        Write-ScriptLog "Ollama API is accessible"
    }

    # Skip model installation if requested
    if ($SkipModelPull) {
        Write-ScriptLog "Skipping model installation (SkipModelPull specified)"
        Write-ScriptLog "═══════════════════════════════════════════════════════"
        Write-ScriptLog "Ollama installation completed successfully"
        Write-ScriptLog "═══════════════════════════════════════════════════════"
        exit 0
    }

    # Get currently installed models
    $installedModels = Get-OllamaModel
    Write-ScriptLog "Currently installed models: $($installedModels -join ', ')"

    # Install models
    $failedModels = @()
    foreach ($model in $Models) {
        # Check if model is already installed
        $modelInstalled = $installedModels | Where-Object { $_ -like "$model*" }
        
        if ($modelInstalled -and -not $Force) {
            Write-ScriptLog "Model $model is already installed"
            continue
        }
        
        # Pull model
        $success = Install-OllamaModel -ModelName $model
        if (-not $success) {
            $failedModels += $model
        }
    }

    # Report results
    if ($failedModels.Count -gt 0) {
        Write-ScriptLog "Failed to install models: $($failedModels -join ', ')" -Level 'Warning'
        Write-ScriptLog "You can manually install them later with: ollama pull <model-name>" -Level 'Information'
    }

    # Get final list of installed models
    $installedModels = Get-OllamaModel
    Write-ScriptLog "Installed models: $($installedModels -join ', ')"

    Write-ScriptLog "═══════════════════════════════════════════════════════"
    Write-ScriptLog "Ollama installation completed successfully"
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    Write-ScriptLog ""
    Write-ScriptLog "Next steps:"
    Write-ScriptLog "  • Test Ollama: ollama run llava"
    Write-ScriptLog "  • Convert sheet music: az 0220 -InputImage <image.png>"
    Write-ScriptLog "  • API endpoint: http://localhost:11434"
    
    exit 0

} catch {
    Write-ScriptLog "Fatal error during Ollama installation: $_" -Level 'Error'
    Write-ScriptLog "Stack trace: $($_.ScriptStackTrace)" -Level 'Debug'
    exit 1
}
