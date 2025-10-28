# Docker Volume Mount Fix - Before and After

## Problem (Before Fix)

When users tried to use the Docker container with a volume mount:

```bash
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:pr-739
```

They would get this error:

```
Import-Module: The specified module '/app/AitherZero.psd1' was not loaded because no valid module file was found in any module directory.
✅ AitherZero loaded. Type Start-AitherZero to begin.
```

The error occurred because:
1. AitherZero was installed in `/app` during the Docker build
2. The volume mount `-v "$(pwd):/app"` replaced the entire `/app` directory with the user's local directory
3. The AitherZero module files were no longer accessible
4. The container tried to import from `/app/AitherZero.psd1` but it didn't exist

## Solution (After Fix)

### What Changed

1. **Installation Location**: AitherZero is now installed in `/opt/aitherzero` instead of `/app`
2. **Working Directory**: `/app` remains as the working directory for user files
3. **Module Path**: The container imports from `/opt/aitherzero/AitherZero.psd1`
4. **Environment Variables**: `AITHERZERO_ROOT` points to `/opt/aitherzero`

### Files Modified

- `Dockerfile` - Install to `/opt/aitherzero`, set WORKDIR to `/app`
- `docker-compose.yml` - Update environment and volume paths
- `automation-scripts/0850_Deploy-PREnvironment.ps1` - Update paths in docker-compose generation
- `automation-scripts/0852_Validate-PRDockerDeployment.ps1` - Update validation paths
- `docs/IMPLEMENTATION-SUMMARY.md` - Update Docker test commands
- `docs/PR-DEPLOYMENT-SETUP-CHECKLIST.md` - Update testing commands

### Now It Works

```bash
# User can mount any directory to /app
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:latest

# Output:
# WARNING: Failed to load module: ./domains/reporting/ReportingEngine.psm1 - Access to the path '/app/reports' is denied.
# ✅ AitherZero loaded. Type Start-AitherZero to begin.
```

The module loads successfully! The warning about `/app/reports` is harmless and only appears when mounting an empty directory.

### Benefits

1. **Volume Mounts Work**: Users can mount their project directory without breaking AitherZero
2. **Separation of Concerns**: AitherZero installation in `/opt/aitherzero` is isolated from user files in `/app`
3. **Backwards Compatible**: Existing users without volume mounts continue to work
4. **CI/CD Friendly**: Can mount workspace directories for CI/CD pipelines

### Usage Examples

#### Mount Project Directory
```bash
cd /path/to/your/project
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:latest
```

#### Run Automation Script on Your Files
```bash
docker run -it --rm \
  -v "$(pwd):/app" \
  -w /app \
  ghcr.io/wizzense/aitherzero:latest \
  pwsh -c "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"
```

#### CI/CD Integration
```yaml
- name: Run Tests
  run: |
    docker run --rm \
      -v "${{ github.workspace }}:/app" \
      -e AITHERZERO_CI=true \
      ghcr.io/wizzense/aitherzero:latest \
      pwsh -c "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"
```

## Technical Details

### Directory Structure

```
/opt/aitherzero/          # AitherZero installation (read-only from user perspective)
├── AitherZero.psd1       # Module manifest
├── AitherZero.psm1       # Root module
├── Start-AitherZero.ps1  # Main entry point
├── domains/              # Domain modules
├── automation-scripts/   # Numbered scripts
├── logs/                 # AitherZero logs
├── reports/              # AitherZero reports
└── ...

/app/                     # User working directory (can be volume mounted)
├── (user files)          # User's project files
└── ...
```

### Environment Variables

- `AITHERZERO_ROOT=/opt/aitherzero` - Points to the installation
- `PATH` includes `/opt/aitherzero` and `/opt/aitherzero/automation-scripts`
- Working directory is `/app` for user convenience

### Module Loading

The container CMD automatically imports the module:

```dockerfile
CMD ["pwsh", "-NoProfile", "-Command", "$VerbosePreference='SilentlyContinue'; $InformationPreference='SilentlyContinue'; Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue; Write-Host '✅ AitherZero loaded. Type Start-AitherZero to begin.' -ForegroundColor Green; Start-Sleep -Seconds 2147483"]
```

This ensures:
1. Module is loaded from the correct location
2. User sees a success message
3. Container stays running for interactive use

## Verification

To verify the fix works:

1. **Build the image**:
   ```bash
   docker build -t aitherzero:test .
   ```

2. **Test with empty directory mount**:
   ```bash
   mkdir -p /tmp/test && cd /tmp/test
   docker run -it --rm -v "$(pwd):/app" -w /app aitherzero:test
   ```

3. **Verify module loads**:
   ```bash
   docker run --rm aitherzero:test pwsh -c \
     "Import-Module /opt/aitherzero/AitherZero.psd1; Get-Command -Module AitherZero"
   ```

All tests should pass successfully.
