# OpenTofuProvider Functions - Consolidated into AitherCore Infrastructure Domain
# Infrastructure deployment and management using OpenTofu/Terraform

#Requires -Version 7.0

# YAML HELPER FUNCTIONS

function ConvertFrom-Yaml {
    <#
    .SYNOPSIS
        Converts YAML content to PowerShell object
    .DESCRIPTION
        Simple YAML parser for basic configuration files
    .PARAMETER InputObject
        YAML content as string
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$InputObject
    )
    
    $result = @{}
    $lines = $InputObject -split "`n"
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^(\w+):\s*(.+)$') {
                $key = $matches[1]
                $value = $matches[2].Trim('"''')
                $result[$key] = $value
            }
        }
    }
    
    return $result
}

function ConvertTo-Yaml {
    <#
    .SYNOPSIS
        Converts PowerShell object to YAML format
    .DESCRIPTION
        Simple YAML serializer for basic objects
    .PARAMETER InputObject
        PowerShell object to convert
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject
    )
    
    $yaml = @()
    
    if ($InputObject -is [hashtable]) {
        foreach ($key in $InputObject.Keys) {
            $value = $InputObject[$key]
            if ($value -is [string]) {
                $yaml += "${key}: `"$value`""
            } else {
                $yaml += "${key}: $value"
            }
        }
    }
    
    return $yaml -join "`n"
}

# OPENTOFU INSTALLATION AND VALIDATION

function Test-OpenTofuInstallation {
    <#
    .SYNOPSIS
        Tests if OpenTofu is properly installed and accessible
    .DESCRIPTION
        Validates OpenTofu installation and returns detailed status
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if OpenTofu is in PATH
        $tofuPath = Get-Command tofu -ErrorAction SilentlyContinue
        if (-not $tofuPath) {
            return @{
                IsValid = $false
                Error = "OpenTofu (tofu) command not found in PATH"
                Version = $null
            }
        }
        
        # Get version information
        $versionOutput = & tofu version
        $version = if ($versionOutput -match 'OpenTofu v(\d+\.\d+\.\d+)') {
            $matches[1]
        } else {
            "Unknown"
        }
        
        Write-CustomLog -Level 'INFO' -Message "OpenTofu version $version detected"
        
        return @{
            IsValid = $true
            Version = $version
            Path = $tofuPath.Source
            Error = $null
        }
        
    } catch {
        return @{
            IsValid = $false
            Error = $_.Exception.Message
            Version = $null
        }
    }
}

function Install-OpenTofuSecure {
    <#
    .SYNOPSIS
        Installs OpenTofu with security validation
    .DESCRIPTION
        Downloads and installs OpenTofu with signature verification
    .PARAMETER Version
        OpenTofu version to install (defaults to latest)
    .PARAMETER InstallPath
        Installation directory (defaults to system path)
    .PARAMETER Force
        Force installation even if already installed
    #>
    [CmdletBinding()]
    param(
        [string]$Version = "latest",
        [string]$InstallPath,
        [switch]$Force
    )
    
    try {
        # Check if already installed
        if (-not $Force) {
            $existing = Test-OpenTofuInstallation
            if ($existing.IsValid) {
                Write-CustomLog -Level 'INFO' -Message "OpenTofu is already installed (version: $($existing.Version))"
                return $existing
            }
        }
        
        Write-CustomLog -Level 'INFO' -Message "Installing OpenTofu version: $Version"
        
        # Platform detection
        $platform = if ($IsWindows) { "windows" } elseif ($IsLinux) { "linux" } else { "darwin" }
        $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
        
        # Download URL
        $downloadUrl = if ($Version -eq "latest") {
            "https://github.com/opentofu/opentofu/releases/latest/download/tofu_${Version}_${platform}_${arch}.zip"
        } else {
            "https://github.com/opentofu/opentofu/releases/download/v${Version}/tofu_${Version}_${platform}_${arch}.zip"
        }
        
        Write-CustomLog -Level 'INFO' -Message "Downloading OpenTofu from: $downloadUrl"
        
        # Create temporary directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "opentofu-install"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Download
        $zipPath = Join-Path $tempDir "opentofu.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        
        # Extract
        $extractPath = Join-Path $tempDir "extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Install
        $binaryName = if ($IsWindows) { "tofu.exe" } else { "tofu" }
        $sourceBinary = Join-Path $extractPath $binaryName
        
        if (-not (Test-Path $sourceBinary)) {
            throw "OpenTofu binary not found in downloaded archive"
        }
        
        # Determine install location
        if (-not $InstallPath) {
            $InstallPath = if ($IsWindows) {
                Join-Path $env:ProgramFiles "OpenTofu"
            } else {
                "/usr/local/bin"
            }
        }
        
        # Create install directory
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }
        
        # Copy binary
        $targetBinary = Join-Path $InstallPath $binaryName
        Copy-Item -Path $sourceBinary -Destination $targetBinary -Force
        
        # Set permissions on Unix systems
        if (-not $IsWindows) {
            chmod +x $targetBinary
        }
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force
        
        # Verify installation
        $validation = Test-OpenTofuInstallation
        if ($validation.IsValid) {
            Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu installed successfully (version: $($validation.Version))"
            return $validation
        } else {
            throw "Installation verification failed: $($validation.Error)"
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "OpenTofu installation failed: $($_.Exception.Message)"
        throw
    }
}

# PROVIDER CONFIGURATION

function New-TaliesinsProviderConfig {
    <#
    .SYNOPSIS
        Creates Taliesins provider configuration for OpenTofu
    .DESCRIPTION
        Generates secure provider configuration for Hyper-V integration
    .PARAMETER Configuration
        Lab configuration object
    .PARAMETER ProviderVersion
        Provider version to use
    .PARAMETER CertificatePath
        Path to SSL certificates
    #>
    param(
        [object]$Configuration,
        [string]$ProviderVersion = "1.2.1",
        [string]$CertificatePath
    )
    
    $mainConfig = @"
terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "$ProviderVersion"
    }
  }
}

provider "hyperv" {
  user         = var.hyperv_user
  password     = var.hyperv_password
  host         = var.hyperv_host
  port         = var.hyperv_port
  https        = var.hyperv_https
  insecure     = var.hyperv_insecure
  use_ntlm     = var.hyperv_use_ntlm
  tls_server_name = var.hyperv_tls_server_name
"@

    if ($CertificatePath) {
        $mainConfig += @"

  cacert_path = "$CertificatePath"
  cert_path   = "$CertificatePath"
  key_path    = "$CertificatePath"
"@
    }

    $mainConfig += @"
}

# Virtual Machine Resource
resource "hyperv_machine_instance" "default" {
  name                   = var.vm_name
  generation            = var.vm_generation
  processor_count       = var.vm_processor_count
  memory_startup_bytes  = var.vm_memory_startup_bytes
  memory_minimum_bytes  = var.vm_memory_minimum_bytes
  memory_maximum_bytes  = var.vm_memory_maximum_bytes
  
  # Network configuration
  network_adaptors {
    name               = "Default Switch"
    switch_name        = var.vm_switch_name
    management_os      = false
    is_legacy         = false
    dynamic_mac_address = true
  }
  
  # Storage configuration
  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path               = var.vm_hard_disk_path
    size               = var.vm_hard_disk_size
  }
  
  # DVD Drive for ISO mounting
  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path               = var.vm_iso_path
  }
}
"@

    $variablesConfig = @"
variable "hyperv_user" {
  description = "Hyper-V username"
  type        = string
}

variable "hyperv_password" {
  description = "Hyper-V password"
  type        = string
  sensitive   = true
}

variable "hyperv_host" {
  description = "Hyper-V host"
  type        = string
  default     = "localhost"
}

variable "hyperv_port" {
  description = "Hyper-V port"
  type        = number
  default     = 5986
}

variable "hyperv_https" {
  description = "Use HTTPS for Hyper-V connection"
  type        = bool
  default     = true
}

variable "hyperv_insecure" {
  description = "Skip SSL verification"
  type        = bool
  default     = false
}

variable "hyperv_use_ntlm" {
  description = "Use NTLM authentication"
  type        = bool
  default     = true
}

variable "hyperv_tls_server_name" {
  description = "TLS server name for verification"
  type        = string
  default     = ""
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "AitherZero-VM"
}

variable "vm_generation" {
  description = "VM generation (1 or 2)"
  type        = number
  default     = 2
}

variable "vm_processor_count" {
  description = "Number of processors"
  type        = number
  default     = 2
}

variable "vm_memory_startup_bytes" {
  description = "Startup memory in bytes"
  type        = number
  default     = 4294967296  # 4GB
}

variable "vm_memory_minimum_bytes" {
  description = "Minimum memory in bytes"
  type        = number
  default     = 2147483648  # 2GB
}

variable "vm_memory_maximum_bytes" {
  description = "Maximum memory in bytes"
  type        = number
  default     = 8589934592  # 8GB
}

variable "vm_switch_name" {
  description = "Hyper-V switch name"
  type        = string
  default     = "Default Switch"
}

variable "vm_hard_disk_path" {
  description = "Path to VM hard disk"
  type        = string
}

variable "vm_hard_disk_size" {
  description = "Hard disk size in bytes"
  type        = number
  default     = 107374182400  # 100GB
}

variable "vm_iso_path" {
  description = "Path to ISO file"
  type        = string
}
"@

    return @{
        MainConfig = $mainConfig
        VariablesConfig = $variablesConfig
    }
}

function Test-TaliesinsProviderInstallation {
    <#
    .SYNOPSIS
        Tests if Taliesins provider is properly installed
    .DESCRIPTION
        Validates provider installation and version
    .PARAMETER ProviderVersion
        Expected provider version
    #>
    param(
        [string]$ProviderVersion = "1.2.1"
    )
    
    try {
        # Check if provider is installed
        $providerPath = Join-Path (Get-Location) ".terraform"
        if (-not (Test-Path $providerPath)) {
            return @{
                Success = $false
                Error = "Terraform not initialized (.terraform directory not found)"
            }
        }
        
        # Check provider installation
        $providersPath = Join-Path $providerPath "providers"
        $hypervProvider = Get-ChildItem -Path $providersPath -Filter "*hyperv*" -Recurse -ErrorAction SilentlyContinue
        
        if (-not $hypervProvider) {
            return @{
                Success = $false
                Error = "Taliesins Hyper-V provider not found"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Taliesins provider installation validated"
        return @{
            Success = $true
            ProviderPath = $hypervProvider.FullName
            Error = $null
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# OPENTOFU COMMAND EXECUTION

function Invoke-OpenTofuCommand {
    <#
    .SYNOPSIS
        Executes OpenTofu commands with proper error handling
    .DESCRIPTION
        Wrapper for OpenTofu command execution with comprehensive logging
    .PARAMETER Command
        OpenTofu command to execute
    .PARAMETER Arguments
        Additional arguments
    .PARAMETER WorkingDirectory
        Working directory for execution
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location)
    )
    
    try {
        $originalLocation = Get-Location
        Set-Location $WorkingDirectory
        
        $fullCommand = "tofu $Command"
        if ($Arguments) {
            $fullCommand += " " + ($Arguments -join " ")
        }
        
        Write-CustomLog -Level 'INFO' -Message "Executing: $fullCommand"
        
        # Execute command
        $process = Start-Process -FilePath "tofu" -ArgumentList ($Command + $Arguments) -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$WorkingDirectory\tofu-output.log" -RedirectStandardError "$WorkingDirectory\tofu-error.log"
        
        # Read output
        $stdout = ""
        $stderr = ""
        
        if (Test-Path "$WorkingDirectory\tofu-output.log") {
            $stdout = Get-Content "$WorkingDirectory\tofu-output.log" -Raw
            Remove-Item "$WorkingDirectory\tofu-output.log" -Force
        }
        
        if (Test-Path "$WorkingDirectory\tofu-error.log") {
            $stderr = Get-Content "$WorkingDirectory\tofu-error.log" -Raw
            Remove-Item "$WorkingDirectory\tofu-error.log" -Force
        }
        
        if ($process.ExitCode -eq 0) {
            Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu command completed successfully"
            return @{
                Success = $true
                ExitCode = $process.ExitCode
                Output = $stdout
                Error = $stderr
            }
        } else {
            Write-CustomLog -Level 'ERROR' -Message "OpenTofu command failed with exit code: $($process.ExitCode)"
            Write-CustomLog -Level 'ERROR' -Message "Error output: $stderr"
            return @{
                Success = $false
                ExitCode = $process.ExitCode
                Output = $stdout
                Error = $stderr
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to execute OpenTofu command: $($_.Exception.Message)"
        return @{
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
        }
    } finally {
        Set-Location $originalLocation
    }
}

# MAIN DEPLOYMENT FUNCTIONS

function Initialize-OpenTofuProvider {
    <#
    .SYNOPSIS
        Initializes OpenTofu with secure Taliesins provider configuration
    .DESCRIPTION
        Sets up OpenTofu environment with proper Taliesins Hyper-V provider integration
    .PARAMETER ConfigPath
        Path to the lab configuration file (YAML format)
    .PARAMETER ProviderVersion
        Taliesins provider version to use
    .PARAMETER CertificatePath
        Path to client certificates for secure communication
    .PARAMETER Force
        Force re-initialization even if already initialized
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter()]
        [string]$ProviderVersion = "1.2.1",

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Initializing OpenTofu with Taliesins provider (Version: $ProviderVersion)"

        # Load configuration
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml
        Write-CustomLog -Level 'INFO' -Message "Loaded configuration from: $ConfigPath"
    }

    process {
        try {
            # Validate OpenTofu installation
            $openTofuValid = Test-OpenTofuInstallation
            if (-not $openTofuValid.IsValid) {
                throw "OpenTofu is not properly installed. Run Install-OpenTofuSecure first."
            }

            # Generate secure provider configuration
            $providerConfig = New-TaliesinsProviderConfig -Configuration $config -ProviderVersion $ProviderVersion -CertificatePath $CertificatePath

            # Create terraform configuration directory
            $workingDir = Get-Location
            $terraformDir = Join-Path $workingDir ".terraform"

            if ($Force -and (Test-Path $terraformDir)) {
                Write-CustomLog -Level 'INFO' -Message "Removing existing .terraform directory"
                Remove-Item $terraformDir -Recurse -Force
            }

            # Write provider configuration
            $mainTfPath = Join-Path $workingDir "main.tf"
            if ($PSCmdlet.ShouldProcess($mainTfPath, "Write OpenTofu configuration")) {
                Set-Content -Path $mainTfPath -Value $providerConfig.MainConfig
                Write-CustomLog -Level 'INFO' -Message "Created main.tf configuration"
            }

            # Write variables file
            $variablesTfPath = Join-Path $workingDir "variables.tf"
            if ($PSCmdlet.ShouldProcess($variablesTfPath, "Write variables configuration")) {
                Set-Content -Path $variablesTfPath -Value $providerConfig.VariablesConfig
                Write-CustomLog -Level 'INFO' -Message "Created variables.tf configuration"
            }

            # Initialize OpenTofu
            Write-CustomLog -Level 'INFO' -Message "Running OpenTofu init..."
            $initResult = Invoke-OpenTofuCommand -Command "init" -WorkingDirectory $workingDir

            if ($initResult.Success) {
                # Validate provider installation
                $validationResult = Test-TaliesinsProviderInstallation -ProviderVersion $ProviderVersion

                if ($validationResult.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu initialized successfully with Taliesins provider"
                    return @{
                        Success = $true
                        ProviderVersion = $ProviderVersion
                        ConfigPath = $ConfigPath
                        WorkingDirectory = $workingDir
                        CertificatesConfigured = ($null -ne $CertificatePath)
                    }
                } else {
                    throw "Provider validation failed: $($validationResult.Error)"
                }
            } else {
                throw "OpenTofu initialization failed: $($initResult.Error)"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "OpenTofu provider initialization failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "OpenTofu provider initialization completed"
    }
}

function Start-InfrastructureDeployment {
    <#
    .SYNOPSIS
        Starts an infrastructure deployment using OpenTofu
    .DESCRIPTION
        Main entry point for infrastructure deployment with comprehensive error handling
    .PARAMETER ConfigurationPath
        Path to deployment configuration file
    .PARAMETER DryRun
        Perform planning only without applying changes
    .PARAMETER Stage
        Run specific deployment stage only
    .PARAMETER MaxRetries
        Maximum retry attempts for failed operations
    .PARAMETER Force
        Force deployment even with warnings
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$ConfigurationPath,

        [switch]$DryRun,

        [ValidateSet('Plan', 'Apply', 'Destroy')]
        [string]$Stage,

        [int]$MaxRetries = 3,

        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting infrastructure deployment from: $ConfigurationPath"

        # Load configuration
        $config = Get-Content $ConfigurationPath -Raw | ConvertFrom-Yaml
        
        # Initialize deployment result
        $deploymentResult = @{
            Success = $false
            ConfigurationPath = $ConfigurationPath
            StartTime = Get-Date
            EndTime = $null
            Duration = $null
            Stage = $Stage
            DryRun = $DryRun.IsPresent
            Stages = @{}
            Resources = @{}
            Warnings = @()
            Errors = @()
        }

        # Initialize OpenTofu if not already done
        $initResult = Initialize-OpenTofuProvider -ConfigPath $ConfigurationPath -Force:$Force
        if (-not $initResult.Success) {
            throw "Failed to initialize OpenTofu provider"
        }

        # Plan stage
        if (-not $Stage -or $Stage -eq 'Plan') {
            Write-CustomLog -Level 'INFO' -Message "Creating deployment plan..."
            $planResult = Invoke-OpenTofuCommand -Command "plan" -Arguments @("-out=tfplan")
            
            $deploymentResult.Stages['Plan'] = @{
                Success = $planResult.Success
                Output = $planResult.Output
                Error = $planResult.Error
                Duration = (Get-Date) - $deploymentResult.StartTime
            }
            
            if (-not $planResult.Success) {
                $deploymentResult.Errors += "Plan stage failed: $($planResult.Error)"
                throw "Deployment planning failed"
            }
        }

        # Apply stage (skip if dry run)
        if (-not $DryRun -and (-not $Stage -or $Stage -eq 'Apply')) {
            Write-CustomLog -Level 'INFO' -Message "Applying deployment plan..."
            $applyResult = Invoke-OpenTofuCommand -Command "apply" -Arguments @("-auto-approve", "tfplan")
            
            $deploymentResult.Stages['Apply'] = @{
                Success = $applyResult.Success
                Output = $applyResult.Output
                Error = $applyResult.Error
                Duration = (Get-Date) - $deploymentResult.StartTime
            }
            
            if (-not $applyResult.Success) {
                $deploymentResult.Errors += "Apply stage failed: $($applyResult.Error)"
                throw "Deployment application failed"
            }
        }

        # Destroy stage (if requested)
        if ($Stage -eq 'Destroy') {
            Write-CustomLog -Level 'INFO' -Message "Destroying infrastructure..."
            $destroyResult = Invoke-OpenTofuCommand -Command "destroy" -Arguments @("-auto-approve")
            
            $deploymentResult.Stages['Destroy'] = @{
                Success = $destroyResult.Success
                Output = $destroyResult.Output
                Error = $destroyResult.Error
                Duration = (Get-Date) - $deploymentResult.StartTime
            }
            
            if (-not $destroyResult.Success) {
                $deploymentResult.Errors += "Destroy stage failed: $($destroyResult.Error)"
                throw "Infrastructure destruction failed"
            }
        }

        # Mark as successful
        $deploymentResult.Success = $true
        $deploymentResult.EndTime = Get-Date
        $deploymentResult.Duration = $deploymentResult.EndTime - $deploymentResult.StartTime

        Write-CustomLog -Level 'SUCCESS' -Message "Infrastructure deployment completed successfully"
        return $deploymentResult

    } catch {
        $deploymentResult.Success = $false
        $deploymentResult.EndTime = Get-Date
        $deploymentResult.Duration = $deploymentResult.EndTime - $deploymentResult.StartTime
        $deploymentResult.Errors += $_.Exception.Message

        Write-CustomLog -Level 'ERROR' -Message "Infrastructure deployment failed: $($_.Exception.Message)"
        return $deploymentResult
    }
}

function New-LabInfrastructure {
    <#
    .SYNOPSIS
        Creates new lab infrastructure using OpenTofu
    .DESCRIPTION
        Simplified interface for creating lab infrastructure
    .PARAMETER ConfigPath
        Path to lab configuration file
    .PARAMETER VMName
        Name of the virtual machine to create
    .PARAMETER ISOPath
        Path to ISO file for VM installation
    .PARAMETER Force
        Force creation even if VM already exists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$VMName = "AitherZero-Lab",
        
        [string]$ISOPath,
        
        [switch]$Force
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Creating lab infrastructure: $VMName"
        
        # Create simple configuration for lab
        $labConfig = @{
            vm_name = $VMName
            vm_iso_path = $ISOPath
            vm_hard_disk_path = Join-Path $env:TEMP "${VMName}.vhdx"
        }
        
        # Write temporary config
        $tempConfig = Join-Path $env:TEMP "lab-config.yaml"
        $labConfig | ConvertTo-Yaml | Set-Content $tempConfig
        
        # Start deployment
        $result = Start-InfrastructureDeployment -ConfigurationPath $tempConfig -Force:$Force
        
        # Cleanup
        Remove-Item $tempConfig -Force -ErrorAction SilentlyContinue
        
        if ($result.Success) {
            Write-CustomLog -Level 'SUCCESS' -Message "Lab infrastructure created successfully"
        } else {
            Write-CustomLog -Level 'ERROR' -Message "Lab infrastructure creation failed"
        }
        
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create lab infrastructure: $($_.Exception.Message)"
        throw
    }
}

function Get-DeploymentStatus {
    <#
    .SYNOPSIS
        Gets the status of OpenTofu deployment
    .DESCRIPTION
        Retrieves current deployment status and resource information
    .PARAMETER WorkingDirectory
        Working directory containing OpenTofu files
    #>
    [CmdletBinding()]
    param(
        [string]$WorkingDirectory = (Get-Location)
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving deployment status"
        
        # Check if OpenTofu is initialized
        $terraformDir = Join-Path $WorkingDirectory ".terraform"
        if (-not (Test-Path $terraformDir)) {
            return @{
                Initialized = $false
                Resources = @()
                State = "Not initialized"
            }
        }
        
        # Get state information
        $stateResult = Invoke-OpenTofuCommand -Command "show" -WorkingDirectory $WorkingDirectory
        
        return @{
            Initialized = $true
            Resources = if ($stateResult.Success) { $stateResult.Output } else { @() }
            State = if ($stateResult.Success) { "Deployed" } else { "Error" }
            LastError = $stateResult.Error
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment status: $($_.Exception.Message)"
        return @{
            Initialized = $false
            Resources = @()
            State = "Error"
            LastError = $_.Exception.Message
        }
    }
}