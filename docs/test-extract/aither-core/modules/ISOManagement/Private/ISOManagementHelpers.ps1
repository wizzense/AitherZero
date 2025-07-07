# ISOManagement Module Helper Functions
# Unified helper functions combining functionality from ISOManager and ISOCustomizer

#region Template Management Helpers

function Get-AutounattendTemplate {
    <#
    .SYNOPSIS
        Retrieves autounattend.xml template files for Windows deployments.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Generic', 'Headless', 'HeadlessModern', 'Custom')]
        [string]$TemplateType = 'Generic'
    )

    $templatePath = $script:ISOManagementConfig.TemplateDirectory
    
    if (-not (Test-Path $templatePath)) {
        Write-CustomLog -Level 'WARNING' -Message "Template directory not found: $templatePath"
        return $null
    }

    $templateFile = switch ($TemplateType) {
        'Generic' { 'autounattend-generic.xml' }
        'Headless' { 'autounattend-headless.xml' }
        'HeadlessModern' { 'autounattend-headless-modern.xml' }
        'Custom' { 
            # Return all XML files for custom selection
            Get-ChildItem -Path $templatePath -Filter "*.xml" | Where-Object { $_.Name -notlike "autounattend-*" }
        }
    }

    if ($TemplateType -eq 'Custom') {
        return $templateFile
    }

    $fullPath = Join-Path $templatePath $templateFile
    if (Test-Path $fullPath) {
        return $fullPath
    } else {
        Write-CustomLog -Level 'WARNING' -Message "Template file not found: $fullPath"
        return $null
    }
}

function Get-BootstrapTemplate {
    <#
    .SYNOPSIS
        Retrieves bootstrap script templates for post-installation automation.
    #>
    [CmdletBinding()]
    param()

    $templatePath = Join-Path $script:ISOManagementConfig.TemplateDirectory 'bootstrap.ps1'
    
    if (Test-Path $templatePath) {
        return $templatePath
    } else {
        Write-CustomLog -Level 'WARNING' -Message "Bootstrap template not found: $templatePath"
        return $null
    }
}

function Get-KickstartTemplate {
    <#
    .SYNOPSIS
        Retrieves kickstart configuration templates for Linux deployments.
    #>
    [CmdletBinding()]
    param()

    $templatePath = Join-Path $script:ISOManagementConfig.TemplateDirectory 'kickstart.cfg'
    
    if (Test-Path $templatePath) {
        return $templatePath
    } else {
        Write-CustomLog -Level 'WARNING' -Message "Kickstart template not found: $templatePath"
        return $null
    }
}

#endregion

#region Workflow Management Helpers

function Add-WorkflowHistoryEntry {
    <#
    .SYNOPSIS
        Adds an entry to the workflow history log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WorkflowEntry
    )

    try {
        $historyPath = $script:ISOManagementConfig.WorkflowHistoryPath
        
        if (Test-Path $historyPath) {
            $history = Get-Content $historyPath | ConvertFrom-Json
        } else {
            $history = @{
                Version = $script:ISOManagementConfig.Version
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Workflows = @()
            }
        }

        # Add the new entry
        $history.Workflows += $WorkflowEntry

        # Maintain history size limit
        if ($history.Workflows.Count -gt $script:ISOManagementConfig.MaxHistoryEntries) {
            $history.Workflows = $history.Workflows | 
                Sort-Object StartTime -Descending | 
                Select-Object -First $script:ISOManagementConfig.MaxHistoryEntries
        }

        # Save updated history
        $history | ConvertTo-Json -Depth 10 | Out-File -FilePath $historyPath -Encoding UTF8
        
        Write-CustomLog -Level 'DEBUG' -Message "Added workflow entry to history: $($WorkflowEntry.WorkflowId)"
        
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to add workflow history entry: $($_.Exception.Message)"
    }
}

function Get-WorkflowHistoryEntries {
    <#
    .SYNOPSIS
        Retrieves workflow history entries with filtering options.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$WorkflowId,

        [Parameter(Mandatory = $false)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$MaxEntries = 50
    )

    try {
        $historyPath = $script:ISOManagementConfig.WorkflowHistoryPath
        
        if (-not (Test-Path $historyPath)) {
            return @()
        }

        $history = Get-Content $historyPath | ConvertFrom-Json
        $entries = $history.Workflows

        # Apply filters
        if ($WorkflowId) {
            $entries = $entries | Where-Object { $_.WorkflowId -eq $WorkflowId }
        }

        if ($Status) {
            $entries = $entries | Where-Object { $_.Status -eq $Status }
        }

        # Sort by start time (most recent first) and limit results
        $entries = $entries | 
            Sort-Object StartTime -Descending | 
            Select-Object -First $MaxEntries

        return $entries
        
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to retrieve workflow history: $($_.Exception.Message)"
        return @()
    }
}

function Clear-WorkflowHistory {
    <#
    .SYNOPSIS
        Clears workflow history entries with optional filtering.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$All,

        [Parameter(Mandatory = $false)]
        [int]$OlderThanDays,

        [Parameter(Mandatory = $false)]
        [string]$Status
    )

    try {
        $historyPath = $script:ISOManagementConfig.WorkflowHistoryPath
        
        if (-not (Test-Path $historyPath)) {
            Write-CustomLog -Level 'INFO' -Message "No workflow history file to clear"
            return
        }

        $history = Get-Content $historyPath | ConvertFrom-Json
        $originalCount = $history.Workflows.Count

        if ($All) {
            $history.Workflows = @()
        } else {
            $entries = $history.Workflows

            # Filter by age
            if ($OlderThanDays) {
                $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
                $entries = $entries | Where-Object { 
                    [DateTime]::Parse($_.StartTime) -ge $cutoffDate 
                }
            }

            # Filter by status
            if ($Status) {
                $entries = $entries | Where-Object { $_.Status -ne $Status }
            }

            $history.Workflows = $entries
        }

        # Save updated history
        $history | ConvertTo-Json -Depth 10 | Out-File -FilePath $historyPath -Encoding UTF8
        
        $clearedCount = $originalCount - $history.Workflows.Count
        Write-CustomLog -Level 'SUCCESS' -Message "Cleared $clearedCount workflow history entries"
        
        return @{
            OriginalCount = $originalCount
            RemainingCount = $history.Workflows.Count
            ClearedCount = $clearedCount
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to clear workflow history: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Configuration Management Helpers

function Initialize-ModuleConfiguration {
    <#
    .SYNOPSIS
        Initializes module configuration and creates required directories.
    #>
    [CmdletBinding()]
    param()

    try {
        # Create default repository if it doesn't exist
        if (-not (Test-Path $script:ISOManagementConfig.DefaultRepositoryPath)) {
            Write-CustomLog -Level 'INFO' -Message "Creating default ISO repository"
            
            New-Item -ItemType Directory -Path $script:ISOManagementConfig.DefaultRepositoryPath -Force | Out-Null
            
            # Create repository structure
            $repoStructure = @('Windows', 'Linux', 'Custom', 'Metadata', 'Logs', 'Temp', 'Archive', 'Backup', 'Templates')
            foreach ($folder in $repoStructure) {
                $folderPath = Join-Path $script:ISOManagementConfig.DefaultRepositoryPath $folder
                New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
            }
            
            # Create repository configuration
            $repoConfig = @{
                Name = "Default-ISO-Repository"
                Description = "Default ISO repository created by ISOManagement module"
                Path = $script:ISOManagementConfig.DefaultRepositoryPath
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Version = $script:ISOManagementConfig.Version
                ModuleVersion = $script:ISOManagementConfig.Version
                ConsolidatedFrom = $script:ISOManagementConfig.ConsolidatedModules
            }
            
            $configPath = Join-Path $script:ISOManagementConfig.DefaultRepositoryPath "repository.config.json"
            $repoConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
        }

        # Initialize workflow history
        if (-not (Test-Path $script:ISOManagementConfig.WorkflowHistoryPath)) {
            $initialHistory = @{
                Version = $script:ISOManagementConfig.Version
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Workflows = @()
            }
            $initialHistory | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ISOManagementConfig.WorkflowHistoryPath -Encoding UTF8
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Module configuration initialized successfully"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize module configuration: $($_.Exception.Message)"
        throw
    }
}

function Test-ModuleEnvironment {
    <#
    .SYNOPSIS
        Tests the module environment and reports any issues.
    #>
    [CmdletBinding()]
    param()

    $issues = @()
    $warnings = @()

    # Check default repository
    if (-not (Test-Path $script:ISOManagementConfig.DefaultRepositoryPath)) {
        $issues += "Default repository path does not exist: $($script:ISOManagementConfig.DefaultRepositoryPath)"
    }

    # Check template directory
    if (-not (Test-Path $script:ISOManagementConfig.TemplateDirectory)) {
        $issues += "Template directory does not exist: $($script:ISOManagementConfig.TemplateDirectory)"
    }

    # Check Windows ADK (Windows only)
    if ($IsWindows) {
        if (-not $script:ISOManagementConfig.OscdimgPath -or -not (Test-Path $script:ISOManagementConfig.OscdimgPath)) {
            $warnings += "Windows ADK oscdimg.exe not found - ISO creation for Windows will be limited"
        }
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $warnings += "PowerShell version $($PSVersionTable.PSVersion) detected - PowerShell 7.0+ recommended for full functionality"
    }

    # Check available disk space
    try {
        $repoPath = $script:ISOManagementConfig.DefaultRepositoryPath
        if (Test-Path $repoPath) {
            $drive = Split-Path $repoPath -Qualifier
            if ($IsWindows) {
                $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $drive }
                if ($disk -and $disk.FreeSpace) {
                    $freeSpaceGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
                    if ($freeSpaceGB -lt 10) {
                        $warnings += "Low disk space on repository drive: $freeSpaceGB GB available"
                    }
                }
            }
        }
    } catch {
        $warnings += "Could not check disk space: $($_.Exception.Message)"
    }

    return @{
        IsHealthy = ($issues.Count -eq 0)
        Issues = $issues
        Warnings = $warnings
        Summary = "Issues: $($issues.Count), Warnings: $($warnings.Count)"
    }
}

#endregion

#region Utility Helpers

function Resolve-ISOPath {
    <#
    .SYNOPSIS
        Resolves ISO file paths, including repository searches and downloads.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ISOPath,

        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath
    )

    # If it's already a valid full path, return it
    if ([System.IO.Path]::IsPathRooted($ISOPath) -and (Test-Path $ISOPath)) {
        return $ISOPath
    }

    # Use default repository if not specified
    if (-not $RepositoryPath) {
        $RepositoryPath = $script:ISOManagementConfig.DefaultRepositoryPath
    }

    # Search in repository subdirectories
    $searchPaths = @(
        (Join-Path $RepositoryPath "Windows"),
        (Join-Path $RepositoryPath "Linux"),
        (Join-Path $RepositoryPath "Custom"),
        $RepositoryPath
    )

    foreach ($searchPath in $searchPaths) {
        $fullPath = Join-Path $searchPath $ISOPath
        if (Test-Path $fullPath) {
            return $fullPath
        }

        # Try with .iso extension if not already present
        if (-not $ISOPath.EndsWith('.iso')) {
            $isoPath = $fullPath + '.iso'
            if (Test-Path $isoPath) {
                return $isoPath
            }
        }
    }

    # If not found, return original path (may trigger download logic)
    return $ISOPath
}

function Format-FileSize {
    <#
    .SYNOPSIS
        Formats file sizes in human-readable format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )

    $sizes = @('B', 'KB', 'MB', 'GB', 'TB')
    $index = 0
    $size = [double]$Bytes

    while ($size -ge 1024 -and $index -lt ($sizes.Length - 1)) {
        $size = $size / 1024
        $index++
    }

    return "{0:N2} {1}" -f $size, $sizes[$index]
}

function New-UniqueFileName {
    <#
    .SYNOPSIS
        Generates unique file names to avoid conflicts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $false)]
        [string]$Suffix = ""
    )

    $directory = Split-Path $BasePath -Parent
    $fileName = Split-Path $BasePath -LeafBase
    $extension = Split-Path $BasePath -Extension
    
    $counter = 1
    $newPath = $BasePath

    while (Test-Path $newPath) {
        $newFileName = if ($Suffix) {
            "$fileName-$Suffix-$counter$extension"
        } else {
            "$fileName-$counter$extension"
        }
        $newPath = Join-Path $directory $newFileName
        $counter++
    }

    return $newPath
}

#endregion

#region Validation Helpers

function Test-ISOFile {
    <#
    .SYNOPSIS
        Performs basic validation of ISO file structure and accessibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ISOPath
    )

    $result = @{
        IsValid = $false
        FileExists = $false
        IsReadable = $false
        FileSize = 0
        Issues = @()
    }

    # Check if file exists
    if (-not (Test-Path $ISOPath)) {
        $result.Issues += "ISO file does not exist: $ISOPath"
        return $result
    }

    $result.FileExists = $true

    try {
        # Check if file is readable and get size
        $fileInfo = Get-Item $ISOPath
        $result.FileSize = $fileInfo.Length
        $result.IsReadable = $true

        # Basic size validation
        if ($result.FileSize -lt 1MB) {
            $result.Issues += "ISO file appears too small (less than 1MB): $(Format-FileSize $result.FileSize)"
        }

        # Check file extension
        if (-not $ISOPath.EndsWith('.iso', [StringComparison]::OrdinalIgnoreCase)) {
            $result.Issues += "File does not have .iso extension"
        }

        # If no issues, mark as valid
        if ($result.Issues.Count -eq 0) {
            $result.IsValid = $true
        }

    } catch {
        $result.Issues += "Cannot access ISO file: $($_.Exception.Message)"
    }

    return $result
}

function Test-TemplatePath {
    <#
    .SYNOPSIS
        Validates template file paths and accessibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $false)]
        [string]$TemplateType = 'Unknown'
    )

    $result = @{
        IsValid = $false
        FileExists = $false
        IsReadable = $false
        TemplateType = $TemplateType
        Issues = @()
    }

    if (-not (Test-Path $TemplatePath)) {
        $result.Issues += "Template file does not exist: $TemplatePath"
        return $result
    }

    $result.FileExists = $true

    try {
        # Try to read the file
        $content = Get-Content $TemplatePath -Raw -ErrorAction Stop
        $result.IsReadable = $true

        # Validate content based on template type
        switch ($TemplateType.ToLower()) {
            'autounattend' {
                if ($content -notmatch '<unattend.*xmlns') {
                    $result.Issues += "File does not appear to be a valid autounattend XML file"
                }
            }
            'bootstrap' {
                if ($TemplatePath.EndsWith('.ps1') -and $content -notmatch '#.*PowerShell|Write-Host|Write-Output') {
                    $result.Issues += "File does not appear to be a valid PowerShell script"
                }
            }
            'kickstart' {
                if ($content -notmatch '#.*kickstart|%packages|%post') {
                    $result.Issues += "File does not appear to be a valid kickstart configuration"
                }
            }
        }

        # If no issues, mark as valid
        if ($result.Issues.Count -eq 0) {
            $result.IsValid = $true
        }

    } catch {
        $result.Issues += "Cannot read template file: $($_.Exception.Message)"
    }

    return $result
}

#endregion