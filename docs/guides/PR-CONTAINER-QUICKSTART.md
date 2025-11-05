# PR Container Quick Start Guide

This guide demonstrates the exact workflow for testing pull requests using the AitherZero container management system.

## Prerequisites

- Docker installed and running
- Repository cloned locally

## Quick Start Commands

These commands work for any PR number. Simply replace `2157` with your PR number.

### Step 1: Clone Repository

```bash
# Clone the repo
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
```

### Step 2: QuickStart (Automated Setup)

The `QuickStart` action automatically pulls the image, starts the container, and verifies it's ready:

```bash
# QuickStart: Pull + Run + Verify automatically
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 2157
```

**What this does:**
- Pulls the PR container image from GitHub Container Registry (`ghcr.io/wizzense/aitherzero:pr-2157`)
- Creates and starts the container with name `aitherzero-pr-2157`
- Maps to a unique port (8087 for PR 2157)
- Verifies the container is healthy and running
- Displays helpful next steps

### Step 3: Interactive Shell

Open an interactive PowerShell session inside the container:

```bash
# Open interactive shell
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 2157
```

**Inside the shell:**
```powershell
# AitherZero module is auto-loaded, so you can immediately use:
Start-AitherZero                    # Launch interactive menu
az 0402                             # Run unit tests  
az 0510 -ShowAll                    # Generate project report
Get-Command -Module AitherZero      # List all available commands

# Exit when done
exit
# Or press Ctrl+D
```

### Step 4: Execute Commands

Run specific commands in the container without entering it:

```bash
# Execute commands
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 2157 -Command "az 0402"

# More examples:
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 2157 -Command "az 0404"
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 2157 -Command "az 0510 -ShowAll"
```

**What gets executed:**
- Commands run in `/opt/aitherzero` directory
- AitherZero module is automatically imported
- The `az` alias is available (shorthand for running numbered scripts)

### Step 5: Monitor Status

Check if the container is running and healthy:

```bash
# Check status
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Status -PRNumber 2157
```

**Output includes:**
- Container name and image
- Port mapping
- Running status
- Health check status
- Access URL

### Step 6: View Logs

Check container logs for troubleshooting:

```bash
# View logs (last 100 lines)
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 2157

# Follow logs in real-time
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 2157 -Follow
```

Press `Ctrl+C` to stop following logs.

### Step 7: Cleanup

Remove the container when you're done testing:

```bash
# Cleanup when done
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 2157
```

**What this does:**
- Stops the running container
- Removes the container
- Optionally removes the image (use `-Force` to remove image too)

## Complete Workflow Example

Here's a complete testing workflow from start to finish:

```bash
# 1. Clone and navigate
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# 2. Quick setup
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 2157

# 3. Run tests
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 2157 -Command "az 0402"

# 4. Check for errors
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 2157

# 5. Interactive exploration (optional)
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 2157

# 6. Cleanup
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 2157
```

## Port Mapping

Each PR gets a unique port based on its number:

| PR Number | Port | Calculation |
|-----------|------|-------------|
| 2157 | 8087 | 8080 + (2157 % 10) = 8087 |
| 1677 | 8087 | 8080 + (1677 % 10) = 8087 |
| 1634 | 8084 | 8080 + (1634 % 10) = 8084 |
| 2500 | 8080 | 8080 + (2500 % 10) = 8080 |

## Additional Actions

### List All Containers

See all AitherZero PR containers on your system:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action List
```

### Manual Pull

Pull the image without starting it:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Pull -PRNumber 2157
```

### Manual Run

Start a container from an already-pulled image:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber 2157
```

### Stop (Without Removing)

Stop the container but don't remove it:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Stop -PRNumber 2157

# Restart later with:
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber 2157
```

## Advanced Options

### Force Recreation

Force recreate a container even if it's already running:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber 2157 -Force
```

### Custom Port

Use a different port than the default:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber 2157 -Port 9000
```

### Custom Image Tag

Use a custom image instead of the default PR image:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber 2157 -ImageTag "ghcr.io/wizzense/aitherzero:latest"
```

## Troubleshooting

### Docker Not Running

If you see "Docker daemon is not running":

```bash
# Windows: Start Docker Desktop
# Linux: sudo systemctl start docker
# macOS: Open Docker Desktop application
```

### Container Not Found

If the container doesn't exist, it may not have been built yet. Check:

1. PR must be created on GitHub
2. `docker-build-pr.yml` workflow must complete
3. Image should be available at: `ghcr.io/wizzense/aitherzero:pr-{number}`

### Image Pull Fails

If image pull fails, verify:

```bash
# Check if image exists on GHCR
docker pull ghcr.io/wizzense/aitherzero:pr-2157

# Or browse to:
# https://github.com/wizzense/AitherZero/pkgs/container/aitherzero
```

### Container Exits Immediately

Check logs to see why:

```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 2157
```

## See Also

- [Complete Docker Guide](../../DOCKER.md) - Comprehensive Docker documentation
- [Container Guide](../DOCKER-CONTAINER-GUIDE.md) - Detailed container usage
- [Docker Usage](../DOCKER-USAGE.md) - Docker commands and patterns
- [Script Reference](../../automation-scripts/0854_Manage-PRContainer.ps1) - Full script documentation

## Support

For issues or questions:
- GitHub Issues: https://github.com/wizzense/AitherZero/issues
- Script: `automation-scripts/0854_Manage-PRContainer.ps1`
- Documentation: `DOCKER.md`
