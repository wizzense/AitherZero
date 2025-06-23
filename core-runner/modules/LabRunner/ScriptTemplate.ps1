if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

#Param(object$Config)

function Invoke-LabStep {
    param(scriptblock$Body, object$Config)
    if ($Config -is string) {
        if (Test-Path $Config) {
            $Config = Get-Content -Raw -Path $Config | ConvertFrom-Json} else {
            try { $Config = $Config | ConvertFrom-Json} catch {}
        }
    }
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    
Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

}




