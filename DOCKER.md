# AitherZero Docker Usage Guide

This guide explains how to use AitherZero with Docker for easy deployment and testing.

## Quick Start

### Pull and Run a PR Container

The simplest way to test a PR is to pull and run the pre-built container:

```bash
# Pull the PR container image (replace 1634 with your PR number)
docker pull ghcr.io/wizzense/aitherzero:pr-1634

# Run the container interactively
docker run -it --name aitherzero-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# You'll immediately see the AitherZero welcome screen with the module loaded!
# ✅ AitherZero loaded. Type Start-AitherZero to begin.
```

### Interactive Shell Access

If the container is already running, access it with:

```bash
# Access interactive PowerShell shell (module auto-loads)
docker exec -it aitherzero-pr-1634 pwsh

# You'll see the welcome message and can immediately use AitherZero commands:
Start-AitherZero     # Launch interactive menu
az 0402              # Run unit tests
az 0510              # Generate project report
```

### Run Single Commands

Execute commands without entering the container:

```bash
# Run unit tests (using simplified syntax)
docker exec aitherzero-pr-1634 pwsh -Command "cd /opt/aitherzero && ./Start-AitherZero.ps1 -Mode Run -Target 0402"

# Run PSScriptAnalyzer
docker exec aitherzero-pr-1634 pwsh -Command "az 0404"

# Generate project report
docker exec aitherzero-pr-1634 pwsh -Command "az 0510 -ShowAll"

# List available scripts
docker exec aitherzero-pr-1634 pwsh -Command "cd /opt/aitherzero && ./Start-AitherZero.ps1 -Mode List -Target scripts"

# Search for scripts
docker exec aitherzero-pr-1634 pwsh -Command "cd /opt/aitherzero && ./Start-AitherZero.ps1 -Mode Search -Query test"
```

### Using the Container Manager (Alternative)

For automated PR testing workflows, use the container manager script:

```bash
# Clone the repo (if you want to run automation scripts)
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# QuickStart: Pull + Run + Verify in one command
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1634

# Open interactive shell
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1634

# Cleanup when done
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 1634
```

### Building Locally

If you want to build from source:

```bash
# Clone and navigate to repo
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Build the image
docker build -t aitherzero:latest .

# Run interactively
docker run -it --name aitherzero aitherzero:latest
```

## Container Features

When you start the container, it automatically:

1. ✅ Loads the AitherZero module at `/opt/aitherzero`
2. 📦 Provides an interactive PowerShell 7 environment
3. 🎯 Sets the working directory to `/opt/aitherzero` with all scripts accessible
4. 🖥️ Displays a welcome message with helpful commands

**Important Directories:**
- `/opt/aitherzero` - AitherZero installation (where the module lives)
- `/app` - Working directory for mounting your own files (optional)
- Logs, reports, and test results are stored in `/opt/aitherzero/`

## Access Methods

### Interactive CLI Access (Recommended)

The simplest way to use AitherZero in a container:

```bash
# For a running container
docker exec -it aitherzero-pr-1634 pwsh

# For a new container
docker run -it --name aitherzero-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# Inside the container:
PS /opt/aitherzero> Start-AitherZero     # Launch the interactive menu
PS /opt/aitherzero> az 0402              # Run unit tests
PS /opt/aitherzero> az 0510              # Generate reports
PS /opt/aitherzero> Get-Command -Module AitherZero  # List all commands
```

### Run Single Commands

Execute AitherZero commands from outside the container:

```bash
# Run unit tests
docker exec aitherzero-pr-1634 pwsh -Command "az 0402"

# Generate project report
docker exec aitherzero-pr-1634 pwsh -Command "az 0510"

# Run a playbook
docker exec aitherzero-pr-1634 pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"

# List available scripts
docker exec aitherzero-pr-1634 pwsh -Command "./Start-AitherZero.ps1 -Mode List -Target scripts"
```

### Using docker-start.ps1 (Alternative Entry Point)

For an enhanced interactive experience with more startup messages:

```bash
docker exec -it aitherzero-pr-1634 pwsh /opt/aitherzero/docker-start.ps1
```

## Custom Configuration

### Environment Variables

Configure AitherZero behavior using environment variables:

```bash
docker run -it \
  -e AITHERZERO_PROFILE=Developer \
  -e AITHERZERO_NONINTERACTIVE=false \
  --name aitherzero \
  ghcr.io/wizzense/aitherzero:latest
```

Available environment variables:
- `AITHERZERO_PROFILE`: Minimal, Standard, Developer, Full
- `AITHERZERO_NONINTERACTIVE`: true/false (default: true in container)
- `AITHERZERO_CI`: true/false
- `AITHERZERO_LOG_LEVEL`: Debug, Information, Warning, Error

### Running Specific Modes

Override the default interactive mode:

```bash
# Run validation only
docker run --rm ghcr.io/wizzense/aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Validate"

# Run tests
docker run --rm ghcr.io/wizzense/aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Test -NonInteractive"

# Run a specific playbook
docker run --rm ghcr.io/wizzense/aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -NonInteractive"
```

### Volume Mounts

Mount your project files or persist data across container restarts:

```bash
# Mount your project files to /app
docker run -it \
  -v $(pwd):/app \
  --name aitherzero \
  ghcr.io/wizzense/aitherzero:latest

# Persist logs and reports
docker run -it \
  -v aitherzero-logs:/opt/aitherzero/logs \
  -v aitherzero-reports:/opt/aitherzero/reports \
  --name aitherzero \
  ghcr.io/wizzense/aitherzero:latest
```

## Docker Compose (For Local Development)

For local development, use Docker Compose:

```bash
# Start the container
docker-compose up -d

# Access the container
docker exec -it aitherzero-app pwsh

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### Using Profiles

Docker compose supports optional services via profiles:

```bash
# Start with Redis cache
docker-compose --profile with-cache up -d

# Start with PostgreSQL database
docker-compose --profile with-database up -d

# Start with all optional services
docker-compose --profile with-cache --profile with-database up -d
```

## Troubleshooting

### Container starts then exits immediately

The updated container now stays running in interactive mode. If you see issues:

```bash
# Check container status
docker ps -a

# Check logs
docker logs aitherzero-pr-1634

# Restart the container
docker restart aitherzero-pr-1634
```

### Module not loading properly

If you encounter module loading issues:

```bash
# Verify module exists
docker exec aitherzero-pr-1634 pwsh -Command "Test-Path /opt/aitherzero/AitherZero.psd1"

# Manually import module
docker exec -it aitherzero-pr-1634 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1 -Verbose"

# Check what modules are loaded
docker exec aitherzero-pr-1634 pwsh -Command "Get-Module"
```

### First run shows errors about OpenTofu

This is expected behavior. Some infrastructure scripts (like 0300) check for tools like OpenTofu that aren't in the container. These scripts are designed for full infrastructure deployments, not container environments.

**Solution**: Use the container for testing, validation, and development tasks:
- ✅ `az 0402` - Unit tests
- ✅ `az 0404` - PSScriptAnalyzer
- ✅ `az 0407` - Syntax validation
- ✅ `az 0510` - Generate reports
- ✅ `Start-AitherZero` - Interactive menu (skip infrastructure options)

### Permission issues

If you encounter permission errors with mounted volumes:

```bash
# On Linux/Mac, fix ownership
sudo chown -R $(id -u):$(id -g) ./logs ./reports

# Or run container as root (not recommended)
docker exec -it -u root aitherzero-pr-1634 pwsh
```

## Health Checks

The container includes a health check that verifies the module manifest exists:

```bash
# Check if container is healthy
docker inspect --format='{{.State.Health.Status}}' aitherzero-pr-1634

# Using docker-compose
docker-compose ps
```

## Stopping and Cleaning Up

```bash
# Stop a running container
docker stop aitherzero-pr-1634

# Remove the container
docker rm aitherzero-pr-1634

# Stop and remove with Docker Compose
docker-compose down

# Remove volumes as well
docker-compose down -v

# Remove the image
docker rmi ghcr.io/wizzense/aitherzero:pr-1634

# Complete cleanup
docker-compose down -v --rmi all
```

## Best Practices

1. **PR Testing**: Use pre-built PR images from GHCR for quick testing
2. **Interactive Use**: Use `docker exec -it <container> pwsh` for the best experience
3. **Automation**: Use single command execution for CI/CD pipelines
4. **Volumes**: Mount volumes for persistent logs and reports if needed
5. **Container Names**: Use descriptive names like `aitherzero-pr-1634` for easy identification

## Common Use Cases

### Testing a Pull Request

```bash
# Pull and test a specific PR
docker pull ghcr.io/wizzense/aitherzero:pr-1634
docker run -it --name aitherzero-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# Inside container, run tests
az 0402  # Unit tests
az 0404  # Linter

# Cleanup when done
exit
docker rm aitherzero-pr-1634
```

### CI/CD Integration

```bash
# Run tests in CI pipeline
docker run --rm \
  -e AITHERZERO_CI=true \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0402"

# Generate reports and extract them
docker run --rm \
  -v $(pwd)/reports:/opt/aitherzero/reports \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0510 -ShowAll"
```

### Local Development

```bash
# Build local image
docker build -t aitherzero:dev .

# Run with your code mounted
docker run -it \
  -v $(pwd)/automation-scripts:/opt/aitherzero/automation-scripts \
  --name aitherzero-dev \
  aitherzero:dev

# Make changes on host, test in container immediately
```

## Support

For more information:
- **Main README**: [README.md](README.md)
- **Docker Compose Setup**: [docker-compose.yml](docker-compose.yml)
- **Container Manager Script**: [automation-scripts/0854_Manage-PRContainer.ps1](automation-scripts/0854_Manage-PRContainer.ps1)
- **GitHub Issues**: https://github.com/wizzense/AitherZero/issues
