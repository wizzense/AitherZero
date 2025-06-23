function Invoke-MassFileFix {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$FixOperation,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter()]
        [switch]$CreateBackup
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $backupPath = if ($CreateBackup) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            Join-Path 'backups' "pre-patch-$timestamp"
        }
    }

    process {
        try {
            if ($CreateBackup) {
                # Create backup directory
                New-Item -ItemType Directory -Force -Path $backupPath
                
                # Backup files
                foreach ($file in $FilePaths) {
                    $relativePath = $file -replace [regex]::Escape($PWD.Path + '\'), ''
                    $backupFilePath = Join-Path $backupPath $relativePath
                    $backupDir = Split-Path $backupFilePath -Parent
                    
                    if (-not (Test-Path $backupDir)) {
                        New-Item -ItemType Directory -Force -Path $backupDir
                    }
                    
                    Copy-Item $file $backupFilePath -Force
                }
            }

            # Process each file
            foreach ($file in $FilePaths) {
                if ($PSCmdlet.ShouldProcess($file, $Description)) {
                    try {
                        $content = Get-Content -Path $file -Raw
                        $newContent = & $FixOperation $content
                        if ($newContent -ne $content) {
                            Set-Content -Path $file -Value $newContent -NoNewline
                            Write-Host "Updated: $file" -ForegroundColor Green
                        } else {
                            Write-Verbose "No changes needed: $file"
                        }
                    } catch {
                        Write-Warning "Failed to process $file : $_"
                    }
                }
            }

            Write-Host "`nOperation completed successfully" -ForegroundColor Green
            if ($CreateBackup) {
                Write-Host "Backup created at: $backupPath" -ForegroundColor Cyan
            }

        } catch {
            Write-Error "Failed to complete mass file fix: $_"
            if ($CreateBackup) {
                Write-Warning "Backup available at: $backupPath"
            }
            throw
        }
    }
}



