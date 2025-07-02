#Requires -Version 7.0
<#
.SYNOPSIS
    Generates non-secret-looking test data for use in tests
.DESCRIPTION
    This module provides functions to generate test data that won't trigger
    secret detection tools like GitGuardian while still being suitable for
    testing security features.
#>

function New-TestGuid {
    <#
    .SYNOPSIS
        Generates a new GUID string for test purposes
    .DESCRIPTION
        Creates a GUID that can be used as test data without looking like a secret
    .EXAMPLE
        $testId = New-TestGuid
    #>
    [CmdletBinding()]
    param()
    
    return [System.Guid]::NewGuid().ToString()
}

function New-TestBase64String {
    <#
    .SYNOPSIS
        Generates a random base64 string for test purposes
    .DESCRIPTION
        Creates a base64-encoded random string that doesn't look like credentials
    .PARAMETER Length
        The length of random bytes to generate before encoding (default: 16)
    .EXAMPLE
        $testData = New-TestBase64String -Length 24
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Length = 16
    )
    
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes)
}

function New-TestHashString {
    <#
    .SYNOPSIS
        Generates a SHA256 hash string for test purposes
    .DESCRIPTION
        Creates a hash that looks like encrypted data but isn't a secret
    .PARAMETER InputString
        The string to hash (default: current timestamp)
    .EXAMPLE
        $testHash = New-TestHashString
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InputString = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
    )
    
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hash = $sha256.ComputeHash($bytes)
    return [BitConverter]::ToString($hash).Replace('-', '').ToLower()
}

function New-TestNumericString {
    <#
    .SYNOPSIS
        Generates a numeric string for test purposes
    .DESCRIPTION
        Creates a string of numbers that doesn't look like a PIN or password
    .PARAMETER Length
        The length of the numeric string (default: 8)
    .EXAMPLE
        $testNumber = New-TestNumericString -Length 12
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Length = 8
    )
    
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += Get-Random -Minimum 0 -Maximum 10
    }
    return $result
}

function New-TestAlphanumericString {
    <#
    .SYNOPSIS
        Generates an alphanumeric string for test purposes
    .DESCRIPTION
        Creates a random string of letters and numbers without special characters
    .PARAMETER Length
        The length of the string (default: 16)
    .EXAMPLE
        $testString = New-TestAlphanumericString -Length 20
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Length = 16
    )
    
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $result
}

function New-TestDataSet {
    <#
    .SYNOPSIS
        Generates a complete set of test data
    .DESCRIPTION
        Creates a hashtable with various types of test data for comprehensive testing
    .EXAMPLE
        $testData = New-TestDataSet
    #>
    [CmdletBinding()]
    param()
    
    return @{
        TestId = New-TestGuid
        TestKey = New-TestBase64String -Length 32
        TestHash = New-TestHashString
        TestCode = New-TestNumericString -Length 6
        TestToken = New-TestAlphanumericString -Length 24
        TestIdentifier = "TEST-$(New-TestNumericString -Length 4)"
        TestTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'New-TestGuid',
    'New-TestBase64String',
    'New-TestHashString',
    'New-TestNumericString',
    'New-TestAlphanumericString',
    'New-TestDataSet'
)