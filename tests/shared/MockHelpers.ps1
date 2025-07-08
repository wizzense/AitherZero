#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Centralized mocking framework for AitherZero tests

.DESCRIPTION
    Provides reusable mock helpers for common operations including:
    - Git operations
    - File system operations
    - Network operations
    - System services
    - Registry access
    - External tools

.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    Created: 2025-07-08
#>

# Check if we're in a test context
$script:IsTestContext = $null -ne (Get-Command Mock -ErrorAction SilentlyContinue)

# Helper function to safely create mocks
function New-SafeMock {
    param(
        [string]$CommandName,
        [scriptblock]$MockWith
    )
    
    if ($script:IsTestContext) {
        Mock -CommandName $CommandName -MockWith $MockWith
    } else {
        Write-Verbose "Skipping mock for $CommandName - not in test context"
    }
}

# Mock configuration tracking
$script:MockConfig = @{
    Git = @{
        Enabled = $false
        Repository = @{
            Branch = "main"
            RemoteUrl = "https://github.com/test/repo.git"
            IsDirty = $false
            Commits = @()
        }
    }
    FileSystem = @{
        Enabled = $false
        VirtualPaths = @{}
        VirtualContent = @{}
    }
    Network = @{
        Enabled = $false
        Responses = @{}
        Failures = @()
    }
    System = @{
        Enabled = $false
        Services = @{}
        Processes = @{}
        Registry = @{}
    }
}

#region Git Operations Mocking

<#
.SYNOPSIS
    Initialize git mocking for tests
#>
function Initialize-GitMocking {
    [CmdletBinding()]
    param(
        [string]$CurrentBranch = "main",
        [string]$RemoteUrl = "https://github.com/test/repo.git",
        [switch]$IsDirty,
        [string[]]$Commits = @("abc123 Initial commit")
    )

    $script:MockConfig.Git.Enabled = $true
    $script:MockConfig.Git.Repository.Branch = $CurrentBranch
    $script:MockConfig.Git.Repository.RemoteUrl = $RemoteUrl
    $script:MockConfig.Git.Repository.IsDirty = $IsDirty.IsPresent
    $script:MockConfig.Git.Repository.Commits = $Commits

    # Mock git executable
    New-SafeMock -CommandName git -MockWith {
        param($Command)
        
        switch ($Command) {
            "rev-parse" {
                if ($args[0] -eq "HEAD") {
                    return $script:MockConfig.Git.Repository.Commits[0].Split(' ')[0]
                }
                if ($args[0] -eq "--show-toplevel") {
                    return "/fake/repo/path"
                }
                return "abc123"
            }
            "branch" {
                if ($args[0] -eq "--show-current") {
                    return $script:MockConfig.Git.Repository.Branch
                }
                return "* $($script:MockConfig.Git.Repository.Branch)"
            }
            "status" {
                if ($script:MockConfig.Git.Repository.IsDirty) {
                    return @(
                        "On branch $($script:MockConfig.Git.Repository.Branch)",
                        "Changes not staged for commit:",
                        "  modified: test-file.txt"
                    )
                }
                return @(
                    "On branch $($script:MockConfig.Git.Repository.Branch)",
                    "nothing to commit, working tree clean"
                )
            }
            "remote" {
                if ($args[0] -eq "get-url" -and $args[1] -eq "origin") {
                    return $script:MockConfig.Git.Repository.RemoteUrl
                }
                return "origin"
            }
            "log" {
                return $script:MockConfig.Git.Repository.Commits
            }
            "add" {
                return "Files added successfully"
            }
            "commit" {
                $newCommit = "def456 $($args[-1])"
                $script:MockConfig.Git.Repository.Commits = @($newCommit) + $script:MockConfig.Git.Repository.Commits
                return $newCommit
            }
            "checkout" {
                if ($args[0] -eq "-b") {
                    $script:MockConfig.Git.Repository.Branch = $args[1]
                    return "Switched to a new branch '$($args[1])'"
                }
                $script:MockConfig.Git.Repository.Branch = $args[0]
                return "Switched to branch '$($args[0])'"
            }
            "push" {
                return "Everything up-to-date"
            }
            "pull" {
                return "Already up to date."
            }
            "merge" {
                return "Merge successful"
            }
            "config" {
                return $true
            }
            "init" {
                return "Initialized empty Git repository"
            }
            default {
                return "Git command executed: $Command $($args -join ' ')"
            }
        }
    }

    Write-Host "Git mocking initialized with branch: $CurrentBranch" -ForegroundColor Green
}

<#
.SYNOPSIS
    Set git repository state for testing
#>
function Set-GitRepositoryState {
    [CmdletBinding()]
    param(
        [string]$Branch,
        [switch]$IsDirty,
        [string[]]$Commits,
        [string]$RemoteUrl
    )

    if ($Branch) { $script:MockConfig.Git.Repository.Branch = $Branch }
    if ($IsDirty.IsPresent) { $script:MockConfig.Git.Repository.IsDirty = $true }
    if ($Commits) { $script:MockConfig.Git.Repository.Commits = $Commits }
    if ($RemoteUrl) { $script:MockConfig.Git.Repository.RemoteUrl = $RemoteUrl }
}

<#
.SYNOPSIS
    Add simulated git conflict markers to test content
#>
function Add-GitConflictMarkers {
    [CmdletBinding()]
    param(
        [string]$Content,
        [string]$HeadContent = "HEAD content",
        [string]$BranchContent = "branch content"
    )

    return @"
$Content
<<<<<<< HEAD
$HeadContent
=======
$BranchContent
>>>>>>> branch-name
"@
}

#endregion

#region File System Operations Mocking

<#
.SYNOPSIS
    Initialize file system mocking for tests
#>
function Initialize-FileSystemMocking {
    [CmdletBinding()]
    param(
        [hashtable]$VirtualPaths = @{},
        [hashtable]$VirtualContent = @{}
    )

    $script:MockConfig.FileSystem.Enabled = $true
    $script:MockConfig.FileSystem.VirtualPaths = $VirtualPaths
    $script:MockConfig.FileSystem.VirtualContent = $VirtualContent

    # Mock Test-Path
    Mock -CommandName Test-Path -MockWith {
        param($Path)
        
        if ($script:MockConfig.FileSystem.VirtualPaths.ContainsKey($Path)) {
            return $script:MockConfig.FileSystem.VirtualPaths[$Path]
        }
        
        # Default behavior for unmocked paths
        return $false
    }

    # Mock Get-Content
    Mock -CommandName Get-Content -MockWith {
        param($Path)
        
        if ($script:MockConfig.FileSystem.VirtualContent.ContainsKey($Path)) {
            return $script:MockConfig.FileSystem.VirtualContent[$Path]
        }
        
        throw "Mock: File not found: $Path"
    }

    # Mock Set-Content
    Mock -CommandName Set-Content -MockWith {
        param($Path, $Value)
        
        $script:MockConfig.FileSystem.VirtualContent[$Path] = $Value
        return $true
    }

    # Mock New-Item
    Mock -CommandName New-Item -MockWith {
        param($Path, $ItemType)
        
        $script:MockConfig.FileSystem.VirtualPaths[$Path] = $true
        if ($ItemType -eq "File") {
            $script:MockConfig.FileSystem.VirtualContent[$Path] = ""
        }
        
        return [PSCustomObject]@{
            FullName = $Path
            Name = Split-Path -Leaf $Path
            Exists = $true
        }
    }

    # Mock Remove-Item
    Mock -CommandName Remove-Item -MockWith {
        param($Path)
        
        if ($script:MockConfig.FileSystem.VirtualPaths.ContainsKey($Path)) {
            $script:MockConfig.FileSystem.VirtualPaths.Remove($Path)
        }
        if ($script:MockConfig.FileSystem.VirtualContent.ContainsKey($Path)) {
            $script:MockConfig.FileSystem.VirtualContent.Remove($Path)
        }
        return $true
    }

    # Mock Get-ChildItem
    Mock -CommandName Get-ChildItem -MockWith {
        param($Path)
        
        $results = @()
        foreach ($virtualPath in $script:MockConfig.FileSystem.VirtualPaths.Keys) {
            if ($virtualPath.StartsWith($Path)) {
                $results += [PSCustomObject]@{
                    FullName = $virtualPath
                    Name = Split-Path -Leaf $virtualPath
                    PSIsContainer = $script:MockConfig.FileSystem.VirtualContent.ContainsKey($virtualPath) -eq $false
                }
            }
        }
        return $results
    }

    Write-Host "File system mocking initialized" -ForegroundColor Green
}

<#
.SYNOPSIS
    Add virtual file or directory to mock file system
#>
function Add-VirtualPath {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Content,
        [switch]$IsDirectory
    )

    $script:MockConfig.FileSystem.VirtualPaths[$Path] = $true
    
    if (-not $IsDirectory -and $Content) {
        $script:MockConfig.FileSystem.VirtualContent[$Path] = $Content
    }
}

<#
.SYNOPSIS
    Remove virtual file or directory from mock file system
#>
function Remove-VirtualPath {
    [CmdletBinding()]
    param([string]$Path)

    $script:MockConfig.FileSystem.VirtualPaths.Remove($Path)
    $script:MockConfig.FileSystem.VirtualContent.Remove($Path)
}

#endregion

#region Network Operations Mocking

<#
.SYNOPSIS
    Initialize network mocking for tests
#>
function Initialize-NetworkMocking {
    [CmdletBinding()]
    param(
        [hashtable]$MockedResponses = @{},
        [string[]]$FailingUrls = @()
    )

    $script:MockConfig.Network.Enabled = $true
    $script:MockConfig.Network.Responses = $MockedResponses
    $script:MockConfig.Network.Failures = $FailingUrls

    # Mock Invoke-RestMethod
    Mock -CommandName Invoke-RestMethod -MockWith {
        param($Uri, $Method, $Body, $Headers)
        
        if ($script:MockConfig.Network.Failures -contains $Uri) {
            throw "Mock: Network request failed for $Uri"
        }
        
        if ($script:MockConfig.Network.Responses.ContainsKey($Uri)) {
            return $script:MockConfig.Network.Responses[$Uri]
        }
        
        # Default response
        return @{
            Status = "Success"
            Message = "Mock response for $Uri"
            Method = $Method
            RequestTime = Get-Date
        }
    }

    # Mock Invoke-WebRequest
    Mock -CommandName Invoke-WebRequest -MockWith {
        param($Uri, $Method, $Body, $Headers)
        
        if ($script:MockConfig.Network.Failures -contains $Uri) {
            throw "Mock: Web request failed for $Uri"
        }
        
        if ($script:MockConfig.Network.Responses.ContainsKey($Uri)) {
            $response = $script:MockConfig.Network.Responses[$Uri]
            return [PSCustomObject]@{
                StatusCode = 200
                Content = $response | ConvertTo-Json
                Headers = @{}
            }
        }
        
        # Default response
        return [PSCustomObject]@{
            StatusCode = 200
            Content = "Mock web response"
            Headers = @{}
        }
    }

    Write-Host "Network mocking initialized" -ForegroundColor Green
}

<#
.SYNOPSIS
    Add mock response for specific URL
#>
function Add-MockResponse {
    [CmdletBinding()]
    param(
        [string]$Url,
        [object]$Response
    )

    $script:MockConfig.Network.Responses[$Url] = $Response
}

<#
.SYNOPSIS
    Add URL to failing requests list
#>
function Add-FailingUrl {
    [CmdletBinding()]
    param([string]$Url)

    $script:MockConfig.Network.Failures += $Url
}

#endregion

#region System Services Mocking

<#
.SYNOPSIS
    Initialize system services mocking for tests
#>
function Initialize-SystemServicesMocking {
    [CmdletBinding()]
    param(
        [hashtable]$MockedServices = @{},
        [hashtable]$MockedProcesses = @{},
        [hashtable]$MockedRegistry = @{}
    )

    $script:MockConfig.System.Enabled = $true
    $script:MockConfig.System.Services = $MockedServices
    $script:MockConfig.System.Processes = $MockedProcesses
    $script:MockConfig.System.Registry = $MockedRegistry

    # Mock Get-Service
    Mock -CommandName Get-Service -MockWith {
        param($Name)
        
        if ($Name -and $script:MockConfig.System.Services.ContainsKey($Name)) {
            return $script:MockConfig.System.Services[$Name]
        }
        
        # Return all mocked services if no name specified
        return $script:MockConfig.System.Services.Values
    }

    # Mock Get-Process
    Mock -CommandName Get-Process -MockWith {
        param($Name)
        
        if ($Name -and $script:MockConfig.System.Processes.ContainsKey($Name)) {
            return $script:MockConfig.System.Processes[$Name]
        }
        
        # Return all mocked processes if no name specified
        return $script:MockConfig.System.Processes.Values
    }

    # Mock Start-Service
    Mock -CommandName Start-Service -MockWith {
        param($Name)
        
        if ($script:MockConfig.System.Services.ContainsKey($Name)) {
            $script:MockConfig.System.Services[$Name].Status = "Running"
        }
        return $true
    }

    # Mock Stop-Service
    Mock -CommandName Stop-Service -MockWith {
        param($Name)
        
        if ($script:MockConfig.System.Services.ContainsKey($Name)) {
            $script:MockConfig.System.Services[$Name].Status = "Stopped"
        }
        return $true
    }

    # Mock Registry operations
    Mock -CommandName Get-ItemProperty -MockWith {
        param($Path, $Name)
        
        if ($script:MockConfig.System.Registry.ContainsKey($Path)) {
            $regKey = $script:MockConfig.System.Registry[$Path]
            if ($Name) {
                return $regKey[$Name]
            }
            return $regKey
        }
        
        throw "Mock: Registry key not found: $Path"
    }

    Write-Host "System services mocking initialized" -ForegroundColor Green
}

<#
.SYNOPSIS
    Add mock service to system services
#>
function Add-MockService {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Status = "Running",
        [string]$StartType = "Automatic"
    )

    $script:MockConfig.System.Services[$Name] = [PSCustomObject]@{
        Name = $Name
        Status = $Status
        StartType = $StartType
        ServiceName = $Name
    }
}

<#
.SYNOPSIS
    Add mock process to system processes
#>
function Add-MockProcess {
    [CmdletBinding()]
    param(
        [string]$Name,
        [int]$Id = (Get-Random -Maximum 99999),
        [string]$ProcessName = $Name
    )

    $script:MockConfig.System.Processes[$Name] = [PSCustomObject]@{
        Name = $Name
        Id = $Id
        ProcessName = $ProcessName
        WorkingSet = 1024000
        CPU = 0.5
    }
}

#endregion

#region External Tools Mocking

<#
.SYNOPSIS
    Initialize external tools mocking for tests
#>
function Initialize-ExternalToolsMocking {
    [CmdletBinding()]
    param(
        [hashtable]$ToolResponses = @{}
    )

    # Mock common external tools
    $tools = @('terraform', 'tofu', 'docker', 'kubectl', 'az', 'aws', 'gcloud')
    
    foreach ($tool in $tools) {
        $response = if ($ToolResponses.ContainsKey($tool)) {
            $ToolResponses[$tool]
        } else {
            "Mock $tool output"
        }
        
        Mock -CommandName $tool -MockWith {
            return $response
        }.GetNewClosure()
    }

    # Mock PowerShell execution
    Mock -CommandName Start-Process -MockWith {
        param($FilePath, $ArgumentList)
        
        return [PSCustomObject]@{
            ExitCode = 0
            StandardOutput = "Mock process output"
            StandardError = ""
        }
    }

    Write-Host "External tools mocking initialized" -ForegroundColor Green
}

#endregion

#region Mock Management and Cleanup

<#
.SYNOPSIS
    Initialize all mocking systems for comprehensive testing
#>
function Initialize-ComprehensiveMocking {
    [CmdletBinding()]
    param(
        [switch]$IncludeGit,
        [switch]$IncludeFileSystem,
        [switch]$IncludeNetwork,
        [switch]$IncludeSystemServices,
        [switch]$IncludeExternalTools
    )

    Write-Host "Initializing comprehensive mocking framework..." -ForegroundColor Cyan

    if ($IncludeGit) {
        Initialize-GitMocking
    }

    if ($IncludeFileSystem) {
        Initialize-FileSystemMocking
    }

    if ($IncludeNetwork) {
        Initialize-NetworkMocking
    }

    if ($IncludeSystemServices) {
        Initialize-SystemServicesMocking
    }

    if ($IncludeExternalTools) {
        Initialize-ExternalToolsMocking
    }

    Write-Host "Comprehensive mocking framework initialized" -ForegroundColor Green
}

<#
.SYNOPSIS
    Reset all mock configurations to default state
#>
function Reset-MockConfiguration {
    [CmdletBinding()]
    param()

    $script:MockConfig = @{
        Git = @{
            Enabled = $false
            Repository = @{
                Branch = "main"
                RemoteUrl = "https://github.com/test/repo.git"
                IsDirty = $false
                Commits = @()
            }
        }
        FileSystem = @{
            Enabled = $false
            VirtualPaths = @{}
            VirtualContent = @{}
        }
        Network = @{
            Enabled = $false
            Responses = @{}
            Failures = @()
        }
        System = @{
            Enabled = $false
            Services = @{}
            Processes = @{}
            Registry = @{}
        }
    }

    Write-Host "Mock configuration reset to default state" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Get current mock configuration for debugging
#>
function Get-MockConfiguration {
    [CmdletBinding()]
    param()

    return $script:MockConfig
}

<#
.SYNOPSIS
    Validate that mocks are properly isolated between tests
#>
function Test-MockIsolation {
    [CmdletBinding()]
    param()

    $issues = @()

    # Check if any mocks have persistent state
    if ($script:MockConfig.Git.Repository.Commits.Count -gt 0) {
        $issues += "Git commits not reset between tests"
    }

    if ($script:MockConfig.FileSystem.VirtualPaths.Count -gt 0) {
        $issues += "Virtual file system paths not cleaned up"
    }

    if ($script:MockConfig.Network.Responses.Count -gt 0) {
        $issues += "Network response mocks not reset"
    }

    if ($issues.Count -gt 0) {
        Write-Warning "Mock isolation issues detected:"
        $issues | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }

    return $true
}

#endregion

#region Pester Integration Helpers

<#
.SYNOPSIS
    BeforeEach helper for setting up mocks
#>
function Set-TestMockEnvironment {
    [CmdletBinding()]
    param(
        [string[]]$MockTypes = @("Git", "FileSystem", "Network", "SystemServices", "ExternalTools")
    )

    foreach ($mockType in $MockTypes) {
        switch ($mockType) {
            "Git" { Initialize-GitMocking }
            "FileSystem" { Initialize-FileSystemMocking }
            "Network" { Initialize-NetworkMocking }
            "SystemServices" { Initialize-SystemServicesMocking }
            "ExternalTools" { Initialize-ExternalToolsMocking }
        }
    }
}

<#
.SYNOPSIS
    AfterEach helper for cleaning up mocks
#>
function Clear-TestMockEnvironment {
    [CmdletBinding()]
    param()

    Reset-MockConfiguration
}

#endregion

# Functions are automatically available when dot-sourced
# Export-ModuleMember is only needed for .psm1 modules