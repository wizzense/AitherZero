# AitherZero Docker Usage Guide

## Overview

AitherZero is available as a Docker container image that provides a complete, pre-configured automation environment. The container is designed to work seamlessly with volume mounts, allowing you to work with your own files while using the AitherZero tooling.

## Quick Start

### Pull the Image

```bash
# Latest release
docker pull ghcr.io/wizzense/aitherzero:latest

# Specific PR build (replace <PR_NUMBER> with your PR number)
docker pull ghcr.io/wizzense/aitherzero:pr-<PR_NUMBER>
```

### Run Interactively

```bash
# Start container in interactive mode
docker run -it --rm ghcr.io/wizzense/aitherzero:latest

# The module loads automatically and you'll see:
# ✅ AitherZero loaded. Type Start-AitherZero to begin.

# Then you can run:
Start-AitherZero
```

## Working with Your Files

### Understanding the Directory Structure

The AitherZero container uses a two-directory approach:

- **`/opt/aitherzero`** - AitherZero installation (read-only)
  - Contains all AitherZero modules, scripts, and tools
  - This directory is **never affected** by volume mounts
  
- **`/app`** - Working directory (mount your files here)
  - Default working directory for user files
  - Safe to mount your project directory here
  - Files you create will be in this directory

### Mounting Your Project Directory

You can safely mount your project directory to `/app` without affecting AitherZero:

```bash
# Mount current directory to /app
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:latest

# AitherZero will still work because it's installed in /opt/aitherzero
# Your files are accessible in /app
```

### Example: Running Scripts on Your Files

> **Note:** Manual import of the AitherZero module (`Import-Module /opt/aitherzero/AitherZero.psd1`) is only necessary when you override the default CMD with `-c` (as shown below). If you start the container interactively (see above), the module loads automatically and you do not need to import it manually.

```bash
# Navigate to your project directory
cd /path/to/your/project

# Run AitherZero container with your project mounted and a custom command
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:latest pwsh -c "
  Import-Module /opt/aitherzero/AitherZero.psd1
  # Your project files are now in /app
  Get-ChildItem /app
  # Use AitherZero tools
  /opt/aitherzero/Start-AitherZero.ps1
"
```

## Common Use Cases

### 1. Interactive Development

Start an interactive session with your project files:

```bash
docker run -it --rm \
  -v "$(pwd):/app" \
  -w /app \
  ghcr.io/wizzense/aitherzero:latest
```

### 2. Running Specific Scripts

Execute numbered automation scripts (using the `az` alias):

```bash
docker run -it --rm \
  -v "$(pwd):/app" \
  -w /app \
  ghcr.io/wizzense/aitherzero:latest \
  pwsh -c "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"
```

### 3. Running Playbooks

Execute orchestration playbooks:

```bash
docker run -it --rm \
  -v "$(pwd):/app" \
  -w /app \
  ghcr.io/wizzense/aitherzero:latest \
  pwsh -c "/opt/aitherzero/Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"
```

### 4. CI/CD Integration

Use in GitHub Actions or other CI/CD pipelines:

```yaml
- name: Run AitherZero Tests
  run: |
    docker run --rm \
      -v "${{ github.workspace }}:/app" \
      -e AITHERZERO_CI=true \
      ghcr.io/wizzense/aitherzero:latest \
      pwsh -c "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"
```

## Environment Variables

Configure AitherZero behavior with environment variables:

```bash
docker run -it --rm \
  -e AITHERZERO_NONINTERACTIVE=true \
  -e AITHERZERO_CI=false \
  -e AITHERZERO_LOG_LEVEL=Information \
  -v "$(pwd):/app" \
  ghcr.io/wizzense/aitherzero:latest
```

Available variables:
- `AITHERZERO_ROOT` - Installation root (**fixed as `/opt/aitherzero` in the Docker image; do not change unless you know what you are doing**)
- `AITHERZERO_NONINTERACTIVE` - Disable interactive prompts
- `AITHERZERO_CI` - Enable CI mode
- `AITHERZERO_DISABLE_TRANSCRIPT` - Disable transcript logging
- `AITHERZERO_LOG_LEVEL` - Set log level (Verbose, Information, Warning, Error)

## Docker Compose

Use Docker Compose for persistent environments:

```yaml
version: '3.8'

services:
  aitherzero:
    image: ghcr.io/wizzense/aitherzero:latest
    volumes:
      - ./:/app                              # Mount your project
      - aitherzero-logs:/opt/aitherzero/logs # Persist logs
    working_dir: /app
    environment:
      - AITHERZERO_NONINTERACTIVE=false

volumes:
  aitherzero-logs:
```

Then run:

```bash
docker-compose up -d
docker-compose exec aitherzero pwsh
```

## Troubleshooting

### Module Not Found Error

**Problem:** `Import-Module: The specified module '/app/AitherZero.psd1' was not loaded`

**Solution:** This error occurred in older versions. Make sure you're using the correct module path:

```bash
# ❌ Old (incorrect)
Import-Module /app/AitherZero.psd1

# ✅ New (correct)
Import-Module /opt/aitherzero/AitherZero.psd1
```

The container now handles this automatically on startup.

### Permission Denied on Reports Directory

**Symptom:** Warning about `/app/reports` being denied

**Explanation:** This is a harmless warning that occurs when mounting an empty directory. The AitherZero reports are stored in `/opt/aitherzero/reports`, not `/app/reports`.

**Solution:** No action needed - the module loads successfully despite the warning. If you want to suppress it, ensure your mounted directory contains a `reports` folder:

```bash
mkdir -p reports
docker run -it --rm -v "$(pwd):/app" -w /app ghcr.io/wizzense/aitherzero:latest
```

### Container Exits Immediately

**Problem:** Container starts and exits right away

**Solution:** The default CMD keeps the container running. If it exits, you may have overridden the command. Use:

```bash
# Keep container running in background
docker run -d --name aitherzero ghcr.io/wizzense/aitherzero:latest

# Then exec into it
docker exec -it aitherzero pwsh
```

## Best Practices

1. **Always mount to `/app`** - Keep your project files in `/app`, AitherZero is in `/opt/aitherzero`
2. **Use volume mounts for persistence** - Mount specific volumes for logs and reports if you need them
3. **Use `.dockerignore`** - Exclude unnecessary files when building custom images
4. **Set environment variables** - Configure behavior via environment variables rather than modifying container files
5. **Use specific tags** - Pin to specific version tags rather than using `latest` in production

## Additional Resources

- [Docker Compose Configuration](../docker-compose.yml)
- [GitHub Actions Integration](../.github/workflows/)
- [AitherZero Documentation](../README.md)
- [PR Deployment Guide](./PR-DEPLOYMENT-SETUP-CHECKLIST.md)

## Support

For issues or questions:
- [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- [Project Documentation](../docs/)
