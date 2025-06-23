function New-CustomISO {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceISOPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputISOPath,

        [Parameter(Mandatory = $false)]
        [string]$ExtractPath,

        [Parameter(Mandatory = $false)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [string]$BootstrapScript,

        [Parameter(Mandatory = $false)]
        [string]$AutounattendFile,

        [Parameter(Mandatory = $false)]
        [hashtable]$AutounattendConfig,

        [Parameter(Mandatory = $false)]
        [int]$WIMIndex = 3,

        [Parameter(Mandatory = $false)]
        [string[]]$AdditionalFiles = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$DriversPath = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$RegistryChanges = @{},

        [Parameter(Mandatory = $false)]
        [string]$OscdimgPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$KeepTempFiles,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly
    )    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting custom ISO creation from: $SourceISOPath"

        # Set default bootstrap script if not specified
        if (-not $BootstrapScript) {
            $defaultBootstrap = Get-BootstrapTemplate
            if ($defaultBootstrap) {
                $BootstrapScript = $defaultBootstrap
                Write-CustomLog -Level 'INFO' -Message "Using default bootstrap template: $BootstrapScript"
            }
        }

        # Set default paths
        if (-not $ExtractPath) {
            $ExtractPath = Join-Path $env:TEMP "ISOExtract_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }

        if (-not $MountPath) {
            $MountPath = Join-Path $env:TEMP "ISOMount_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }

        if (-not $OscdimgPath) {
            $OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
        }

        # Verify prerequisites
        if (-not (Test-Path $SourceISOPath)) {
            throw "Source ISO not found: $SourceISOPath"
        }

        if ((Test-Path $OutputISOPath) -and -not $Force) {
            throw "Output ISO already exists: $OutputISOPath. Use -Force to overwrite."
        }

        # Check for administrative privileges (required for DISM operations)
        if (-not (Test-AdminPrivileges)) {
            throw "This operation requires administrative privileges for DISM operations"
        }

        # Verify Windows ADK/DISM availability
        if (-not (Test-Path $OscdimgPath)) {
            throw "Windows ADK oscdimg.exe not found at: $OscdimgPath. Please install Windows ADK."
        }

        # Create working directories
        foreach ($path in @($ExtractPath, $MountPath)) {
            if (Test-Path $path) {
                if ($Force) {
                    Remove-Item -Path $path -Recurse -Force
                } else {
                    throw "Working directory already exists: $path. Use -Force to overwrite."
                }
            }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($OutputISOPath, "Create Custom ISO")) {

                # Step 1: Mount the source ISO
                Write-CustomLog -Level 'INFO' -Message "Mounting source ISO..."
                $mountResult = Mount-DiskImage -ImagePath $SourceISOPath -PassThru
                $driveLetter = (Get-Volume -DiskImage $mountResult).DriveLetter + ":"

                try {
                    # Step 2: Extract ISO contents
                    Write-CustomLog -Level 'INFO' -Message "Extracting ISO contents to: $ExtractPath"
                    $robocopyArgs = @(
                        "$driveLetter\",
                        "$ExtractPath\",
                        "/E",
                        "/R:3",
                        "/W:1",
                        "/NP"
                    )

                    $robocopyResult = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow

                    # Robocopy exit codes 0-7 are success, 8+ are errors
                    if ($robocopyResult.ExitCode -gt 7) {
                        throw "Failed to extract ISO contents. Robocopy exit code: $($robocopyResult.ExitCode)"
                    }

                    # Step 3: Generate autounattend file if configuration provided
                    if ($AutounattendConfig -and -not $AutounattendFile) {
                        Write-CustomLog -Level 'INFO' -Message "Generating autounattend file from configuration..."
                        $AutounattendFile = Join-Path $ExtractPath "autounattend.xml"
                        New-AutounattendFile -Configuration $AutounattendConfig -OutputPath $AutounattendFile
                    }

                    # Step 4: Mount WIM for modification
                    $wimPath = Join-Path $ExtractPath "sources\install.wim"
                    if (-not (Test-Path $wimPath)) {
                        throw "install.wim not found in extracted ISO"
                    }

                    Write-CustomLog -Level 'INFO' -Message "Mounting WIM image (Index: $WIMIndex)..."
                    $dismArgs = @(
                        "/Mount-Image",
                        "/ImageFile:`"$wimPath`"",
                        "/Index:$WIMIndex",
                        "/MountDir:`"$MountPath`""
                    )

                    $dismResult = Start-Process -FilePath "dism" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow
                    if ($dismResult.ExitCode -ne 0) {
                        throw "Failed to mount WIM image. DISM exit code: $($dismResult.ExitCode)"
                    }

                    try {
                        # Step 5: Add bootstrap script if provided
                        if ($BootstrapScript) {
                            if (-not (Test-Path $BootstrapScript)) {
                                Write-CustomLog -Level 'WARN' -Message "Bootstrap script not found: $BootstrapScript"
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "Adding bootstrap script to Windows directory..."
                                $targetBootstrap = Join-Path $MountPath "Windows\bootstrap.ps1"
                                Copy-Item -Path $BootstrapScript -Destination $targetBootstrap -Force
                            }
                        }

                        # Step 6: Add additional files
                        foreach ($fileSpec in $AdditionalFiles) {
                            if ($fileSpec -match '^(.+)\|(.+)$') {
                                $sourcePath = $matches[1]
                                $targetPath = Join-Path $MountPath $matches[2]
                            } else {
                                $sourcePath = $fileSpec
                                $targetPath = Join-Path $MountPath "Windows\$(Split-Path $fileSpec -Leaf)"
                            }

                            if (Test-Path $sourcePath) {
                                Write-CustomLog -Level 'INFO' -Message "Adding file: $sourcePath -> $targetPath"
                                $targetDir = Split-Path $targetPath -Parent
                                if (-not (Test-Path $targetDir)) {
                                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                                }
                                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                            } else {
                                Write-CustomLog -Level 'WARN' -Message "Additional file not found: $sourcePath"
                            }
                        }

                        # Step 7: Add drivers if provided
                        foreach ($driverPath in $DriversPath) {
                            if (Test-Path $driverPath) {
                                Write-CustomLog -Level 'INFO' -Message "Adding drivers from: $driverPath"
                                $dismDriverArgs = @(
                                    "/Image:`"$MountPath`"",
                                    "/Add-Driver",
                                    "/Driver:`"$driverPath`"",
                                    "/Recurse"
                                )

                                $dismDriverResult = Start-Process -FilePath "dism" -ArgumentList $dismDriverArgs -Wait -PassThru -NoNewWindow
                                if ($dismDriverResult.ExitCode -ne 0) {
                                    Write-CustomLog -Level 'WARN' -Message "Failed to add drivers from: $driverPath"
                                }
                            }
                        }

                        # Step 8: Apply registry changes
                        if ($RegistryChanges.Count -gt 0) {
                            Write-CustomLog -Level 'INFO' -Message "Applying registry changes..."
                            Apply-OfflineRegistryChanges -MountPath $MountPath -Changes $RegistryChanges
                        }

                    } finally {
                        # Step 9: Unmount and commit WIM changes
                        Write-CustomLog -Level 'INFO' -Message "Committing changes and unmounting WIM..."
                        $dismUnmountArgs = @(
                            "/Unmount-Image",
                            "/MountDir:`"$MountPath`"",
                            "/Commit"
                        )

                        $dismUnmountResult = Start-Process -FilePath "dism" -ArgumentList $dismUnmountArgs -Wait -PassThru -NoNewWindow
                        if ($dismUnmountResult.ExitCode -ne 0) {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to unmount WIM image. DISM exit code: $($dismUnmountResult.ExitCode)"
                        }
                    }

                    # Step 10: Add autounattend.xml to ISO root if provided
                    if ($AutounattendFile -and (Test-Path $AutounattendFile)) {
                        Write-CustomLog -Level 'INFO' -Message "Adding autounattend.xml to ISO root..."
                        Copy-Item -Path $AutounattendFile -Destination (Join-Path $ExtractPath "autounattend.xml") -Force
                    }

                    # Step 11: Create bootable ISO
                    Write-CustomLog -Level 'INFO' -Message "Creating bootable ISO..."
                    $oscdimgArgs = @(
                        "-m",
                        "-o",
                        "-u2",
                        "-udfver102",
                        "-bootdata:2#p0,e,b`"$ExtractPath\boot\etfsboot.com`"#pEF,e,b`"$ExtractPath\efi\microsoft\boot\efisys.bin`"",
                        "`"$ExtractPath`"",
                        "`"$OutputISOPath`""
                    )

                    $oscdimgResult = Start-Process -FilePath $OscdimgPath -ArgumentList $oscdimgArgs -Wait -PassThru -NoNewWindow
                    if ($oscdimgResult.ExitCode -ne 0) {
                        throw "Failed to create bootable ISO. oscdimg exit code: $($oscdimgResult.ExitCode)"
                    }

                } finally {
                    # Always dismount the source ISO
                    Write-CustomLog -Level 'INFO' -Message "Dismounting source ISO..."
                    Dismount-DiskImage -ImagePath $SourceISOPath | Out-Null
                }

                # Cleanup temporary files if not keeping them
                if (-not $KeepTempFiles) {
                    Write-CustomLog -Level 'INFO' -Message "Cleaning up temporary files..."
                    Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Custom ISO created successfully: $OutputISOPath"

                return @{
                    Success = $true
                    SourceISO = $SourceISOPath
                    OutputISO = $OutputISOPath
                    WIMIndex = $WIMIndex
                    FileSize = (Get-Item $OutputISOPath).Length
                    CreationTime = Get-Date
                    ExtractPath = if ($KeepTempFiles) { $ExtractPath } else { $null }
                    MountPath = if ($KeepTempFiles) { $MountPath } else { $null }
                    Message = "Custom ISO created successfully"
                }
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create custom ISO: $($_.Exception.Message)"

            # Cleanup on error
            try {
                Dismount-DiskImage -ImagePath $SourceISOPath -ErrorAction SilentlyContinue | Out-Null
                Start-Process -FilePath "dism" -ArgumentList @("/Unmount-Image", "/MountDir:`"$MountPath`"", "/Discard") -Wait -NoNewWindow -ErrorAction SilentlyContinue
                Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Error during cleanup: $($_.Exception.Message)"
            }

            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed New-CustomISO operation"
    }
}
