function Get-AutounattendTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Generic', 'Headless')]
        [string]$TemplateType = 'Generic'
    )

    $templateDir = Join-Path $PSScriptRoot '../Templates'

    $templateFile = switch ($TemplateType) {
        'Generic' { 'autounattend-generic.xml' }
        'Headless' { 'autounattend-headless.xml' }
        default { 'autounattend-generic.xml' }
    }

    $templatePath = Join-Path $templateDir $templateFile

    if (Test-Path $templatePath) {
        return $templatePath
    } else {
        Write-CustomLog -Level 'WARN' -Message "Template not found: $templatePath"
        return $null
    }
}

function Get-BootstrapTemplate {
    [CmdletBinding()]
    param()

    $templateDir = Join-Path $PSScriptRoot '../Templates'
    $bootstrapPath = Join-Path $templateDir 'bootstrap.ps1'

    if (Test-Path $bootstrapPath) {
        return $bootstrapPath
    } else {
        Write-CustomLog -Level 'WARN' -Message "Bootstrap template not found: $bootstrapPath"
        return $null
    }
}

function Get-KickstartTemplate {
    [CmdletBinding()]
    param()

    $templateDir = Join-Path $PSScriptRoot '../Templates'
    $kickstartPath = Join-Path $templateDir 'kickstart.cfg'

    if (Test-Path $kickstartPath) {
        return $kickstartPath
    } else {
        Write-CustomLog -Level 'WARN' -Message "Kickstart template not found: $kickstartPath"
        return $null
    }
}
