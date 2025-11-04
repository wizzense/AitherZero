# DownloadUtility Module

Provides optimized file download capabilities with intelligent retry, resume, and validation features.

## Overview

The DownloadUtility module leverages **BITS (Background Intelligent Transfer Service)** on Windows for optimized large file downloads without console progress bar flooding, with automatic fallback to `Invoke-WebRequest` on other platforms.

## Key Features

### 🔄 Intelligent Retry Logic
- Configurable retry count (default: 3 attempts)
- Exponential backoff delay (2s, 4s, 8s, etc.)
- Automatic cleanup of partial/corrupt downloads on failure
- Detailed logging of retry attempts

### 💾 Download Resume & Idempotency
- Automatic detection of existing complete downloads (cached files)
- Content-Length validation for download completeness
- Detection and handling of partial/interrupted downloads
- BITS automatic resume support on Windows
- Idempotent operations - safe to run repeatedly

### 🌍 Cross-Platform Support
- **Windows**: BITS (Background Intelligent Transfer Service) - optimized, no progress bars
- **Linux/macOS**: Invoke-WebRequest fallback with progress suppression
- Automatic method selection based on platform availability
- Manual method override when needed

### ✅ Validation & Safety
- Content-Length header validation before and after download
- File size verification to detect incomplete downloads
- Automatic cleanup of corrupt/partial files
- Optional validation skip for servers without Content-Length

## Functions

### `Invoke-FileDownload`

Downloads a file using the optimal method for the current platform.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Uri` | string | Required | URL of the file to download |
| `OutFile` | string | Required | Local path where file should be saved |
| `UseBasicParsing` | switch | - | Use basic parsing for web requests |
| `TimeoutSec` | int | 300 | Timeout in seconds for download operation |
| `RetryCount` | int | 3 | Number of retry attempts on failure |
| `RetryDelaySeconds` | int | 2 | Initial delay between retries (exponential backoff) |
| `Force` | switch | - | Force overwrite of existing file |
| `SkipValidation` | switch | - | Skip Content-Length validation |
| `Method` | string | 'Auto' | Force specific method: 'Auto', 'BITS', or 'WebRequest' |

#### Returns

PSCustomObject with the following properties:
- `Success` (bool): Indicates if download succeeded
- `Method` (string): Download method used ('BITS', 'WebRequest', or 'Cached')
- `FilePath` (string): Path to downloaded file
- `FileSize` (long): Size of downloaded file in bytes
- `ExpectedSize` (long): Expected size from Content-Length header
- `Duration` (TimeSpan): Time taken for download
- `Attempts` (int): Number of attempts made
- `Resumed` (bool): Whether download was resumed from partial file
- `Message` (string): Status or error message

#### Examples

```powershell
# Basic usage
$result = Invoke-FileDownload -Uri 'https://example.com/file.zip' -OutFile 'C:\Temp\file.zip'
if ($result.Success) {
    Write-Host "Downloaded $($result.FileSize) bytes via $($result.Method)"
}

# With custom retry settings
$result = Invoke-FileDownload -Uri $url -OutFile $path `
    -RetryCount 5 `
    -RetryDelaySeconds 3 `
    -UseBasicParsing

# Force re-download (ignore cached)
$result = Invoke-FileDownload -Uri $url -OutFile $path -Force

# Force specific download method
$result = Invoke-FileDownload -Uri $url -OutFile $path -Method BITS
```

### `Test-BitsAvailability`

Tests if BITS is available on the current system.

#### Returns

Boolean indicating BITS availability (Windows only).

#### Example

```powershell
if (Test-BitsAvailability) {
    Write-Host "BITS is available for optimized downloads"
}
```

### `Get-DownloadMethod`

Gets the recommended download method for the current platform.

#### Returns

String: 'BITS' on Windows with BITS available, 'WebRequest' otherwise.

#### Example

```powershell
$method = Get-DownloadMethod
Write-Host "Recommended download method: $method"
```

## Usage Patterns

### Pattern 1: Replace Invoke-WebRequest

**Before:**
```powershell
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
$ProgressPreference = 'Continue'
```

**After:**
```powershell
$result = Invoke-FileDownload -Uri $url -OutFile $file -UseBasicParsing
if (-not $result.Success) {
    throw "Download failed: $($result.Message)"
}
```

### Pattern 2: Large File Downloads with Retry

```powershell
# Download large installer with retry logic
$result = Invoke-FileDownload `
    -Uri 'https://example.com/installer.exe' `
    -OutFile 'C:\Temp\installer.exe' `
    -RetryCount 5 `
    -RetryDelaySeconds 3 `
    -UseBasicParsing

if ($result.Success) {
    Write-Host "Downloaded $($result.FileSize) bytes in $($result.Duration.TotalSeconds)s"
    Write-Host "Method used: $($result.Method)"
    Write-Host "Attempts: $($result.Attempts)"
} else {
    Write-Error "Download failed after $($result.Attempts) attempts"
    Write-Error $result.Message
}
```

### Pattern 3: Idempotent Downloads

```powershell
# Safe to run multiple times - will use cached file if already downloaded
$result = Invoke-FileDownload -Uri $url -OutFile $path -UseBasicParsing

if ($result.Method -eq 'Cached') {
    Write-Host "Using existing file (already downloaded)"
} else {
    Write-Host "Downloaded new file via $($result.Method)"
}
```

### Pattern 4: Force Re-download

```powershell
# Force re-download even if file exists
$result = Invoke-FileDownload -Uri $url -OutFile $path -Force -UseBasicParsing
```

## Retry and Resume Logic

### Exponential Backoff

The module uses exponential backoff for retries:
- Attempt 1: Immediate
- Attempt 2: Wait 2s (RetryDelaySeconds * 2^0)
- Attempt 3: Wait 4s (RetryDelaySeconds * 2^1)
- Attempt 4: Wait 8s (RetryDelaySeconds * 2^2)
- And so on...

### Intelligent Resume

On interrupted downloads:

1. **Check existing file**: If file exists, check its size
2. **Validate with remote**: Compare with Content-Length header
3. **Resume or restart**:
   - If sizes match: Use cached file (complete)
   - If partial: Resume with BITS (Windows) or restart with WebRequest
   - If corrupt: Delete and restart

### Validation

Content-Length validation ensures download completeness:
- **Before download**: HEAD request to get expected size
- **After download**: Compare actual file size with expected
- **On mismatch**: Treat as failed download and retry

## Platform-Specific Behavior

### Windows with BITS

- Uses Background Intelligent Transfer Service
- Optimized for large downloads
- No console progress bar flooding
- Automatic resume capability
- Network-friendly (throttles on congestion)

### Linux/macOS

- Uses Invoke-WebRequest
- Progress bar suppressed (`$ProgressPreference = 'SilentlyContinue'`)
- No automatic resume (partial files deleted on failure)
- Still benefits from retry logic and validation

## Error Handling

The module handles various error scenarios:

| Scenario | Behavior |
|----------|----------|
| Network failure | Retry with exponential backoff |
| Partial download | Resume (BITS) or restart (WebRequest) |
| Timeout | Retry up to configured count |
| Invalid URL | Fail after retries exhausted |
| Disk full | Fail immediately |
| Permission denied | Fail immediately |

## Integration with AitherZero

The DownloadUtility module is automatically loaded by AitherZero.psm1:

```powershell
# In AitherZero.psm1
$modulesToLoad = @(
    './domains/utilities/Logging.psm1',
    './domains/utilities/DownloadUtility.psm1',  # Loaded early
    # ...
)
```

Functions are exported in AitherZero.psd1:

```powershell
FunctionsToExport = @(
    'Invoke-FileDownload',
    'Test-BitsAvailability',
    'Get-DownloadMethod',
    # ...
)
```

## Testing

Run the test suite:

```powershell
Invoke-Pester -Path './tests/domains/utilities/DownloadUtility.Tests.ps1' -Output Detailed
```

## Migration Guide

See [DOWNLOAD-UTILITY-MIGRATION.md](../../docs/DOWNLOAD-UTILITY-MIGRATION.md) for:
- Complete migration examples
- Before/after comparisons
- Priority order for script updates
- Testing checklist

## Performance Benefits

| Metric | Invoke-WebRequest | Invoke-FileDownload |
|--------|-------------------|---------------------|
| **Console flooding** | Yes (progress bars) | No (suppressed) |
| **Retry logic** | Manual | Automatic |
| **Resume capability** | No | Yes (BITS on Windows) |
| **Validation** | Manual | Automatic |
| **Idempotent** | No | Yes |
| **Network-friendly** | No | Yes (BITS throttles) |

## Logging

The module integrates with AitherZero's logging system:

```
[2025-11-04 03:42:01] [INFO] Starting file download from: https://example.com/file.zip
[2025-11-04 03:42:01] [DEBUG] Checking remote file size...
[2025-11-04 03:42:01] [DEBUG] Expected file size: 1048576 bytes
[2025-11-04 03:42:01] [INFO] Downloading via BITS (attempt 1 of 3)...
[2025-11-04 03:42:05] [INFO] File downloaded successfully: 1048576 bytes in 4.23 seconds
```

## Best Practices

1. **Always check result.Success**:
   ```powershell
   if (-not $result.Success) {
       throw "Download failed: $($result.Message)"
   }
   ```

2. **Use appropriate retry counts**:
   - Local network: `RetryCount 2`
   - Internet: `RetryCount 3-5`
   - Critical downloads: `RetryCount 5-10`

3. **Consider timeout for large files**:
   ```powershell
   $result = Invoke-FileDownload -Uri $url -OutFile $path -TimeoutSec 600
   ```

4. **Use -Force judiciously**:
   - Only when you need to force re-download
   - Most times, let caching work

5. **Log download metrics**:
   ```powershell
   Write-Log "Downloaded $($result.FileSize) bytes via $($result.Method) in $($result.Duration.TotalSeconds)s"
   ```

## See Also

- [Migration Guide](../../docs/DOWNLOAD-UTILITY-MIGRATION.md)
- [AitherZero Documentation](../../README.md)
- [Logging Module](./Logging.psm1)
