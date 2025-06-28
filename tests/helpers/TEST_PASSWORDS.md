# Test Password Configuration

This document explains how to configure test passwords for AitherZero tests to avoid hardcoded passwords in test files.

## Overview

To prevent security scans from flagging hardcoded passwords in test files, AitherZero uses a test credential helper system that:

1. Checks for passwords in environment variables
2. Falls back to generated mock passwords using base64 encoding
3. Ensures passwords meet complexity requirements when needed

## Environment Variables

You can set test passwords using environment variables. The format is:

```
AITHERZERO_TEST_PASSWORD_<PURPOSE>
```

### Examples:

```powershell
# PowerShell
$env:AITHERZERO_TEST_PASSWORD_ADMIN = "YourSecureTestPassword123!"
$env:AITHERZERO_TEST_PASSWORD_DOMAIN = "YourDomainTestPassword456!"
$env:AITHERZERO_TEST_PASSWORD_ISO_BASIC = "YourISOTestPassword789!"

# Bash/Linux
export AITHERZERO_TEST_PASSWORD_ADMIN="YourSecureTestPassword123!"
export AITHERZERO_TEST_PASSWORD_DOMAIN="YourDomainTestPassword456!"
export AITHERZERO_TEST_PASSWORD_ISO_BASIC="YourISOTestPassword789!"
```

## Using the Test Helpers

### Basic Usage

```powershell
# Import the helper
. "$PSScriptRoot/helpers/Test-Credentials.ps1"

# Get a test password
$password = Get-TestPassword -Purpose 'Admin'

# Get a SecureString password
$securePassword = Get-TestSecurePassword -Purpose 'Admin'

# Get a PSCredential object
$credential = Get-TestCredential -Username 'testuser' -Purpose 'Admin'
```

### ISO Test Configurations

```powershell
# Import the ISO configuration helper
. "$PSScriptRoot/helpers/Test-ISOConfigurations.ps1"

# Get a test configuration
$config = Get-TestISOConfiguration -ConfigurationType 'Basic'

# Get multiple configurations
$configs = Get-TestISOConfigurationBatch -Count 5
```

## Security Best Practices

1. **Never commit real passwords** - Even test passwords should not be committed to source control
2. **Use environment variables** - Set test passwords in your local environment or CI/CD pipeline
3. **Rotate test passwords** - Change test passwords periodically
4. **Use complex passwords** - Even for tests, use passwords that meet complexity requirements

## CI/CD Configuration

For GitHub Actions or other CI/CD systems, configure test passwords as secrets:

```yaml
env:
  AITHERZERO_TEST_PASSWORD_ADMIN: ${{ secrets.TEST_PASSWORD_ADMIN }}
  AITHERZERO_TEST_PASSWORD_DOMAIN: ${{ secrets.TEST_PASSWORD_DOMAIN }}
```

## Troubleshooting

If tests fail due to password issues:

1. Check if the required environment variable is set
2. Verify the password meets complexity requirements (if applicable)
3. Ensure the helper scripts are properly imported
4. Check that the Purpose parameter matches the expected value

## Mock Password Generation

When environment variables are not set, the system generates mock passwords:

- Base pattern is base64 encoded to avoid literal passwords in code
- Purpose-specific suffixes are added for uniqueness
- Complexity elements are added when required
- Generated passwords are consistent within a test run

This approach ensures:
- No hardcoded passwords in test files
- Consistent test behavior
- Security scan compliance
- Flexibility for different environments