# Configuration Management Helper Functions

function Get-RepositoryConfiguration {
    <#
    .SYNOPSIS
        Gets the repository configuration storage.
    #>
    [CmdletBinding()]
    param()
    
    $configPath = Join-Path $env:LOCALAPPDATA "AitherZero" "repository-config.json"
    $configDir = Split-Path $configPath -Parent
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
    } else {
        $config = @{
            Version = "1.0"
            Repositories = @{}
            BasePath = Join-Path $env:LOCALAPPDATA "AitherZero" "repositories"
        }
        Save-RepositoryConfiguration -Configuration $config
    }
    
    return $config
}

function Save-RepositoryConfiguration {
    <#
    .SYNOPSIS
        Saves the repository configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )
    
    $configPath = Join-Path $env:LOCALAPPDATA "AitherZero" "repository-config.json"
    $Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
}

function Test-RepositoryAccess {
    <#
    .SYNOPSIS
        Tests if a repository URL is accessible.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter()]
        [string]$CredentialName
    )
    
    try {
        # Simple connectivity test
        if ($Url -match '^https?://') {
            $uri = [Uri]$Url
            $response = Test-NetConnection -ComputerName $uri.Host -Port ($uri.Port ?? 443) -InformationLevel Quiet
            return $response
        } elseif ($Url -match '^git@') {
            # Git SSH URL
            return $true  # Assume accessible for now
        } elseif ($Url -match '^file://') {
            # Local file URL
            $localPath = $Url -replace '^file://', ''
            return Test-Path $localPath
        }
        
        return $false
    } catch {
        return $false
    }
}

function Invoke-GitClone {
    <#
    .SYNOPSIS
        Clones a Git repository.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [string]$Branch = "main",
        
        [Parameter()]
        [string]$CredentialName
    )
    
    try {
        $cloneArgs = @("clone", "--branch", $Branch, $Url, $Path)
        
        if ($CredentialName) {
            # Set up credential helper for this operation
            $env:GIT_ASKPASS = "echo"
            $cred = Get-StoredCredential -Name $CredentialName
            if ($cred) {
                $env:GIT_USERNAME = $cred.UserName
                $env:GIT_PASSWORD = $cred.GetNetworkCredential().Password
            }
        }
        
        $result = git @cloneArgs 2>&1
        $success = $LASTEXITCODE -eq 0
        
        @{
            Success = $success
            Output = $result
            Error = if (-not $success) { $result } else { $null }
        }
    } catch {
        @{
            Success = $false
            Output = $null
            Error = $_.Exception.Message
        }
    } finally {
        # Clean up environment
        Remove-Item env:GIT_ASKPASS -ErrorAction SilentlyContinue
        Remove-Item env:GIT_USERNAME -ErrorAction SilentlyContinue
        Remove-Item env:GIT_PASSWORD -ErrorAction SilentlyContinue
    }
}

function Test-RepositoryStructure {
    <#
    .SYNOPSIS
        Validates repository structure for templates.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
        Metadata = @{}
    }
    
    # Check for required directories
    $requiredDirs = @("templates", "docs")
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $Path $dir
        if (-not (Test-Path $dirPath)) {
            $result.Warnings += "Missing recommended directory: $dir"
        }
    }
    
    # Check for repository metadata
    $metadataFiles = @("repository.json", "repository.yaml", "README.md")
    $foundMetadata = $false
    
    foreach ($file in $metadataFiles) {
        $filePath = Join-Path $Path $file
        if (Test-Path $filePath) {
            $foundMetadata = $true
            if ($file -match '\.json$') {
                try {
                    $metadata = Get-Content $filePath -Raw | ConvertFrom-Json
                    $result.Metadata = $metadata
                } catch {
                    $result.Warnings += "Failed to parse $file"
                }
            }
            break
        }
    }
    
    if (-not $foundMetadata) {
        $result.Warnings += "No repository metadata file found"
    }
    
    # Check for templates
    $templatesPath = Join-Path $Path "templates"
    if (Test-Path $templatesPath) {
        $templates = Get-ChildItem -Path $templatesPath -Directory
        $result.Metadata.TemplateCount = $templates.Count
        
        if ($templates.Count -eq 0) {
            $result.Warnings += "No templates found in templates directory"
        }
    }
    
    return $result
}

function Get-GitCommit {
    <#
    .SYNOPSIS
        Gets current Git commit hash.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Push-Location $Path
    try {
        $commit = git rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $commit
        }
        return $null
    } finally {
        Pop-Location
    }
}

function Invoke-GitPull {
    <#
    .SYNOPSIS
        Pulls latest changes from Git repository.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [string]$Branch,
        
        [Parameter()]
        [string]$CredentialName
    )
    
    Push-Location $Path
    try {
        # Store current state
        $beforeCommit = git rev-parse HEAD 2>$null
        
        # Pull changes
        $pullArgs = @("pull")
        if ($Branch) {
            $pullArgs += @("origin", $Branch)
        }
        
        $result = git @pullArgs 2>&1
        $success = $LASTEXITCODE -eq 0
        
        # Get changes if successful
        $changes = @()
        if ($success) {
            $afterCommit = git rev-parse HEAD 2>$null
            if ($beforeCommit -ne $afterCommit) {
                $changes = git log "$beforeCommit..$afterCommit" --oneline 2>$null
            }
        }
        
        @{
            Success = $success
            Output = $result
            Error = if (-not $success) { $result } else { $null }
            Changes = $changes
        }
    } finally {
        Pop-Location
    }
}

function Reset-GitRepository {
    <#
    .SYNOPSIS
        Resets Git repository to specific commit.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$Commit
    )
    
    Push-Location $Path
    try {
        git reset --hard $Commit 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    } finally {
        Pop-Location
    }
}

function Get-DirectorySize {
    <#
    .SYNOPSIS
        Gets directory size in bytes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $size = 0
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
        ForEach-Object { $size += $_.Length }
    return $size
}

function Test-StoredCredential {
    <#
    .SYNOPSIS
        Tests if a stored credential exists and is valid.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        $cred = Get-StoredCredential -Name $Name -ErrorAction SilentlyContinue
        return $null -ne $cred
    } catch {
        return $false
    }
}

function Get-TemplateConfiguration {
    <#
    .SYNOPSIS
        Gets template system configuration.
    #>
    [CmdletBinding()]
    param()
    
    @{
        TemplatePath = Join-Path $env:LOCALAPPDATA "AitherZero" "templates"
        CachePath = Join-Path $env:TEMP "AitherZero" "template-cache"
    }
}

function Update-TemplateIndex {
    <#
    .SYNOPSIS
        Updates template index file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplatePath,
        
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter()]
        [switch]$SetAsLatest
    )
    
    $indexPath = Join-Path $TemplatePath "versions.json"
    
    $index = if (Test-Path $indexPath) {
        Get-Content $indexPath -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{
            versions = @()
            latest = $null
        }
    }
    
    if ($Version -notin $index.versions) {
        $index.versions += $Version
    }
    
    if ($SetAsLatest) {
        $index.latest = $Version
        
        # Create/update latest symlink
        $latestPath = Join-Path $TemplatePath "latest"
        if (Test-Path $latestPath) {
            Remove-Item $latestPath -Force -Recurse
        }
        
        # Copy instead of symlink for cross-platform compatibility
        $versionPath = Join-Path $TemplatePath $Version
        if (Test-Path $versionPath) {
            Copy-Item -Path $versionPath -Destination $latestPath -Recurse -Force
        }
    }
    
    $index | ConvertTo-Json -Depth 10 | Set-Content -Path $indexPath -Encoding UTF8
}

function ConvertTo-HashtableFromPSObject {
    <#
    .SYNOPSIS
        Converts PSCustomObject to hashtable recursively.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $InputObject
    )
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @()
        foreach ($item in $InputObject) {
            $collection += ConvertTo-HashtableFromPSObject $item
        }
        return ,$collection
    } elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [System.Management.Automation.PSObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-HashtableFromPSObject $property.Value
        }
        return $hash
    } else {
        return $InputObject
    }
}

function Merge-DeploymentConfigurations {
    <#
    .SYNOPSIS
        Deep merges two configuration hashtables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,
        
        [Parameter(Mandatory)]
        [hashtable]$Override
    )
    
    $merged = $Base.Clone()
    
    foreach ($key in $Override.Keys) {
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            # Recursive merge for nested hashtables
            $merged[$key] = Merge-DeploymentConfigurations -Base $merged[$key] -Override $Override[$key]
        } else {
            # Override value
            $merged[$key] = $Override[$key]
        }
    }
    
    return $merged
}

function Expand-ConfigurationVariables {
    <#
    .SYNOPSIS
        Expands variables in configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )
    
    $expanded = @{}
    
    foreach ($key in $Configuration.Keys) {
        $value = $Configuration[$key]
        
        if ($value -is [string]) {
            # Expand environment variables
            $expandedValue = [System.Environment]::ExpandEnvironmentVariables($value)
            
            # Expand configuration references ${config.key}
            if ($expandedValue -match '\$\{config\.([^}]+)\}') {
                $matches = [regex]::Matches($expandedValue, '\$\{config\.([^}]+)\}')
                foreach ($match in $matches) {
                    $refKey = $match.Groups[1].Value
                    if ($Configuration.ContainsKey($refKey)) {
                        $expandedValue = $expandedValue -replace [regex]::Escape($match.Value), $Configuration[$refKey]
                    }
                }
            }
            
            $expanded[$key] = $expandedValue
        } elseif ($value -is [hashtable]) {
            $expanded[$key] = Expand-ConfigurationVariables -Configuration $value
        } else {
            $expanded[$key] = $value
        }
    }
    
    return $expanded
}

function Test-ConfigurationSchema {
    <#
    .SYNOPSIS
        Validates configuration against schema.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [Parameter(Mandatory)]
        [string]$SchemaPath
    )
    
    # Simple schema validation (can be extended with JSON Schema)
    $result = @{
        IsValid = $true
        Errors = @()
    }
    
    # Load schema
    $schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json -AsHashtable
    
    # Validate required fields
    if ($schema.required) {
        foreach ($field in $schema.required) {
            if (-not $Configuration.ContainsKey($field)) {
                $result.IsValid = $false
                $result.Errors += "Missing required field: $field"
            }
        }
    }
    
    # Validate field types
    if ($schema.properties) {
        foreach ($prop in $schema.properties.Keys) {
            if ($Configuration.ContainsKey($prop)) {
                $expectedType = $schema.properties[$prop].type
                $actualValue = $Configuration[$prop]
                
                $isValid = switch ($expectedType) {
                    "string" { $actualValue -is [string] }
                    "number" { $actualValue -is [int] -or $actualValue -is [double] }
                    "boolean" { $actualValue -is [bool] }
                    "array" { $actualValue -is [array] }
                    "object" { $actualValue -is [hashtable] }
                    default { $true }
                }
                
                if (-not $isValid) {
                    $result.IsValid = $false
                    $result.Errors += "Invalid type for field '$prop': expected $expectedType"
                }
            }
        }
    }
    
    return $result
}

function Resolve-TemplatePath {
    <#
    .SYNOPSIS
        Resolves template reference to actual path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [Parameter()]
        [string]$BasePath
    )
    
    # Try different resolution strategies
    $possiblePaths = @()
    
    if ($BasePath) {
        $possiblePaths += Join-Path $BasePath $Template
        $possiblePaths += Join-Path $BasePath "templates" $Template
    }
    
    $templateConfig = Get-TemplateConfiguration
    $possiblePaths += Join-Path $templateConfig.TemplatePath $Template
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return @{
                Path = $path
                Name = Split-Path $path -Leaf
                Type = if (Test-Path (Join-Path $path "template.json")) { "structured" } else { "simple" }
            }
        }
    }
    
    return $null
}

function Expand-TemplateParameters {
    <#
    .SYNOPSIS
        Expands template parameters in resources.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Resources,
        
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )
    
    $json = $Resources | ConvertTo-Json -Depth 100
    
    # Replace parameter placeholders
    foreach ($param in $Parameters.Keys) {
        $value = $Parameters[$param]
        $json = $json -replace "\{\{\s*$param\s*\}\}", $value
    }
    
    $json | ConvertFrom-Json -AsHashtable
}