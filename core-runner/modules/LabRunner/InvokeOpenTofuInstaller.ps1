function Invoke-OpenTofuInstaller {
    param(
        [string]$CosignPath,
        [string]$OpenTofuVersion
    )
    
    $installer = (Resolve-Path (Join-Path $PSScriptRoot 'OpenTofuInstaller.ps1')).Path
    Write-CustomLog "Running OpenTofuInstaller.ps1 with version $OpenTofuVersion"
    & $installer -installMethod standalone -cosignPath $CosignPath -opentofuVersion $OpenTofuVersion
    Write-CustomLog 'OpenTofu installer completed'
}



