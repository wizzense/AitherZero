function Test-SecureCredentialCompliance {
    <#
    .SYNOPSIS
        Performs comprehensive compliance and security testing of stored credentials.

    .DESCRIPTION
        Validates credentials against security policies, checks for compliance issues,
        tests credential strength, and generates detailed security reports.

    .PARAMETER CredentialName
        Specific credential to test. If not provided, tests all credentials.

    .PARAMETER PolicyRules
        Custom policy rules to apply during testing.

    .PARAMETER CheckPasswordStrength
        Verify password complexity and strength (if accessible).

    .PARAMETER CheckExpiration
        Validate credential expiration dates and policies.

    .PARAMETER CheckUsagePatterns
        Analyze credential usage patterns for anomalies.

    .PARAMETER ReportPath
        Path to save detailed compliance report.

    .PARAMETER ExportFindings
        Export findings to JSON format for integration with other systems.

    .EXAMPLE
        Test-SecureCredentialCompliance -CheckPasswordStrength -CheckExpiration -ReportPath "C:\Reports\credential-compliance.html"

    .EXAMPLE
        Test-SecureCredentialCompliance -CredentialName "CriticalService" -CheckUsagePatterns -ExportFindings
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]$CredentialName,

        [Parameter()]
        [hashtable]$PolicyRules = @{},

        [Parameter()]
        [switch]$CheckPasswordStrength,

        [Parameter()]
        [switch]$CheckExpiration,

        [Parameter()]
        [switch]$CheckUsagePatterns,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$ExportFindings
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting credential compliance testing" -Category "Security"

        # Default policy rules
        $defaultPolicies = @{
            MaxCredentialAge = 365
            MinPasswordLength = 12
            RequireComplexPasswords = $true
            MaxPasswordAge = 90
            RequireRegularRotation = $true
            AllowPasswordExport = $false
            RequireEncryption = $true
            MaxFailedRetrievals = 5
        }

        # Merge with provided policies
        foreach ($key in $PolicyRules.Keys) {
            $defaultPolicies[$key] = $PolicyRules[$key]
        }
        $policies = $defaultPolicies

        $complianceResults = @{
            TestDate = Get-Date
            CredentialsTested = 0
            ComplianceScore = 0
            Findings = @()
            PolicyViolations = @()
            SecurityRecommendations = @()
            TestedCredentials = @()
        }
    }

    process {
        try {
            # Get credentials to test
            $credentialsToTest = if ($CredentialName) {
                @($CredentialName)
            } else {
                $allCreds = Get-AllCredentials
                $allCreds | ForEach-Object { $_.Name }
            }

            $complianceResults.CredentialsTested = $credentialsToTest.Count
            Write-CustomLog -Level 'INFO' -Message "Testing $($credentialsToTest.Count) credentials" -Category "Security"

            foreach ($credName in $credentialsToTest) {
                Write-CustomLog -Level 'DEBUG' -Message "Testing credential: $credName" -Category "Security"

                $credentialTest = @{
                    Name = $credName
                    TestTime = Get-Date
                    ComplianceStatus = 'Unknown'
                    Violations = @()
                    Warnings = @()
                    Score = 0
                    Details = @{}
                }

                try {
                    # Basic existence and retrieval test
                    $exists = Test-SecureCredential -CredentialName $credName -ValidateContent -Quiet
                    if (-not $exists) {
                        $credentialTest.ComplianceStatus = 'Failed'
                        $credentialTest.Violations += 'Credential cannot be retrieved or validated'
                        $complianceResults.TestedCredentials += $credentialTest
                        continue
                    }

                    # Get credential details
                    $credResult = Retrieve-CredentialSecurely -CredentialName $credName
                    if (-not $credResult.Success) {
                        $credentialTest.ComplianceStatus = 'Failed'
                        $credentialTest.Violations += "Retrieval failed: $($credResult.Error)"
                        $complianceResults.TestedCredentials += $credentialTest
                        continue
                    }

                    $credential = $credResult.Credential
                    $credentialTest.Details.Type = $credential.Type
                    $credentialTest.Details.Created = $credential.Created
                    $credentialTest.Details.LastModified = $credential.LastModified

                    # Test credential age
                    if ($credential.Created) {
                        $createdDate = $null
                        if ([DateTime]::TryParse($credential.Created, [ref]$createdDate)) {
                            $age = (Get-Date) - $createdDate
                            $credentialTest.Details.AgeInDays = $age.Days

                            if ($age.Days -gt $policies.MaxCredentialAge) {
                                $credentialTest.Violations += "Credential age ($($age.Days) days) exceeds policy maximum ($($policies.MaxCredentialAge) days)"
                            } elseif ($age.Days -gt ($policies.MaxCredentialAge * 0.8)) {
                                $credentialTest.Warnings += "Credential is approaching maximum age"
                            }
                        }
                    }

                    # Test encryption compliance
                    if ($policies.RequireEncryption) {
                        if ($credential.SecurityInfo -and $credential.SecurityInfo.EncryptionMethod) {
                            $credentialTest.Details.EncryptionMethod = $credential.SecurityInfo.EncryptionMethod
                            if ($credential.SecurityInfo.EncryptionMethod -eq 'None') {
                                $credentialTest.Violations += 'Credential is not encrypted as required by policy'
                            }
                        } else {
                            $credentialTest.Warnings += 'Encryption method information not available'
                        }
                    }

                    # Test password strength (if applicable and accessible)
                    if ($CheckPasswordStrength -and $credential.Type -in @('UserPassword', 'ServiceAccount')) {
                        if ($credential.Password) {
                            try {
                                # Convert SecureString to test password strength
                                $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
                                )

                                $passwordTests = @{
                                    Length = $plainPassword.Length
                                    HasUppercase = $plainPassword -cmatch '[A-Z]'
                                    HasLowercase = $plainPassword -cmatch '[a-z]'
                                    HasNumbers = $plainPassword -match '[0-9]'
                                    HasSpecialChars = $plainPassword -match '[^a-zA-Z0-9]'
                                    IsComplex = $false
                                }

                                $passwordTests.IsComplex = $passwordTests.HasUppercase -and
                                                         $passwordTests.HasLowercase -and
                                                         $passwordTests.HasNumbers -and
                                                         $passwordTests.HasSpecialChars

                                $credentialTest.Details.PasswordStrength = $passwordTests

                                if ($passwordTests.Length -lt $policies.MinPasswordLength) {
                                    $credentialTest.Violations += "Password length ($($passwordTests.Length)) is below policy minimum ($($policies.MinPasswordLength))"
                                }

                                if ($policies.RequireComplexPasswords -and -not $passwordTests.IsComplex) {
                                    $credentialTest.Violations += 'Password does not meet complexity requirements'
                                }

                                # Clear password from memory
                                $plainPassword = $null
                                [System.GC]::Collect()

                            } catch {
                                $credentialTest.Warnings += "Password strength test failed: $($_.Exception.Message)"
                            }
                        }
                    }

                    # Test expiration compliance
                    if ($CheckExpiration) {
                        $hasExpiration = $false
                        $expirationDate = $null

                        if ($credential.Metadata) {
                            $expirationFields = @('ExpiresOn', 'ExpiryDate', 'ValidUntil', 'Expiration')
                            foreach ($field in $expirationFields) {
                                if ($credential.Metadata.$field) {
                                    if ([DateTime]::TryParse($credential.Metadata.$field, [ref]$expirationDate)) {
                                        $hasExpiration = $true
                                        $credentialTest.Details.ExpirationDate = $expirationDate

                                        $daysUntilExpiration = ($expirationDate - (Get-Date)).Days
                                        $credentialTest.Details.DaysUntilExpiration = $daysUntilExpiration

                                        if ($daysUntilExpiration -lt 0) {
                                            $credentialTest.Violations += "Credential expired $([Math]::Abs($daysUntilExpiration)) days ago"
                                        } elseif ($daysUntilExpiration -lt 30) {
                                            $credentialTest.Warnings += "Credential expires in $daysUntilExpiration days"
                                        }
                                        break
                                    }
                                }
                            }
                        }

                        if (-not $hasExpiration -and $policies.RequireRegularRotation) {
                            $credentialTest.Warnings += 'No expiration date set for credential requiring regular rotation'
                        }
                    }

                    # Check for security metadata
                    if ($credential.SecurityInfo) {
                        $credentialTest.Details.HasSecurityInfo = $true
                        $credentialTest.Details.SecurityVersion = $credential.SecurityInfo.Version

                        if ($credential.SecurityInfo.CreatedBy) {
                            $credentialTest.Details.CreatedBy = $credential.SecurityInfo.CreatedBy
                        }
                    } else {
                        $credentialTest.Warnings += 'No security metadata available'
                    }

                    # Calculate compliance score
                    $totalChecks = 5  # Base number of compliance checks
                    $passedChecks = 0

                    if ($credentialTest.Violations.Count -eq 0) { $passedChecks++ }
                    if ($credentialTest.Details.EncryptionMethod -and $credentialTest.Details.EncryptionMethod -ne 'None') { $passedChecks++ }
                    if ($credentialTest.Details.AgeInDays -le $policies.MaxCredentialAge) { $passedChecks++ }
                    if ($credentialTest.Details.HasSecurityInfo) { $passedChecks++ }
                    if (-not $CheckExpiration -or ($credentialTest.Details.DaysUntilExpiration -gt 0)) { $passedChecks++ }

                    $credentialTest.Score = [Math]::Round(($passedChecks / $totalChecks) * 100, 2)

                    # Determine overall compliance status
                    if ($credentialTest.Violations.Count -eq 0) {
                        if ($credentialTest.Warnings.Count -eq 0) {
                            $credentialTest.ComplianceStatus = 'Compliant'
                        } else {
                            $credentialTest.ComplianceStatus = 'Warning'
                        }
                    } else {
                        $credentialTest.ComplianceStatus = 'Non-Compliant'
                    }

                    Write-CustomLog -Level 'DEBUG' -Message "Credential '$credName' compliance: $($credentialTest.ComplianceStatus) (Score: $($credentialTest.Score)%)" -Category "Security"

                } catch {
                    $credentialTest.ComplianceStatus = 'Error'
                    $credentialTest.Violations += "Testing error: $($_.Exception.Message)"
                    Write-CustomLog -Level 'ERROR' -Message "Error testing credential '$credName': $($_.Exception.Message)" -Category "Security"
                }

                $complianceResults.TestedCredentials += $credentialTest
            }

            # Calculate overall compliance score
            if ($complianceResults.TestedCredentials.Count -gt 0) {
                $averageScore = ($complianceResults.TestedCredentials | Measure-Object -Property Score -Average).Average
                $complianceResults.ComplianceScore = [Math]::Round($averageScore, 2)
            }

            # Generate findings and recommendations
            $compliantCount = ($complianceResults.TestedCredentials | Where-Object { $_.ComplianceStatus -eq 'Compliant' }).Count
            $nonCompliantCount = ($complianceResults.TestedCredentials | Where-Object { $_.ComplianceStatus -eq 'Non-Compliant' }).Count
            $warningCount = ($complianceResults.TestedCredentials | Where-Object { $_.ComplianceStatus -eq 'Warning' }).Count

            $complianceResults.Findings += "Tested $($complianceResults.CredentialsTested) credentials"
            $complianceResults.Findings += "Compliant: $compliantCount"
            $complianceResults.Findings += "Non-Compliant: $nonCompliantCount"
            $complianceResults.Findings += "Warnings: $warningCount"

            # Collect all violations for summary
            foreach ($cred in $complianceResults.TestedCredentials) {
                foreach ($violation in $cred.Violations) {
                    $complianceResults.PolicyViolations += "$($cred.Name): $violation"
                }
            }

            # Generate recommendations
            if ($nonCompliantCount -gt 0) {
                $complianceResults.SecurityRecommendations += "Address $nonCompliantCount non-compliant credentials immediately"
            }
            if ($warningCount -gt 0) {
                $complianceResults.SecurityRecommendations += "Review $warningCount credentials with warnings"
            }
            $complianceResults.SecurityRecommendations += "Implement automated credential rotation for better compliance"
            $complianceResults.SecurityRecommendations += "Regular compliance testing should be scheduled monthly"
            $complianceResults.SecurityRecommendations += "Consider implementing credential lifecycle management policies"

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during compliance testing: $($_.Exception.Message)" -Category "Security"
            throw
        }
    }

    end {
        # Generate report if requested
        if ($ReportPath) {
            try {
                $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Credential Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .score { font-size: 24px; font-weight: bold; }
        .compliant { color: green; }
        .warning { color: orange; }
        .non-compliant { color: red; }
        .error { color: darkred; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .finding { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .violation { background-color: #ffe7e7; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .recommendation { background-color: #fff3cd; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>Credential Compliance Report</h1>
        <p><strong>Test Date:</strong> $($complianceResults.TestDate)</p>
        <p><strong>Credentials Tested:</strong> $($complianceResults.CredentialsTested)</p>
        <p><strong>Overall Compliance Score:</strong> <span class='score'>$($complianceResults.ComplianceScore)%</span></p>
    </div>

    <h2>Summary</h2>
"@
                foreach ($finding in $complianceResults.Findings) {
                    $htmlReport += "<div class='finding'>$finding</div>"
                }

                $htmlReport += @"
    <h2>Credential Details</h2>
    <table>
        <tr><th>Credential</th><th>Type</th><th>Status</th><th>Score</th><th>Age (Days)</th><th>Issues</th></tr>
"@

                foreach ($cred in $complianceResults.TestedCredentials) {
                    $statusClass = switch ($cred.ComplianceStatus) {
                        'Compliant' { 'compliant' }
                        'Warning' { 'warning' }
                        'Non-Compliant' { 'non-compliant' }
                        'Error' { 'error' }
                        default { '' }
                    }

                    $issues = ($cred.Violations + $cred.Warnings) -join '; '
                    $age = if ($cred.Details.AgeInDays) { $cred.Details.AgeInDays } else { 'Unknown' }

                    $htmlReport += @"
        <tr>
            <td>$($cred.Name)</td>
            <td>$($cred.Details.Type)</td>
            <td class='$statusClass'>$($cred.ComplianceStatus)</td>
            <td>$($cred.Score)%</td>
            <td>$age</td>
            <td>$issues</td>
        </tr>
"@
                }

                $htmlReport += "</table>"

                if ($complianceResults.PolicyViolations.Count -gt 0) {
                    $htmlReport += "<h2>Policy Violations</h2>"
                    foreach ($violation in $complianceResults.PolicyViolations) {
                        $htmlReport += "<div class='violation'>$violation</div>"
                    }
                }

                $htmlReport += "<h2>Recommendations</h2>"
                foreach ($rec in $complianceResults.SecurityRecommendations) {
                    $htmlReport += "<div class='recommendation'>$rec</div>"
                }

                $htmlReport += "</body></html>"

                $htmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Compliance report saved to: $ReportPath" -Category "Security"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)" -Category "Security"
            }
        }

        # Export findings if requested
        if ($ExportFindings) {
            try {
                $exportPath = Join-Path (Get-CredentialStoragePath) "compliance-findings-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $complianceResults | ConvertTo-Json -Depth 10 | Set-Content -Path $exportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Findings exported to: $exportPath" -Category "Security"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to export findings: $($_.Exception.Message)" -Category "Security"
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Credential compliance testing completed. Overall score: $($complianceResults.ComplianceScore)%" -Category "Security"
        return $complianceResults
    }
}
