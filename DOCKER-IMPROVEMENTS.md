# Docker Container Startup Improvements

## Problem Summary

The Docker container had several startup issues:
1. Required manual `cd /opt/aitherzero` 
2. Required running `pwsh ./Start-AitherZero.ps1` twice (first failed, second worked)
3. No global `aitherzero` command available
4. Overly complex with multiple docker-* scripts

## Solution

Simplified the Docker setup to run bootstrap during build and install the global command.

## Before vs After

### Before

```bash
# Start container
docker run -d --name test aitherzero:latest

# Had to manually navigate
docker exec -it test bash
cd /opt/aitherzero

# Had to run twice - first time errors
pwsh ./Start-AitherZero.ps1  # ❌ Errors
pwsh ./Start-AitherZero.ps1  # ✅ Works second time

# No global command
aitherzero  # ❌ Command not found
```

### After

```bash
# Start container - automatically bootstrapped and ready
docker run -d --name test aitherzero:latest

# Global command works immediately from any directory
docker exec test aitherzero  # ✅ Works immediately

# Interactive shell has command in PATH
docker exec -it test pwsh
PS> aitherzero  # ✅ Just works!
```

## Technical Changes

### 1. Dockerfile Simplification

**Removed:**
- Complex multi-stage build
- Separate `/app` working directory
- Python and web server dependencies
- Manual module installation attempts
- Three separate docker-* scripts

**Added:**
- Bootstrap execution during build
- Global command installation verification
- Embedded welcome message in CMD

### 2. Bootstrap Integration

The Dockerfile now runs:
```dockerfile
RUN pwsh -NoProfile -ExecutionPolicy Bypass -Command " \
    Write-Host '🚀 Bootstrapping AitherZero...' -ForegroundColor Cyan; \
    ./bootstrap.ps1 -Mode New -InstallProfile Minimal -NonInteractive -SkipAutoStart; \
    Write-Host '✅ Bootstrap complete' -ForegroundColor Green"
```

This ensures:
- Module is properly initialized
- Global command is installed to `/home/aitherzero/.local/bin`
- Environment variables are set
- All dependencies are resolved

### 3. Global Command Availability

The `aitherzero` command is now:
- Installed during container build
- Added to PATH automatically
- Works from any directory
- Points to `/home/aitherzero/.local/bin/aitherzero`

### 4. File Changes

**Deleted:**
- `container-welcome.ps1` - functionality moved to Dockerfile CMD
- `docker-entrypoint.ps1` - not needed
- `docker-start.ps1` - not needed

**Modified:**
- `Dockerfile` - simplified and improved
- `DOCKER.md` - updated instructions

## Testing Results

```bash
# Build succeeds
$ docker build -t aitherzero-test:latest .
✅ Bootstrap complete
✅ Global aitherzero command installed

# Container starts with welcome
$ docker run -d --name test aitherzero-test:latest
$ docker logs test
╔══════════════════════════════════════════════════════════════╗
║                    🚀 AitherZero Container                   ║
╚══════════════════════════════════════════════════════════════╝

✅ Ready to use!

💡 Quick commands:
   aitherzero                 - Launch interactive menu
   Start-AitherZero           - Same as above

# Command is in PATH
$ docker exec test which aitherzero
/home/aitherzero/.local/bin/aitherzero

# Works from any directory
$ docker exec test pwsh -Command "cd /tmp; aitherzero"
[Successfully launches application with full menu]

# Interactive shell works
$ docker exec -it test pwsh
PS> aitherzero
[Application launches successfully]
```

## Benefits

1. **Immediate Usability**: Container is ready to use as soon as it starts
2. **No Double-Run Bug**: Bootstrap runs once during build, works first time
3. **Global Command**: `aitherzero` command available everywhere
4. **Simplified Maintenance**: Fewer files, clearer purpose
5. **Better UX**: Users just type `aitherzero` and it works

## User Impact

Users can now:
- Pull the container and use it immediately
- Run `aitherzero` from any directory
- Not worry about manual initialization
- Have a consistent, reliable experience

This matches the expected behavior described in the issue: "just be ready to go to run 'aitherzero'".
