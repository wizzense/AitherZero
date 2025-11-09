<#
.SYNOPSIS
    Inject deployment artifacts into ISO images for automated OS installation.

.DESCRIPTION
    This script automates the injection of AitherZero configuration artifacts into
    Windows and Linux ISO images. It supports:
    - Windows: Autounattend.xml, registry files, scripts
    - Linux: Cloud-init configs, preseed/kickstart files, scripts
    - Custom bootstrap scripts
    - Artifact validation

.PARAMETER IsoPath
    Path to the source ISO file to customize.

.PARAMETER OutputPath
    Path where the customized ISO will be created.

.PARAMETER Platform
    Target platform: Windows or Linux.

.PARAMETER ConfigPath
    Path to the configuration file (config.windows.psd1 or config.linux.psd1).
    Defaults to OS-specific config in repository root.

.PARAMETER ArtifactPath
    Path to pre-generated artifacts. If not specified, artifacts will be generated.

.PARAMETER BootstrapScript
    Path to custom bootstrap script to inject into the ISO.
    For Windows: PowerShell script
    For Linux: Bash script

.PARAMETER Validate
    Validate the ISO structure and artifacts without creating output.

.PARAMETER Force
    Overwrite existing output ISO if it exists.

.EXAMPLE
    .\0195_Inject-ISO-Artifacts.ps1 -IsoPath "C:\ISOs\Windows.iso" -Platform Windows

.EXAMPLE
    .\0195_Inject-ISO-Artifacts.ps1 -IsoPath "/isos/ubuntu.iso" -Platform Linux -BootstrapScript "./custom-bootstrap.sh"

.NOTES
    Stage: 0100-0199 (Infrastructure)
    Dependencies: DeploymentArtifacts module, 7zip or oscdimg (Windows), genisoimage (Linux)
    Tags: ISO, Deployment, Automation, Unattended

#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Windows', 'Linux')]
    [string]$Platform,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactPath,

    [Parameter(Mandatory = $false)]
    [string]$BootstrapScript,

    [Parameter(Mandatory = $false)]
    [switch]$Validate,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#Requires -Version 7.0

# Import required modules
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "domains/infrastructure/DeploymentArtifacts.psm1") -Force

# Logging
function Write-IsoLog {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Information' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Main execution
try {
    Write-IsoLog "═══════════════════════════════════════════════════════" -Level Information
    Write-IsoLog "ISO Artifact Injection - AitherZero" -Level Information
    Write-IsoLog "═══════════════════════════════════════════════════════" -Level Information
    Write-IsoLog "Platform: $Platform" -Level Information
    Write-IsoLog "Source ISO: $IsoPath" -Level Information
    Write-IsoLog "Output ISO: $OutputPath" -Level Information
    Write-IsoLog ""

    # Step 1: Validate prerequisites
    Write-IsoLog "Step 1: Validating prerequisites..." -Level Information
    
    # Check for required tools
    if ($Platform -eq 'Windows') {
        $oscdimg = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
        $sevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue
        
        if (-not $oscdimg -and -not $sevenZip) {
            throw "Required tools not found. Install Windows ADK (oscdimg) or 7-Zip"
        }
        
        if ($oscdimg) {
            Write-IsoLog "  Found oscdimg.exe: $($oscdimg.Source)" -Level Information
        }
        if ($sevenZip) {
            Write-IsoLog "  Found 7z.exe: $($sevenZip.Source)" -Level Information
        }
    }
    elseif ($Platform -eq 'Linux') {
        $genisoimage = Get-Command genisoimage -ErrorAction SilentlyContinue
        $xorriso = Get-Command xorriso -ErrorAction SilentlyContinue
        
        if (-not $genisoimage -and -not $xorriso) {
            throw "Required tools not found. Install genisoimage or xorriso"
        }
        
        if ($genisoimage) {
            Write-IsoLog "  Found genisoimage: $($genisoimage.Source)" -Level Information
        }
        if ($xorriso) {
            Write-IsoLog "  Found xorriso: $($xorriso.Source)" -Level Information
        }
    }

    # Step 2: Set up working directory
    Write-IsoLog ""
    Write-IsoLog "Step 2: Setting up working directory..." -Level Information
    
    $workDir = Join-Path $env:TEMP "AitherZero-ISO-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $extractDir = Join-Path $workDir "extracted"
    $artifactDir = Join-Path $workDir "artifacts"
    
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    
    Write-IsoLog "  Working directory: $workDir" -Level Information

    # Step 3: Extract ISO
    Write-IsoLog ""
    Write-IsoLog "Step 3: Extracting ISO..." -Level Information
    
    if ($Platform -eq 'Windows') {
        if ($sevenZip) {
            & 7z.exe x "$IsoPath" -o"$extractDir" -y | Out-Null
        }
        else {
            # Use PowerShell to mount and copy
            $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            Copy-Item -Path "${driveLetter}:\*" -Destination $extractDir -Recurse -Force
            Dismount-DiskImage -ImagePath $IsoPath | Out-Null
        }
    }
    else {
        # Linux: Use 7z if available on Windows, otherwise mount
        if ($sevenZip) {
            & 7z.exe x "$IsoPath" -o"$extractDir" -y | Out-Null
        }
        elseif ($IsLinux) {
            $mountPoint = "/mnt/iso-temp"
            sudo mkdir -p $mountPoint
            sudo mount -o loop "$IsoPath" $mountPoint
            cp -r "$mountPoint/*" "$extractDir/"
            sudo umount $mountPoint
        }
    }
    
    Write-IsoLog "  Extracted to: $extractDir" -Level Information

    # Step 4: Generate or copy artifacts
    Write-IsoLog ""
    Write-IsoLog "Step 4: Preparing deployment artifacts..." -Level Information
    
    if ($ArtifactPath -and (Test-Path $ArtifactPath)) {
        Write-IsoLog "  Copying pre-generated artifacts..." -Level Information
        Copy-Item -Path "$ArtifactPath\*" -Destination $artifactDir -Recurse -Force
    }
    else {
        Write-IsoLog "  Generating artifacts..." -Level Information
        
        # Set config path
        if (-not $ConfigPath) {
            $ConfigPath = Join-Path $ProjectRoot "config.$($Platform.ToLower()).psd1"
        }
        
        if (-not (Test-Path $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        
        # Generate artifacts
        $params = @{
            Platform = $Platform
            ConfigPath = $ConfigPath
            OutputPath = $artifactDir
        }
        
        New-DeploymentArtifacts @params
        
        Write-IsoLog "  Artifacts generated in: $artifactDir" -Level Information
    }

    # Step 5: Inject artifacts into ISO structure
    Write-IsoLog ""
    Write-IsoLog "Step 5: Injecting artifacts into ISO..." -Level Information
    
    if ($Platform -eq 'Windows') {
        # Windows: Copy Autounattend.xml to root
        $unattendSource = Join-Path $artifactDir "Autounattend.xml"
        $unattendDest = Join-Path $extractDir "Autounattend.xml"
        
        if (Test-Path $unattendSource) {
            Copy-Item -Path $unattendSource -Destination $unattendDest -Force
            Write-IsoLog "  Injected Autounattend.xml to ISO root" -Level Information
        }
        
        # Copy scripts to $OEM$
        $oemDir = Join-Path $extractDir '$OEM$\$$\Setup\Scripts'
        New-Item -ItemType Directory -Path $oemDir -Force | Out-Null
        
        if ($BootstrapScript -and (Test-Path $BootstrapScript)) {
            Copy-Item -Path $BootstrapScript -Destination (Join-Path $oemDir "bootstrap.ps1") -Force
            Write-IsoLog "  Injected bootstrap script" -Level Information
        }
        
        # Copy registry files
        Get-ChildItem -Path $artifactDir -Filter "*.reg" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $oemDir -Force
            Write-IsoLog "  Injected $($_.Name)" -Level Information
        }
    }
    elseif ($Platform -eq 'Linux') {
        # Linux: Create cloud-init directory
        $cloudInitDir = Join-Path $extractDir "var\lib\cloud\seed\nocloud"
        New-Item -ItemType Directory -Path $cloudInitDir -Force | Out-Null
        
        # Copy cloud-init files
        $cloudInitSource = Join-Path $artifactDir "cloud-init.yaml"
        if (Test-Path $cloudInitSource) {
            Copy-Item -Path $cloudInitSource -Destination (Join-Path $cloudInitDir "user-data") -Force
            Write-IsoLog "  Injected cloud-init user-data" -Level Information
        }
        
        # Copy bootstrap script
        if ($BootstrapScript -and (Test-Path $BootstrapScript)) {
            Copy-Item -Path $BootstrapScript -Destination (Join-Path $extractDir "bootstrap.sh") -Force
            Write-IsoLog "  Injected bootstrap script" -Level Information
        }
    }

    # Step 6: Validate (if requested)
    if ($Validate) {
        Write-IsoLog ""
        Write-IsoLog "Step 6: Validating ISO structure..." -Level Information
        
        if ($Platform -eq 'Windows') {
            $requiredFiles = @(
                (Join-Path $extractDir "Autounattend.xml"),
                (Join-Path $extractDir "sources\boot.wim")
            )
        }
        else {
            $requiredFiles = @(
                (Join-Path $extractDir "isolinux\isolinux.bin")
            )
        }
        
        foreach ($file in $requiredFiles) {
            if (Test-Path $file) {
                Write-IsoLog "  ✓ Found: $(Split-Path $file -Leaf)" -Level Information
            }
            else {
                Write-IsoLog "  ✗ Missing: $(Split-Path $file -Leaf)" -Level Warning
            }
        }
    }

    # Step 7: Create customized ISO
    if (-not $Validate) {
        Write-IsoLog ""
        Write-IsoLog "Step 7: Creating customized ISO..." -Level Information
        
        # Check if output exists
        if ((Test-Path $OutputPath) -and -not $Force) {
            throw "Output file exists. Use -Force to overwrite: $OutputPath"
        }
        
        if ($Platform -eq 'Windows') {
            if ($oscdimg) {
                # Use oscdimg for Windows ISOs
                $bootData = Join-Path $extractDir "boot\etfsboot.com"
                & oscdimg.exe -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$bootData"#pEF,e,b"$bootData" "$extractDir" "$OutputPath"
            }
            else {
                # Fallback to 7z (creates bootable ISO)
                & 7z.exe a -tiso -m0=BCJ2 -m1=LZMA:d27 "$OutputPath" "$extractDir\*"
            }
        }
        elseif ($Platform -eq 'Linux') {
            if ($genisoimage) {
                & genisoimage -o "$OutputPath" -b isolinux/isolinux.bin -c isolinux/boot.cat `
                    -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "AitherZero" "$extractDir"
            }
            elseif ($xorriso) {
                & xorriso -as mkisofs -o "$OutputPath" -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin `
                    -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 `
                    -boot-info-table "$extractDir"
            }
        }
        
        if (Test-Path $OutputPath) {
            $outputSize = (Get-Item $OutputPath).Length / 1MB
            Write-IsoLog "  ✓ Created ISO: $OutputPath ($([math]::Round($outputSize, 2)) MB)" -Level Information
        }
        else {
            throw "Failed to create ISO: $OutputPath"
        }
    }

    # Step 8: Cleanup
    Write-IsoLog ""
    Write-IsoLog "Step 8: Cleaning up..." -Level Information
    
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-IsoLog "  Removed working directory" -Level Information

    # Summary
    Write-IsoLog ""
    Write-IsoLog "═══════════════════════════════════════════════════════" -Level Information
    Write-IsoLog "✅ ISO Artifact Injection Completed Successfully" -Level Information
    Write-IsoLog "═══════════════════════════════════════════════════════" -Level Information
    
    if (-not $Validate) {
        Write-IsoLog ""
        Write-IsoLog "Customized ISO: $OutputPath" -Level Information
        Write-IsoLog ""
        Write-IsoLog "Next Steps:" -Level Information
        Write-IsoLog "  1. Test the ISO in a VM" -Level Information
        Write-IsoLog "  2. Verify unattended installation works" -Level Information
        Write-IsoLog "  3. Check bootstrap script execution" -Level Information
    }
}
catch {
    Write-IsoLog ""
    Write-IsoLog "❌ Error: $($_.Exception.Message)" -Level Error
    Write-IsoLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    
    # Cleanup on error
    if (Test-Path $workDir) {
        Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}
