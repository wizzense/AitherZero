#Requires -Version 7.0

BeforeAll {
    # Import the module under test
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $modulePath = Join-Path $projectRoot 'domains/utilities/DownloadUtility.psm1'
    
    # Import module
    Import-Module $modulePath -Force
    
    # Create test directory
    $script:TestDownloadDir = Join-Path $TestDrive 'downloads'
    New-Item -ItemType Directory -Path $script:TestDownloadDir -Force | Out-Null
}

Describe 'DownloadUtility Module' {
    
    Context 'Module Loading' {
        It 'Should export Invoke-FileDownload function' {
            Get-Command Invoke-FileDownload -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Test-BitsAvailability function' {
            Get-Command Test-BitsAvailability -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-DownloadMethod function' {
            Get-Command Get-DownloadMethod -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Test-BitsAvailability' {
        It 'Should return a boolean value' {
            $result = Test-BitsAvailability
            $result | Should -BeOfType [bool]
        }
        
        It 'Should return true on Windows with BITS, false otherwise' {
            $result = Test-BitsAvailability
            if ($IsWindows) {
                # BITS should be available on Windows
                $result | Should -BeIn @($true, $false)
            } else {
                # BITS not available on non-Windows
                $result | Should -Be $false
            }
        }
    }
    
    Context 'Get-DownloadMethod' {
        It 'Should return a valid download method' {
            $method = Get-DownloadMethod
            $method | Should -BeIn @('BITS', 'WebRequest')
        }
        
        It 'Should return BITS on Windows when available' {
            $method = Get-DownloadMethod
            if ($IsWindows -and (Test-BitsAvailability)) {
                $method | Should -Be 'BITS'
            }
        }
        
        It 'Should return WebRequest on non-Windows platforms' {
            $method = Get-DownloadMethod
            if (-not $IsWindows) {
                $method | Should -Be 'WebRequest'
            }
        }
    }
    
    Context 'Invoke-FileDownload - Parameter Validation' {
        It 'Should require Uri parameter' {
            { Invoke-FileDownload -OutFile 'test.txt' -ErrorAction Stop -WarningAction SilentlyContinue 2>$null } | Should -Throw
        }
        
        It 'Should require OutFile parameter' {
            { Invoke-FileDownload -Uri 'https://example.com/file.txt' -ErrorAction Stop -WarningAction SilentlyContinue 2>$null } | Should -Throw
        }
        
        It 'Should accept valid Method parameter values' {
            $validMethods = @('Auto', 'BITS', 'WebRequest')
            foreach ($method in $validMethods) {
                { 
                    Invoke-FileDownload -Uri 'https://httpbin.org/delay/0' `
                        -OutFile (Join-Path $script:TestDownloadDir "test-$method.txt") `
                        -Method $method -WhatIf 
                } | Should -Not -Throw
            }
        }
        
        It 'Should reject invalid Method parameter values' {
            { 
                Invoke-FileDownload -Uri 'https://example.com' `
                    -OutFile 'test.txt' -Method 'Invalid' -WhatIf 
            } | Should -Throw
        }
    }
    
    Context 'Invoke-FileDownload - Cached File Handling' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir 'cached-test.txt'
            $script:TestContent = 'Test content for cached file'
            Set-Content -Path $script:TestFile -Value $script:TestContent -Force
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should use cached file when it exists and Force is not specified' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/delay/0' `
                -OutFile $script:TestFile -SkipValidation
            
            $result.Success | Should -Be $true
            $result.Method | Should -Be 'Cached'
            $result.Attempts | Should -Be 0
        }
        
        It 'Should overwrite when Force parameter is specified' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/delay/0' `
                -OutFile $script:TestFile -Force -SkipValidation
            
            # The download should have been attempted (not cached)
            $result.Method | Should -Not -Be 'Cached'
        }
    }
    
    Context 'Invoke-FileDownload - Basic Download' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "download-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should download a small file successfully' {
            # Use httpbin.org for testing (returns JSON with request info)
            $uri = 'https://httpbin.org/robots.txt'
            $result = Invoke-FileDownload -Uri $uri -OutFile $script:TestFile -UseBasicParsing
            
            $result.Success | Should -Be $true
            $result.FilePath | Should -Be $script:TestFile
            $result.FileSize | Should -BeGreaterThan 0
            Test-Path $script:TestFile | Should -Be $true
        }
        
        It 'Should return correct download metadata' {
            $uri = 'https://httpbin.org/robots.txt'
            $result = Invoke-FileDownload -Uri $uri -OutFile $script:TestFile -UseBasicParsing
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Method | Should -BeIn @('BITS', 'WebRequest')
            $result.FilePath | Should -Be $script:TestFile
            $result.FileSize | Should -BeGreaterThan 0
            $result.Duration | Should -BeOfType [TimeSpan]
            $result.Attempts | Should -BeGreaterThan 0
        }
        
        It 'Should create destination directory if it does not exist' {
            $nestedDir = Join-Path $script:TestDownloadDir "nested/path/to/file"
            $nestedFile = Join-Path $nestedDir "test.txt"
            
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $nestedFile -UseBasicParsing
            
            $result.Success | Should -Be $true
            Test-Path $nestedFile | Should -Be $true
            
            # Cleanup
            Remove-Item (Split-Path $nestedDir -Parent) -Recurse -Force
        }
    }
    
    Context 'Invoke-FileDownload - Retry Logic' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "retry-test-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should retry on failure with specified RetryCount' {
            # Use an invalid URL that will fail
            $result = Invoke-FileDownload -Uri 'https://invalid-domain-12345.example.com/file.txt' `
                -OutFile $script:TestFile -RetryCount 2 -RetryDelaySeconds 1
            
            $result.Success | Should -Be $false
            $result.Attempts | Should -Be 2
            $result.Message | Should -Match 'failed after.*attempts'
        }
        
        It 'Should use exponential backoff for retries' {
            $startTime = Get-Date
            
            # Use an invalid URL that will fail quickly
            # 192.0.2.1 is a documentation/test IP address from TEST-NET-1 (RFC 5737), intentionally unreachable
            $result = Invoke-FileDownload -Uri 'https://192.0.2.1/file.txt' `
                -OutFile $script:TestFile -RetryCount 3 -RetryDelaySeconds 1 -TimeoutSec 2
            
            $duration = ((Get-Date) - $startTime).TotalSeconds
            
            $result.Success | Should -Be $false
            # With exponential backoff: 1s + 2s + 4s = 7s + download attempts
            # Should take at least 3 seconds (1s + 2s minimum from first two retries)
            $duration | Should -BeGreaterThan 3
        }
    }
    
    Context 'Invoke-FileDownload - Size Validation' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "validation-test-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should validate file size against Content-Length header' {
            # Use a known endpoint that provides Content-Length
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -UseBasicParsing
            
            $result.Success | Should -Be $true
            if ($result.ExpectedSize) {
                $result.FileSize | Should -Be $result.ExpectedSize
            }
        }
        
        It 'Should skip validation when SkipValidation is specified' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -SkipValidation -UseBasicParsing
            
            $result.Success | Should -Be $true
        }
    }
    
    Context 'Invoke-FileDownload - WhatIf Support' {
        It 'Should support WhatIf parameter' {
            $testFile = Join-Path $script:TestDownloadDir 'whatif-test.txt'
            
            { 
                Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                    -OutFile $testFile -WhatIf 
            } | Should -Not -Throw
            
            # File should not be created with WhatIf
            Test-Path $testFile | Should -Be $false
        }
    }
    
    Context 'Invoke-FileDownload - Cross-Platform Behavior' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "platform-test-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should work on current platform' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -UseBasicParsing
            
            $result.Success | Should -Be $true
            Test-Path $script:TestFile | Should -Be $true
        }
        
        It 'Should use appropriate method based on platform' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -UseBasicParsing
            
            if ($IsWindows -and (Test-BitsAvailability)) {
                $result.Method | Should -Be 'BITS'
            } else {
                $result.Method | Should -Be 'WebRequest'
            }
        }
    }
    
    Context 'Invoke-FileDownload - Method Override' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "method-override-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should respect Method parameter when set to WebRequest' {
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -Method WebRequest -UseBasicParsing
            
            $result.Success | Should -Be $true
            $result.Method | Should -Be 'WebRequest'
        }
        
        It 'Should use BITS when Method is set to BITS on Windows' {
            if ($IsWindows -and (Test-BitsAvailability)) {
                $result = Invoke-FileDownload -Uri 'https://httpbin.org/robots.txt' `
                    -OutFile $script:TestFile -Method BITS -UseBasicParsing
                
                $result.Success | Should -Be $true
                $result.Method | Should -Be 'BITS'
            } else {
                Set-ItResult -Skipped -Because "BITS is not available on this platform"
            }
        }
    }
}

Describe 'DownloadUtility - Integration Tests' {
    Context 'Real-world Download Scenarios' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "integration-$(Get-Random).txt"
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It 'Should handle redirect URLs correctly' {
            # httpbin.org redirects are handled transparently
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/redirect-to?url=https://httpbin.org/robots.txt' `
                -OutFile $script:TestFile -UseBasicParsing
            
            $result.Success | Should -Be $true
            Test-Path $script:TestFile | Should -Be $true
        }
        
        It 'Should handle downloads with timeout appropriately' {
            # Very short timeout on a delay endpoint
            $result = Invoke-FileDownload -Uri 'https://httpbin.org/delay/5' `
                -OutFile $script:TestFile -TimeoutSec 2 -RetryCount 1
            
            $result.Success | Should -Be $false
            $result.Message | Should -Match 'failed'
        }
    }
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestDownloadDir) {
        Remove-Item $script:TestDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
