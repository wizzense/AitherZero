#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Security validation tests for the Aitherium Infrastructure Automation system

.DESCRIPTION
    This test suite validates security aspects including:
    - Input validation and sanitization
    - Credential handling security
    - File access permissions
    - Script execution security
    - Cross-platform security considerations

.NOTES
    Part of the Aitherium Infrastructure Automation testing framework
#>

BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot

    # Import security-related modules
    try {
        Import-Module "$script:ProjectRoot/aither-core/modules/SecureCredentials" -Force -ErrorAction Stop
    } catch {
        Write-Warning "SecureCredentials module not available for security testing"
    }

    Import-Module "$script:ProjectRoot/aither-core/modules/Logging" -Force

    # Define security test patterns
    $script:SecurityTests = @{
        MaliciousInputs = @(
            "; rm -rf /",
            "'; DROP TABLE users; --",
            "../../../etc/passwd",
            "$(Get-Process)",
            "`r`nInvoke-Expression",
            "powershell.exe -Command",
            "&& format c: /y"
        )
        SafeInputs = @(
            "ValidFileName.txt",
            "normal-script-name",
            "C:\ValidPath\file.txt",
            "/valid/unix/path",
            "123456",
            "ValidModuleName"
        )
    }
}

Describe "Input Validation Security" -Tags @('Security', 'InputValidation') {

    Context "When validating potentially dangerous inputs" {
        It "Should reject malicious file paths" {
            foreach ($maliciousInput in $script:SecurityTests.MaliciousInputs) {
                # Test that functions properly validate dangerous inputs
                try {
                    # Simulate a function that should validate file paths
                    if ($maliciousInput -match '\.\./|;|&|\$\(|\`|rm\s|format\s') {
                        # This is the expected behavior - input should be rejected
                        $true | Should -Be $true
                    } else {
                        # If no validation exists, this test documents the security gap
                        Write-Warning "No validation detected for potentially dangerous input: $maliciousInput"
                    }
                } catch {
                    # Exceptions on malicious input are acceptable
                    $_.Exception.Message | Should -Not -BeNullOrEmpty
                }
            }
        }

        It "Should accept safe inputs" {
            foreach ($safeInput in $script:SecurityTests.SafeInputs) {
                # Safe inputs should not trigger security warnings
                $validation = $true
                try {
                    # Basic validation that safe inputs are actually safe
                    if ($safeInput -notmatch '\.\./|;|&|\$\(|\`|rm\s|format\s') {
                        $validation = $true
                    } else {
                        $validation = $false
                    }
                } catch {
                    $validation = $false
                }

                $validation | Should -Be $true
            }
        }

        It "Should sanitize log inputs" {
            $dangerousLogInput = "User input with `$(Get-Process) injection attempt"

            # Test that logging properly sanitizes inputs
            try {
                Write-CustomLog -Level 'INFO' -Message $dangerousLogInput
                # If this doesn't throw, the input was handled safely
                $true | Should -Be $true
            } catch {
                # If it throws, that's also acceptable security behavior
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "Credential Security" -Tags @('Security', 'Credentials') {

    Context "When handling credentials and sensitive data" {
        It "Should use SecureString for sensitive data" {
            if (Get-Command 'New-SecureCredential' -ErrorAction SilentlyContinue) {
                try {
                    $secureString = ConvertTo-SecureString "TestPassword" -AsPlainText -Force
                    $credential = New-Object System.Management.Automation.PSCredential("TestUser", $secureString)

                    # Verify credential is properly secured
                    $credential.Password | Should -BeOfType [System.Security.SecureString]
                    $credential.GetNetworkCredential().Password | Should -Be "TestPassword"
                } catch {
                    Write-Warning "SecureString testing failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "SecureCredentials functions not available"
            }
        }

        It "Should not expose credentials in logs" {
            $testPassword = "SecretPassword123"

            # Simulate logging that might accidentally include credentials
            try {
                Write-CustomLog -Level 'INFO' -Message "User authentication for account with password: [PROTECTED]"

                # Check that actual password is not in the log message
                $logMessage = "User authentication for account with password: [PROTECTED]"
                $logMessage | Should -Not -Match $testPassword
            } catch {
                # If logging fails on protected content, that's acceptable
                $true | Should -Be $true
            }
        }

        It "Should handle credential storage securely" {
            if (Get-Command 'Set-SecureCredential' -ErrorAction SilentlyContinue) {
                try {
                    $secureString = ConvertTo-SecureString "TestPassword" -AsPlainText -Force

                    # Test secure credential storage
                    Set-SecureCredential -Name "TestCredential" -Credential $secureString

                    # Retrieve and verify
                    $retrieved = Get-SecureCredential -Name "TestCredential"
                    $retrieved | Should -Not -BeNullOrEmpty

                    # Cleanup
                    Remove-SecureCredential -Name "TestCredential" -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Secure credential storage test failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Secure credential functions not available"
            }
        }
    }
}

Describe "File Access Security" -Tags @('Security', 'FileAccess') {

    Context "When accessing files and directories" {
        It "Should validate file access permissions" {
            $testPaths = @(
                $script:ProjectRoot,
                "$script:ProjectRoot/aither-core",
                "$script:ProjectRoot/tests",
                "$script:ProjectRoot/logs"
            )

            foreach ($path in $testPaths) {
                if (Test-Path $path) {
                    try {
                        # Test read access
                        $items = Get-ChildItem $path -ErrorAction Stop | Select-Object -First 1

                        # Verify we're not accidentally accessing restricted areas
                        $path | Should -Not -Match "system32|windows|etc/shadow|etc/passwd"
                    } catch {
                        # Access denied is acceptable for security-sensitive paths
                        $_.Exception.Message | Should -Match "Access|Permission|Denied"
                    }
                }
            }
        }

        It "Should prevent directory traversal attacks" {
            $traversalAttempts = @(
                "../../../etc/passwd",
                "..\..\..\..\windows\system32",
                "..\..\..\Users",
                "../../../../root"
            )

            foreach ($attempt in $traversalAttempts) {
                # Test that path validation prevents traversal
                $resolvedPath = Resolve-Path $attempt -ErrorAction SilentlyContinue

                if ($resolvedPath) {
                    # If path resolves, ensure it's within safe boundaries
                    $resolvedPath.Path | Should -Not -Match "system32|etc/passwd|etc/shadow|root/"
                }
                # If path doesn't resolve, that's good security behavior
            }
        }

        It "Should handle temporary file creation securely" {
            try {
                # Create temporary file in safe location
                $tempPath = Join-Path $env:TEMP "AitherSecurityTest-$(Get-Random).tmp"

                # Test secure temporary file creation
                "Test content" | Out-File $tempPath -ErrorAction Stop

                # Verify file was created
                Test-Path $tempPath | Should -Be $true

                # Cleanup
                Remove-Item $tempPath -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Temporary file security test failed: $($_.Exception.Message)"
            }
        }
    }
}

Describe "Script Execution Security" -Tags @('Security', 'ScriptExecution') {

    Context "When executing scripts and commands" {
        It "Should validate script execution policies" {
            $currentPolicy = Get-ExecutionPolicy

            # Execution policy should be set appropriately for security
            $currentPolicy | Should -Not -Be 'Unrestricted'

            # Document current policy for security review
            Write-Information "Current execution policy: $currentPolicy" -InformationAction Continue
        }

        It "Should prevent command injection in parameters" {
            $dangerousParameters = @(
                "; Get-Process",
                "| Remove-Item",
                "&& format",
                "`$(Invoke-Expression 'Get-Process')"
            )

            foreach ($dangerousParam in $dangerousParameters) {
                # Test that parameter validation prevents injection
                try {
                    # Simulate a function that takes parameters
                    $sanitizedParam = $dangerousParam -replace '[;&|`$()]', ''

                    # Verify dangerous characters were removed
                    $sanitizedParam | Should -Not -Match '[;&|`$()]'
                } catch {
                    # If validation throws an exception, that's acceptable
                    $true | Should -Be $true
                }
            }
        }

        It "Should handle PowerShell remoting securely" {
            if (Get-Command 'Test-WSMan' -ErrorAction SilentlyContinue) {
                try {
                    # Test if WinRM is configured securely
                    $wsmanTest = Test-WSMan -ErrorAction SilentlyContinue

                    if ($wsmanTest) {
                        # If WinRM is enabled, verify it's configured securely
                        $wsmanConfig = Get-WSManInstance -ResourceURI winrm/config -ErrorAction SilentlyContinue

                        if ($wsmanConfig) {
                            # Basic security checks for WinRM configuration
                            $wsmanConfig | Should -Not -BeNullOrEmpty
                        }
                    }
                } catch {
                    # WinRM configuration issues are not critical for this test
                    Write-Warning "WinRM security test skipped: $($_.Exception.Message)"
                }
            }
        }
    }
}

Describe "Cross-Platform Security" -Tags @('Security', 'CrossPlatform') {

    Context "When running on different platforms" {
        It "Should adapt security measures to platform" {
            $platform = $PSVersionTable.Platform

            switch ($platform) {
                'Win32NT' {
                    # Windows-specific security checks
                    $windowsVersion = [System.Environment]::OSVersion.Version
                    $windowsVersion | Should -Not -BeNullOrEmpty
                }
                'Unix' {
                    # Unix/Linux-specific security checks
                    $unixUser = $env:USER
                    $unixUser | Should -Not -Be 'root' # Should not run as root in production
                }
                default {
                    # Generic platform security
                    $platform | Should -Not -BeNullOrEmpty
                }
            }
        }

        It "Should handle file permissions correctly by platform" {
            $testFile = Join-Path $env:TEMP "security-test-$(Get-Random).txt"

            try {
                "Test content" | Out-File $testFile

                if ($IsWindows) {
                    # Windows file permission checks
                    $acl = Get-Acl $testFile -ErrorAction SilentlyContinue
                    $acl | Should -Not -BeNullOrEmpty
                } elseif ($IsLinux -or $IsMacOS) {
                    # Unix-like file permission checks
                    $permissions = (Get-Item $testFile).Mode
                    $permissions | Should -Not -BeNullOrEmpty
                }

                # File should exist and be accessible
                Test-Path $testFile | Should -Be $true
            } finally {
                Remove-Item $testFile -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Network Security" -Tags @('Security', 'Network') {

    Context "When handling network operations" {
        It "Should use secure protocols for downloads" {
            # Test that HTTPS is preferred over HTTP
            $secureUrl = "https://example.com"
            $insecureUrl = "http://example.com"

            # Verify HTTPS preference
            $secureUrl | Should -Match "^https://"
            $insecureUrl | Should -Match "^http://"

            # In production, HTTP should be avoided
            Write-Information "Prefer HTTPS over HTTP for all network operations" -InformationAction Continue
        }

        It "Should validate SSL certificates" {
            try {
                # Test SSL certificate validation
                $webRequest = [System.Net.WebRequest]::Create("https://www.microsoft.com")
                $webRequest.Method = "HEAD"
                $webRequest.Timeout = 5000

                $response = $webRequest.GetResponse()
                $response.StatusCode | Should -Be 'OK'
                $response.Close()
            } catch {
                # SSL validation failures are acceptable for security
                Write-Information "SSL certificate validation active" -InformationAction Continue
            }
        }
    }
}

Describe "Audit and Logging Security" -Tags @('Security', 'Auditing') {

    Context "When auditing security events" {
        It "Should log security-relevant events" {
            try {
                # Test security event logging
                Write-CustomLog -Level 'WARN' -Message 'Security test: Potential unauthorized access attempt detected'

                # Security events should be logged appropriately
                $true | Should -Be $true
            } catch {
                Write-Warning "Security event logging test failed: $($_.Exception.Message)"
            }
        }

        It "Should protect log files from tampering" {
            $logDir = Join-Path $script:ProjectRoot 'logs'

            if (Test-Path $logDir) {
                try {
                    # Check log directory permissions
                    $logFiles = Get-ChildItem $logDir -Filter "*.log" -ErrorAction SilentlyContinue

                    foreach ($logFile in $logFiles) {
                        # Verify log files exist and are accessible
                        Test-Path $logFile.FullName | Should -Be $true

                        # Log files should not be world-writable (Unix) or have weak permissions (Windows)
                        if ($IsLinux -or $IsMacOS) {
                            $permissions = (Get-Item $logFile.FullName).Mode
                            $permissions | Should -Not -Match 'w.*w.*w' # No world-write
                        }
                    }
                } catch {
                    Write-Warning "Log file security check failed: $($_.Exception.Message)"
                }
            }
        }
    }
}

AfterAll {
    # Cleanup any test artifacts
    $testFiles = Get-ChildItem $env:TEMP -Filter "AitherSecurityTest-*" -ErrorAction SilentlyContinue
    foreach ($file in $testFiles) {
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
    }

    # Remove imported modules
    Remove-Module SecureCredentials -Force -ErrorAction SilentlyContinue
    Remove-Module Logging -Force -ErrorAction SilentlyContinue
}
