function Show-LicenseManager {
    <#
    .SYNOPSIS
        Shows the license management UI
    .DESCRIPTION
        Interactive interface for managing licenses
    #>
    [CmdletBinding()]
    param()
    
    try {
        $exitManager = $false
        
        while (-not $exitManager) {
            Clear-Host
            
            # Get current license info
            $licenseInfo = Get-LicenseInfo
            
            Write-Host "┌─ License Manager ───────────────────────────┐" -ForegroundColor Cyan
            Write-Host "│ Current License Status" -ForegroundColor Yellow
            Write-Host "│" -ForegroundColor Cyan
            Write-Host "│ Tier: " -NoNewline -ForegroundColor White
            switch ($licenseInfo.Tier) {
                'enterprise' { Write-Host "$($licenseInfo.TierName) 👑" -ForegroundColor Green }
                'pro' { Write-Host "$($licenseInfo.TierName) ⭐" -ForegroundColor Cyan }
                default { Write-Host "$($licenseInfo.TierName)" -ForegroundColor Yellow }
            }
            Write-Host "│ Status: " -NoNewline -ForegroundColor White
            if ($licenseInfo.Status -eq 'Valid') {
                Write-Host "✓ Valid" -ForegroundColor Green
            } else {
                Write-Host "✗ Invalid/Expired" -ForegroundColor Red
            }
            Write-Host "│ Licensed to: $($licenseInfo.IssuedTo)" -ForegroundColor White
            
            if ($licenseInfo.ExpiryDate) {
                Write-Host "│ Expires: " -NoNewline -ForegroundColor White
                $color = if ($licenseInfo.DaysRemaining -lt 30) { 'Red' } 
                        elseif ($licenseInfo.DaysRemaining -lt 90) { 'Yellow' } 
                        else { 'Green' }
                Write-Host "$($licenseInfo.ExpiryDate.ToString('yyyy-MM-dd')) ($($licenseInfo.DaysRemaining) days)" -ForegroundColor $color
            }
            
            Write-Host "│" -ForegroundColor Cyan
            Write-Host "│ [Actions]" -ForegroundColor Yellow
            Write-Host "│   A. Apply License Key" -ForegroundColor White
            Write-Host "│   F. Apply License File" -ForegroundColor White
            Write-Host "│   V. View Available Features" -ForegroundColor White
            Write-Host "│   G. Generate Test License" -ForegroundColor White
            Write-Host "│   C. Clear License" -ForegroundColor White
            Write-Host "│   U. Upgrade Information" -ForegroundColor White
            Write-Host "│   B. Back to Main Menu" -ForegroundColor White
            Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan
            
            $selection = Read-Host "`nSelect action"
            
            switch ($selection.ToUpper()) {
                'A' {
                    Apply-LicenseKeyInteractive
                }
                'F' {
                    Apply-LicenseFileInteractive
                }
                'V' {
                    Show-AvailableFeatures
                }
                'G' {
                    Generate-TestLicenseInteractive
                }
                'C' {
                    if ($licenseInfo.Tier -ne 'free') {
                        Clear-License
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Host "No license to clear" -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    }
                }
                'U' {
                    Show-UpgradeInformation
                }
                'B' {
                    $exitManager = $true
                }
            }
        }
        
    } catch {
        Write-Error "Error in license manager: $_"
        throw
    }
}

function Apply-LicenseKeyInteractive {
    Clear-Host
    Write-Host "Apply License Key" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter your license key:" -ForegroundColor Yellow
    Write-Host "(Format: Base64 encoded string)" -ForegroundColor DarkGray
    Write-Host ""
    
    $key = Read-Host "License Key"
    
    if ($key) {
        try {
            Set-License -LicenseKey $key
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Write-Host "`nError applying license: $_" -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }
}

function Apply-LicenseFileInteractive {
    Clear-Host
    Write-Host "Apply License File" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Path to license file: " -NoNewline
    $path = Read-Host
    
    if ($path -and (Test-Path $path)) {
        try {
            Set-License -LicenseFile $path
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Write-Host "`nError applying license: $_" -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    } else {
        Write-Host "File not found" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function Show-AvailableFeatures {
    Clear-Host
    Write-Host "Available Features" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    
    $features = Get-AvailableFeatures -IncludeLocked
    
    Write-Host "`nFeatures by Tier:" -ForegroundColor Yellow
    Write-Host ""
    
    # Group by tier
    $tiers = @('free', 'pro', 'enterprise')
    
    foreach ($tier in $tiers) {
        $tierFeatures = $features | Where-Object { $_.RequiredTier -eq $tier }
        if ($tierFeatures) {
            Write-Host "$($tier.ToUpper()) TIER:" -ForegroundColor Cyan
            foreach ($feature in $tierFeatures) {
                Write-Host "  $($feature.Status) $($feature.DisplayName)" -ForegroundColor White
                Write-Host "     Modules: $($feature.Modules -join ', ')" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
    
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Generate-TestLicenseInteractive {
    Clear-Host
    Write-Host "Generate Test License" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "WARNING: For development/testing only!" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Select tier:" -ForegroundColor White
    Write-Host "1. Free" -ForegroundColor White
    Write-Host "2. Professional" -ForegroundColor White
    Write-Host "3. Enterprise" -ForegroundColor White
    Write-Host ""
    
    $tierChoice = Read-Host "Choice (1-3)"
    $tier = switch ($tierChoice) {
        '2' { 'pro' }
        '3' { 'enterprise' }
        default { 'free' }
    }
    
    Write-Host "Email address: " -NoNewline
    $email = Read-Host
    if (-not $email) { $email = "test@example.com" }
    
    Write-Host "Days until expiry [365]: " -NoNewline
    $days = Read-Host
    if (-not $days) { $days = 365 }
    
    try {
        Write-Host "`nGenerating license..." -ForegroundColor Yellow
        $licenseKey = New-License -Tier $tier -Email $email -Days ([int]$days)
        
        Write-Host "`nLicense key copied to clipboard (if available)" -ForegroundColor Green
        try {
            $licenseKey | Set-Clipboard -ErrorAction SilentlyContinue
        } catch {
            # Clipboard might not be available
        }
        
        Write-Host "`nApply this license now? (Y/N): " -NoNewline
        if ((Read-Host) -match '^[Yy]') {
            Set-License -LicenseKey $licenseKey
        }
        
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
    } catch {
        Write-Host "`nError generating license: $_" -ForegroundColor Red
        Start-Sleep -Seconds 3
    }
}

function Show-UpgradeInformation {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Upgrade to Pro or Enterprise         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "PROFESSIONAL TIER" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "✓ Infrastructure Automation (OpenTofu/Terraform)" -ForegroundColor White
    Write-Host "✓ AI Tools Integration (Claude, Gemini)" -ForegroundColor White
    Write-Host "✓ Advanced Orchestration Engine" -ForegroundColor White
    Write-Host "✓ Cloud Provider Integration" -ForegroundColor White
    Write-Host "✓ Priority Support" -ForegroundColor White
    Write-Host ""
    
    Write-Host "ENTERPRISE TIER" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "✓ Everything in Professional" -ForegroundColor White
    Write-Host "✓ Secure Credentials Management" -ForegroundColor White
    Write-Host "✓ Advanced System Monitoring" -ForegroundColor White
    Write-Host "✓ Remote Connection Management" -ForegroundColor White
    Write-Host "✓ REST API Server" -ForegroundColor White
    Write-Host "✓ Enterprise Support SLA" -ForegroundColor White
    Write-Host ""
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "For licensing options, visit:" -ForegroundColor Yellow
    Write-Host "https://github.com/wizzense/AitherZero" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Contact: license@aitherzero.com" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}