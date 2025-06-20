function Get-LabConfig {
    CmdletBinding()
    param(

        string$Path = (Join-Path $PSScriptRoot '..\default-config.json')
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found at $Path"
    }

    try {

        $content = Get-Content -Raw -Path $Path
        if ($Path -match '\.ya?ml$') {
            if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
                try {
                    Import-Module powershell-yaml -ErrorAction Stop
                }
                catch {
                    throw "YAML support requires the 'powershell-yaml' module. Install it with 'Install-Module powershell-yaml'."
                }
            }
            $config = $content  ConvertFrom-Yaml
        }
        else {
            $config = $content | ConvertFrom-Json}

        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $dirs     = @{}
        if ($config.PSObject.Properties'Directories') {
            # Preserve any user-defined directory settings
            $config.Directories.PSObject.Properties | ForEach-Object{
                $dirs$_.Name = $_.Value
            }
        }

        $dirs'RepoRoot'       = $repoRoot.Path
        $dirs'RunnerScripts'  = Join-Path $repoRoot 'core-runner/core_app/scripts'
        $dirs'UtilityScripts' = Join-Path (Join-Path $repoRoot 'lab_utils') 'LabRunner'
        $dirs'ConfigFiles'    = Join-Path $repoRoot 'config_files'
        $dirs'InfraRepo'      = if ($config.InfraRepoPath) { $config.InfraRepoPath } else { 'C:\\Temp\\base-infra' }

        Add-Member -InputObject $config -MemberType NoteProperty -Name Directories -Value (pscustomobject$dirs) -Force
        return $config
    }
    catch {
        throw "Failed to parse config file $Path. $_"


    }
}





