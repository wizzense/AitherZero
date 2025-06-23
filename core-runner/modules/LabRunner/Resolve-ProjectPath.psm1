function Resolve-ProjectPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Root
    )
    if (-not $Root) {
        $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    } else {
        $Root = (Resolve-Path $Root).Path
    }

    $indexPath = Join-Path $Root 'path-index.yaml'
    if (Test-Path $indexPath) {
        if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
            try { Import-Module powershell-yaml -ErrorAction Stop } catch {}
        }
        try { $index = hashtable(Get-Content -Raw -Path $indexPath  ConvertFrom-Yaml) } catch { $index = @{} }
        if ($index.ContainsKey($Name)) { return (Join-Path $Root $index$Name) }
        foreach ($key in $index.Keys) {
            if ((Split-Path $key -Leaf) -eq $Name) {
                return (Join-Path $Root $index$key)
            }
        }
    }

    # Fallback: recursive search
    $match = Get-ChildItem -Path $Root -Recurse -File -Filter $Name -ErrorAction SilentlyContinue  Select-Object -First 1
    if ($null -ne $match) { return $match.FullName }
    return $null
}

Export-ModuleMember -Function Resolve-ProjectPath



