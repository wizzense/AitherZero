function Set-PatchManagerAliases {
    <#
    .SYNOPSIS
        Configures Git aliases for PatchManager integration
    .DESCRIPTION
        Sets up convenient Git aliases that integrate with AitherZero's PatchManager module
        for streamlined development workflow
    .PARAMETER Install
        Install the Git aliases
    .PARAMETER Remove
        Remove the Git aliases
    .PARAMETER List
        List current PatchManager-related aliases
    .EXAMPLE
        Set-PatchManagerAliases -Install
        # Installs all PatchManager Git aliases
    .EXAMPLE
        Set-PatchManagerAliases -List
        # Shows all current PatchManager aliases
    #>
    [CmdletBinding(DefaultParameterSetName = 'Install')]
    param(
        [Parameter(ParameterSetName = 'Install')]
        [switch]$Install,

        [Parameter(ParameterSetName = 'Remove')]
        [switch]$Remove,

        [Parameter(ParameterSetName = 'List')]
        [switch]$List
    )

    try {
        # Define PatchManager Git aliases
        $aliases = @{
            'patch' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; New-Patch"'
            'quickfix' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; New-QuickFix"'
            'feature' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; New-Feature"'
            'hotfix' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; New-Hotfix"'
            'patch-status' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; Get-PatchStatus"'
            'sync-branch' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; Sync-GitBranch"'
            'patch-rollback' = 'pwsh -NoProfile -Command "Import-Module ./aither-core/modules/PatchManager -Force; Invoke-PatchRollback"'
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Install' {
                Write-Host "Installing PatchManager Git aliases..." -ForegroundColor Cyan

                foreach ($alias in $aliases.GetEnumerator()) {
                    try {
                        $null = git config --global alias.$($alias.Key) $alias.Value
                        Write-Host "  ✓ git $($alias.Key)" -ForegroundColor Green
                    } catch {
                        Write-Warning "Failed to set alias '$($alias.Key)': $($_.Exception.Message)"
                    }
                }

                Write-Host "`nPatchManager aliases installed successfully!" -ForegroundColor Green
                Write-Host "You can now use commands like:" -ForegroundColor Yellow
                Write-Host "  git patch -Description 'My changes'" -ForegroundColor White
                Write-Host "  git quickfix -Description 'Fix typo'" -ForegroundColor White
                Write-Host "  git feature -Description 'New feature'" -ForegroundColor White
                Write-Host "  git sync-branch" -ForegroundColor White
            }

            'Remove' {
                Write-Host "Removing PatchManager Git aliases..." -ForegroundColor Cyan

                foreach ($alias in $aliases.Keys) {
                    try {
                        $null = git config --global --unset alias.$alias 2>$null
                        Write-Host "  ✓ Removed git $alias" -ForegroundColor Green
                    } catch {
                        Write-Verbose "Alias '$alias' was not set or failed to remove: $($_.Exception.Message)"
                    }
                }

                Write-Host "PatchManager aliases removed successfully!" -ForegroundColor Green
            }

            'List' {
                Write-Host "Current PatchManager Git aliases:" -ForegroundColor Cyan

                foreach ($alias in $aliases.Keys) {
                    try {
                        $currentValue = git config --global --get alias.$alias 2>$null
                        if ($currentValue) {
                            Write-Host "  git $alias" -ForegroundColor Green
                            Write-Host "    → $currentValue" -ForegroundColor Gray
                        } else {
                            Write-Host "  git $alias" -ForegroundColor Red -NoNewline
                            Write-Host " (not configured)" -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "  git $alias" -ForegroundColor Red -NoNewline
                        Write-Host " (error checking)" -ForegroundColor Gray
                    }
                }
            }
        }

        # Log the operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "PatchManager aliases operation completed" -Level INFO -Context @{
                Operation = $PSCmdlet.ParameterSetName
                AliasCount = $aliases.Count
            }
        }

    } catch {
        Write-Error "Failed to configure PatchManager aliases: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "PatchManager aliases operation failed" -Level ERROR -Exception $_.Exception
        }

        throw
    }
}

function Remove-ProjectEmojis {
    <#
    .SYNOPSIS
        Removes emojis from project files
    .DESCRIPTION
        Scans project files and removes emoji characters to maintain professional code standards
    .PARAMETER Path
        Root path to scan (defaults to current directory)
    .PARAMETER FileTypes
        File extensions to process
    .PARAMETER WhatIf
        Show what would be changed without making changes
    .EXAMPLE
        Remove-ProjectEmojis
        # Removes emojis from common code files in current directory
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Path = ".",

        [Parameter()]
        [string[]]$FileTypes = @('*.ps1', '*.psm1', '*.psd1', '*.md', '*.json', '*.yml', '*.yaml'),

        [Parameter()]
        [switch]$WhatIf
    )

    try {
        Write-Host "Scanning for emojis in project files..." -ForegroundColor Cyan

        # Get all files to process
        $files = @()
        foreach ($fileType in $FileTypes) {
            $files += Get-ChildItem -Path $Path -Filter $fileType -Recurse -File
        }

        $processedFiles = 0
        $modifiedFiles = 0

        foreach ($file in $files) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8

                if ($content) {
                    # Simple emoji pattern (basic Unicode emoji ranges)
                    $emojiPattern = '[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]'

                    if ($content -match $emojiPattern) {
                        if ($WhatIf) {
                            Write-Host "  Would modify: $($file.FullName)" -ForegroundColor Yellow
                        } else {
                            $cleanContent = $content -replace $emojiPattern, ''
                            Set-Content -Path $file.FullName -Value $cleanContent -Encoding UTF8
                            Write-Host "  ✓ Cleaned: $($file.FullName)" -ForegroundColor Green
                            $modifiedFiles++
                        }
                    }
                }

                $processedFiles++

            } catch {
                Write-Warning "Failed to process file '$($file.FullName)': $($_.Exception.Message)"
            }
        }

        Write-Host "Emoji cleanup completed!" -ForegroundColor Green
        Write-Host "  Files processed: $processedFiles" -ForegroundColor White
        Write-Host "  Files modified: $modifiedFiles" -ForegroundColor White

        # Log the operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Project emoji cleanup completed" -Level INFO -Context @{
                ProcessedFiles = $processedFiles
                ModifiedFiles = $modifiedFiles
                WhatIf = $WhatIf.IsPresent
            }
        }

    } catch {
        Write-Error "Failed to remove project emojis: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Project emoji cleanup failed" -Level ERROR -Exception $_.Exception
        }

        throw
    }
}
