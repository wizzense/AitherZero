<#
    This module helps fix problems, found by Meta.Tests.ps1
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

function ConvertTo-UTF8()
{
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [System.IO.FileInfo]$fileInfo
    )

    process 
    {
        $content = Get-Content -Raw -Encoding Unicode -Path $fileInfo.FullName
        [System.IO.File]::WriteAllText($fileInfo.FullName, $content, [System.Text.Encoding]::UTF8)
    }
}

function ConvertTo-ASCII()
{
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [System.IO.FileInfo]$fileInfo
    )

    process 
    {
        $content = Get-Content -Raw -Encoding Unicode -Path $fileInfo.FullName
        [System.IO.File]::WriteAllText($fileInfo.FullName, $content, [System.Text.Encoding]::ASCII)
    }
}

function ConvertTo-SpaceIndentation()
{
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [System.IO.FileInfo]$fileInfo
    )

    process 
    {
        $content = (Get-Content -Raw -Path $fileInfo.FullName) -replace "`t",'    '
        [System.IO.File]::WriteAllText($fileInfo.FullName, $content)
    }
}

function Get-TextFilesList
{
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$root
    )
    ls -File -Recurse $root | ? { @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof') -contains $_.Extension } 
}

function Test-FileUnicode
{
    
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [System.IO.FileInfo]$fileInfo
    )

    process 
    {

        $path = $fileInfo.FullName
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $zeroBytes = @($bytes -eq 0)
        return [bool]$zeroBytes.Length

    }
}

function Get-UnicodeFilesList()
{
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$root
    )

    Get-TextFilesList $root | ? { Test-FileUnicode $_ }
}

function Add-NewLine()
{
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [System.IO.FileInfo]$fileInfo
    )

    process 
    {
        $content = Get-Content -Raw -Path $fileInfo.FullName
        $content += "`r`n"
        [System.IO.File]::WriteAllText($fileInfo.FullName, $content)
    }
}
