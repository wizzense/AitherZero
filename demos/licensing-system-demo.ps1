#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates the AitherZero source code obfuscation and licensing system
    
.DESCRIPTION
    Shows end-to-end functionality including:
    - License creation and validation
    - String encryption and decryption
    - File encryption and decryption
    - Key management
#>

Write-Host "`n=== AitherZero Licensing & Obfuscation System Demo ===" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = 'Stop'

try {
    # Import modules and get module objects for invocation
    Write-Host "0. Loading security modules..." -ForegroundColor Yellow
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $script:EncryptionMod = Import-Module (Join-Path $projectRoot "domains/security/Encryption.psm1") -Force -PassThru
    $script:LicenseMod = Import-Module (Join-Path $projectRoot "domains/security/LicenseManager.psm1") -Force -PassThru
    Write-Host "  ✓ Modules loaded successfully" -ForegroundColor Green

    # 1. Generate encryption key
    Write-Host "`n1. Generating secure encryption key..." -ForegroundColor Yellow
    $key = & $script:EncryptionMod { New-EncryptionKey }
    Write-Host "  ✓ Key generated: $($key.Substring(0, 20))..." -ForegroundColor Green

    # 2. Create license
    Write-Host "`n2. Creating license..." -ForegroundColor Yellow
    $licenseFile = Join-Path ([System.IO.Path]::GetTempPath()) "demo-license-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $license = & $script:LicenseMod { 
        param($id, $to, $exp, $k, $out, $feat)
        New-License -LicenseId $id -LicensedTo $to -ExpirationDate $exp -EncryptionKey $k -OutputPath $out -Features $feat
    } "DEMO-$(Get-Date -Format 'yyyyMMdd')" "Demo User" (Get-Date).AddYears(1) $key $licenseFile @("SourceCodeObfuscation", "RuntimeDecryption")
    
    Write-Host "  ✓ License ID: $($license.LicenseId)" -ForegroundColor Green
    Write-Host "  ✓ Licensed To: $($license.LicensedTo)" -ForegroundColor Green
    Write-Host "  ✓ Expires: $([datetime]::Parse($license.ExpirationDate).ToString('yyyy-MM-dd'))" -ForegroundColor Green
    Write-Host "  ✓ Features: $($license.Features -join ', ')" -ForegroundColor Green
    Write-Host "  ✓ Saved to: $licenseFile" -ForegroundColor Green

    # 3. Validate license
    Write-Host "`n3. Validating license..." -ForegroundColor Yellow
    $validation = & $script:LicenseMod { 
        param($path)
        Test-License -LicensePath $path
    } $licenseFile
    if ($validation.IsValid) {
        Write-Host "  ✓ License is VALID" -ForegroundColor Green
    } else {
        throw "License validation failed: $($validation.Reason)"
    }

    # 4. Encrypt a string
    Write-Host "`n4. Encrypting sensitive data..." -ForegroundColor Yellow
    $plainText = "This is proprietary source code that must be protected. Contains trade secrets!"
    Write-Host "  Original: '$plainText'"
    
    $encrypted = & $script:EncryptionMod { 
        param($text, $k)
        Protect-String -PlainText $text -Key $k
    } $plainText $key
    Write-Host "  ✓ Encrypted data: $($encrypted.EncryptedData.Substring(0, 50))..." -ForegroundColor Green
    Write-Host "  ✓ Length: $($encrypted.EncryptedData.Length) characters" -ForegroundColor Green

    # 5. Decrypt the string
    Write-Host "`n5. Decrypting data..." -ForegroundColor Yellow
    $decrypted = & $script:EncryptionMod {
        param($enc, $k, $s, $iv)
        Unprotect-String -EncryptedData $enc -Key $k -Salt $s -InitializationVector $iv
    } $encrypted.EncryptedData $key $encrypted.Salt $encrypted.IV
    
    Write-Host "  ✓ Decrypted: '$decrypted'" -ForegroundColor Green

    # 6. Verify integrity
    Write-Host "`n6. Verifying data integrity..." -ForegroundColor Yellow
    if ($decrypted -eq $plainText) {
        Write-Host "  ✓ SUCCESS: Decrypted text matches original!" -ForegroundColor Green
    } else {
        throw "Data integrity check failed!"
    }

    # 7. File encryption demo
    Write-Host "`n7. Testing file encryption..." -ForegroundColor Yellow
    $testFile = Join-Path ([System.IO.Path]::GetTempPath()) "demo-module.psm1"
    $moduleContent = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    Proprietary module with trade secrets
#>

function Get-ProprietaryAlgorithm {
    [CmdletBinding()]
    param([string]$Input)
    
    # Secret algorithm here
    $secret = "Trade secret calculation"
    return "$Input : $secret"
}

Export-ModuleMember -Function Get-ProprietaryAlgorithm
'@
    $moduleContent | Out-File -FilePath $testFile -NoNewline
    Write-Host "  Created test file: $testFile"
    
    $fileResult = & $script:EncryptionMod {
        param($path, $k)
        Protect-File -Path $path -Key $k
    } $testFile $key
    Write-Host "  ✓ File encrypted: $($fileResult.EncryptedFile)" -ForegroundColor Green
    Write-Host "  ✓ Metadata saved: $($fileResult.MetadataFile)" -ForegroundColor Green
    
    # 8. Decrypt file
    Write-Host "`n8. Decrypting file..." -ForegroundColor Yellow
    $decryptedFile = & $script:EncryptionMod {
        param($path, $k)
        Unprotect-File -Path $path -Key $k
    } $fileResult.EncryptedFile $key
    Write-Host "  ✓ File decrypted to: $decryptedFile" -ForegroundColor Green
    
    $decryptedContent = Get-Content -Path $decryptedFile -Raw
    if ($decryptedContent -eq $moduleContent) {
        Write-Host "  ✓ File content integrity verified!" -ForegroundColor Green
    } else {
        throw "File content mismatch!"
    }

    # 9. Test key retrieval from license
    Write-Host "`n9. Testing key retrieval from license..." -ForegroundColor Yellow
    $retrievedKey = & $script:LicenseMod {
        param($path)
        Get-LicenseKey -LicensePath $path
    } $licenseFile
    if ($retrievedKey -eq $key) {
        Write-Host "  ✓ Key retrieved successfully from license" -ForegroundColor Green
    } else {
        throw "Key retrieval failed!"
    }

    # Success summary
    Write-Host "`n=== Demo Completed Successfully ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✓ All operations successful:" -ForegroundColor Green
    Write-Host "  • License created and validated" -ForegroundColor Green
    Write-Host "  • String encryption/decryption working" -ForegroundColor Green
    Write-Host "  • File encryption/decryption working" -ForegroundColor Green
    Write-Host "  • Key management operational" -ForegroundColor Green
    Write-Host "  • Data integrity verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "System ready for production use!" -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host "`n=== Demo Failed ===" -ForegroundColor Red
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "✗ Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "`nStack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace
    exit 1
}
