# AitherZero Docker Usage Guide

## Overview

AitherZero is available as a Docker container image that provides a complete, pre-configured automation environment. The container automatically loads the AitherZero module and provides an interactive PowerShell environment ready to use.

## Quick Start

### Pull and Run a PR Container

```bash
# Pull the PR container image (replace 1634 with your PR number)
docker pull ghcr.io/wizzense/aitherzero:pr-1634

# Run interactively - module loads automatically!
docker run -it --name aitherzero-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# You'll see the AitherZero welcome screen:
# ✅ AitherZero loaded. Type Start-AitherZero to begin.

# Start using AitherZero immediately:
PS /opt/aitherzero> Start-AitherZero
```

### Access a Running Container

If your container is already running:

```bash
# Access interactive PowerShell (module auto-loads)
docker exec -it aitherzero-pr-1634 pwsh

# The module is already loaded, just start using it:
Start-AitherZero
```

## Understanding the Container Directory Structure

The AitherZero container uses a clean separation:

- **`/opt/aitherzero`** - AitherZero installation directory
  - Contains all modules, scripts, and tools
  - This is where you'll be by default
  - The AitherZero module is installed here
  
- **`/app`** - Optional working directory for your files
  - Can be used to mount your own project files
  - Completely separate from AitherZero installation

## Working with the Container

### Interactive Mode (Recommended)

The best way to use AitherZero:

```bash
# Start a new container
docker run -it --name aitherzero-test ghcr.io/wizzense/aitherzero:latest

# Or access existing container
docker exec -it aitherzero-test pwsh

# You're now in PowerShell with AitherZero loaded!
PS /opt/aitherzero> Start-AitherZero     # Launch interactive menu
PS /opt/aitherzero> az 0402              # Run unit tests
PS /opt/aitherzero> az 0510              # Generate reports
PS /opt/aitherzero> Get-Command -Module AitherZero  # List all commands
```

### Running Specific Commands

Execute commands without entering the container:

```bash
# Run unit tests
docker exec aitherzero-test pwsh -Command "az 0402"

# Run PSScriptAnalyzer
docker exec aitherzero-test pwsh -Command "az 0404"

# Generate project report
docker exec aitherzero-test pwsh -Command "az 0510 -ShowAll"

# Run a playbook
docker exec aitherzero-test pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"
```

### Mounting Your Project Files

You can mount your own files to `/app` if needed:

```bash
# Mount current directory to /app
docker run -it --rm \
  -v "$(pwd):/app" \
  --name aitherzero-dev \
  ghcr.io/wizzense/aitherzero:latest

# AitherZero is still in /opt/aitherzero
# Your files are in /app
PS /opt/aitherzero> cd /app
PS /app> ls
# Your files are here
```

## Common Use Cases

### 1. Testing a Pull Request

```bash
# Pull and test a specific PR
docker pull ghcr.io/wizzense/aitherzero:pr-1634
docker run -it --name test-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# Inside container:
az 0402  # Run unit tests
az 0404  # Run linter
az 0510  # Generate reports

# Exit and cleanup
exit
docker rm test-pr-1634
```

### 2. Running in CI/CD

```bash
# Run tests in CI
docker run --rm \
  -e AITHERZERO_CI=true \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0402"

# Generate and extract reports
docker run --rm \
  -v $(pwd)/reports:/opt/aitherzero/reports \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0510 -ShowAll"
```

### 3. Local Development

```bash
# Build local image
docker build -t aitherzero:dev .

# Run with interactive access
docker run -it --name aitherzero-dev aitherzero:dev

# Or mount your code for testing changes
docker run -it \
  -v $(pwd)/domains:/opt/aitherzero/domains \
  --name aitherzero-dev \
  aitherzero:dev
```

### 4. Running Playbooks

```bash
# Quick test playbook
docker exec aitherzero-test pwsh -Command \
  "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"

# Full test playbook
docker exec aitherzero-test pwsh -Command \
  "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full"
```

## Environment Variables

Configure container behavior:

```bash
docker run -it \
  -e AITHERZERO_PROFILE=Developer \
  -e AITHERZERO_NONINTERACTIVE=false \
  -e AITHERZERO_LOG_LEVEL=Information \
  --name aitherzero \
  ghcr.io/wizzense/aitherzero:latest
```

Available variables:
- `AITHERZERO_ROOT` - Installation root (default: `/opt/aitherzero`)
- `AITHERZERO_PROFILE` - Profile: Minimal, Standard, Developer, Full
- `AITHERZERO_NONINTERACTIVE` - Disable interactive prompts (default: true)
- `AITHERZERO_CI` - Enable CI mode (default: false)
- `AITHERZERO_LOG_LEVEL` - Logging level: Debug, Information, Warning, Error
- `AITHERZERO_DISABLE_TRANSCRIPT` - Disable transcript logging (default: 1)

## Troubleshooting

### Module Not Loading

If the module doesn't load automatically:

```bash
# Verify module exists
docker exec aitherzero-test pwsh -Command \
  "Test-Path /opt/aitherzero/AitherZero.psd1"

# Manually import
docker exec -it aitherzero-test pwsh -Command \
  "Import-Module /opt/aitherzero/AitherZero.psd1 -Verbose"

# Check loaded modules
docker exec aitherzero-test pwsh -Command "Get-Module"
```

### First Run Shows OpenTofu Error

This is expected. Some infrastructure scripts check for tools like OpenTofu that aren't in the container. These scripts are for full infrastructure deployments.

**What works in containers:**
- ✅ `az 0402` - Unit tests
- ✅ `az 0404` - PSScriptAnalyzer
- ✅ `az 0407` - Syntax validation
- ✅ `az 0510` - Generate reports
- ✅ `Start-AitherZero` - Interactive menu

**What requires a full environment:**
- ❌ Infrastructure deployment (0300-0399 range)
- ❌ Hyper-V setup (requires Windows host)
- ❌ Some platform-specific features

### Container Exits Immediately

The container should stay running now. If it exits:

```bash
# Check logs
docker logs aitherzero-test

# Restart
docker restart aitherzero-test

# Run with explicit keep-alive
docker run -it --name aitherzero-test \
  ghcr.io/wizzense/aitherzero:latest
```

### Permission Issues

```bash
# Fix mounted volume permissions (Linux/Mac)
sudo chown -R $(id -u):$(id -g) ./logs ./reports

# Run as root if needed (not recommended)
docker exec -it -u root aitherzero-test pwsh
```

## Docker Compose

For persistent development environments:

```yaml
version: '3.8'

services:
  aitherzero:
    image: ghcr.io/wizzense/aitherzero:latest
    container_name: aitherzero-dev
    volumes:
      - aitherzero-logs:/opt/aitherzero/logs
      - aitherzero-reports:/opt/aitherzero/reports
    environment:
      - AITHERZERO_PROFILE=Developer
      - AITHERZERO_NONINTERACTIVE=false
    stdin_open: true
    tty: true

volumes:
  aitherzero-logs:
  aitherzero-reports:
```

Then:

```bash
docker-compose up -d
docker-compose exec aitherzero pwsh
```

## Best Practices

1. **Use descriptive container names** like `aitherzero-pr-1634` for easy identification
2. **Mount volumes for persistence** if you need to keep logs/reports
3. **Use `--rm` flag** for temporary testing containers
4. **Set environment variables** for customization instead of modifying files
5. **Test in containers** before deploying to ensure cross-platform compatibility

## Support

For more information:
- **Main Docker Guide**: [/DOCKER.md](../DOCKER.md)
- **Container Manager Script**: [automation-scripts/0854_Manage-PRContainer.ps1](../automation-scripts/0854_Manage-PRContainer.ps1)
- **GitHub Issues**: https://github.com/wizzense/AitherZero/issues
