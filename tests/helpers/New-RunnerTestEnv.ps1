# Helper to create an isolated runner test environment.
# Returns the path to the temporary directory.

if (-not $script:RunnerTestEnvDirs) { $script:RunnerTestEnvDirs = @() }

function global:New-RunnerTestEnv {
    $root = Join-Path $TestDrive ([guid]::NewGuid())
    if (Test-Path $root) {
        Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    $repoRoot = Join-Path $PSScriptRoot '..' '..'
    $pwshDir = Join-Path $root 'pwsh'
    if (-not (Test-Path $pwshDir)) { New-Item -ItemType Directory -Path $pwshDir -Force | Out-Null }
    Copy-Item (Join-Path $repoRoot 'core-runner' 'core_app' 'core-runner.ps1') -Destination $pwshDir

    $rsDir = Join-Path $root 'core-runner' 'core_app' 'scripts'

    if (-not (Test-Path $rsDir)) { New-Item -ItemType Directory -Path $rsDir -Force | Out-Null }
    $utils = Join-Path $pwshDir 'modules/LabRunner'
            if (-not (Test-Path $utils)) { New-Item -ItemType Directory -Path $utils -Force | Out-Null }
    
    'function Write-CustomLog { 
        param([string]$Message, [string]$Level) 
        Write-Host "[$Level] $Message"
    }' | Set-Content -Path (Join-Path $utils 'Logger.ps1')

    $labs = Join-Path $pwshDir 'lab_utils'
    if (-not (Test-Path $labs)) { New-Item -ItemType Directory -Path $labs -Force | Out-Null }
    Copy-Item (Join-Path $repoRoot 'core-runner' 'modules' 'LabRunner' 'Resolve-ProjectPath.psm1') -Destination $labs -Force -ErrorAction SilentlyContinue
    
    'function Get-LabConfig { 
        param([string]$Path) 
        Get-Content -Raw $Path | ConvertFrom-Json
    }' | Set-Content -Path (Join-Path $labs 'Get-LabConfig.ps1')
    
    'function Format-Config { 
        param($Config) 
        $Config | ConvertTo-Json -Depth 5 
    }' | Set-Content -Path (Join-Path $labs 'Format-Config.ps1')
    
    'function Get-Platform {
        if ($IsWindows) { return "Windows" }
        elseif ($IsLinux) { return "Linux" }
        elseif ($IsMacOS) { return "MacOS" }
        else { return "Unknown" }
    }' | Set-Content -Path (Join-Path $labs 'Get-Platform.ps1')
    
    'function Get-MenuSelection { }' | Set-Content -Path (Join-Path $labs 'Menu.ps1')

    # Also expose Resolve-ProjectPath from the repository root so tests invoking
    # runner.ps1 can locate it via $root/lab_utils
    $rootLabs = Join-Path $root 'lab_utils'
            if (-not (Test-Path $rootLabs)) { New-Item -ItemType Directory -Path $rootLabs -Force | Out-Null }
    Copy-Item (Join-Path $repoRoot 'core-runner' 'modules' 'LabRunner' 'Resolve-ProjectPath.psm1') -Destination $rootLabs -ErrorAction SilentlyContinue

    $cfgDir = Join-Path $root 'configs' 'config_files'
            if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
    '{}' | Set-Content -Path (Join-Path $cfgDir 'default-config.json')
    '{}' | Set-Content -Path (Join-Path $cfgDir 'recommended-config.json')

    $script:RunnerTestEnvDirs += $root
    return $root
}

function global:Remove-RunnerTestEnv {
    foreach ($envDir in $script:RunnerTestEnvDirs) {
        Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
    }
    $script:RunnerTestEnvDirs = @()
}
