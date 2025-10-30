# AitherZero Docker Usage Guide

This guide explains how to use AitherZero with Docker for easy deployment and testing.

## What Does This Do?

The AitherZero PR container system provides:
- **Automated PR Testing**: Every PR automatically builds a Docker image published to GitHub Container Registry
- **Isolated Environments**: Each PR gets its own container for safe testing without affecting your system
- **Quick Access**: Pull and run PR containers in seconds to test changes before merging
- **Container Management**: The `0854_Manage-PRContainer.ps1` script provides automated container lifecycle management

### How It Works

1. **Automatic Build**: When you open a PR, GitHub Actions automatically builds a container image
2. **Published to Registry**: The image is pushed to `ghcr.io/wizzense/aitherzero:pr-{number}`
3. **Easy Testing**: Pull the image and run it locally to test the PR changes
4. **Managed Lifecycle**: Use the container manager script for automated setup, testing, and cleanup

## Quick Start

### Method 1: Simple Docker Commands (No Clone Required)

The fastest way to test a PR - just use Docker directly:

```bash
# Pull the PR container image (replace 1677 with your PR number)
docker pull ghcr.io/wizzense/aitherzero:pr-1677

# Run the container
docker run -d --name aitherzero-pr-1677 -p 8087:8080 ghcr.io/wizzense/aitherzero:pr-1677

# Wait a few seconds for startup
sleep 5

# Run tests in the container (when module is loaded, 'az' alias is available)
docker exec aitherzero-pr-1677 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"

# Open interactive shell to explore
docker exec -it aitherzero-pr-1677 pwsh

# Cleanup when done
docker stop aitherzero-pr-1677 && docker rm aitherzero-pr-1677
```

### Method 2: Using the Container Manager (After Cloning)

For automated workflows, clone the repo and use the container manager:

```bash
# Step 1: Clone the AitherZero repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Step 2: Use the container manager for automated operations
# QuickStart: Pull + Run + Verify in one command
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1677

# Open interactive shell
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1677

# Check status
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Status -PRNumber 1677

# View logs
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 1677 -Follow

# Execute commands in container
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 1677 -Command "az 0402"

# Cleanup when done
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 1677
```

### Method 3: Interactive Testing (Recommended for Development)

The best experience for exploring and testing:

```bash
# Pull and run PR container interactively
docker pull ghcr.io/wizzense/aitherzero:pr-1677
docker run -it --name aitherzero-pr-1677 ghcr.io/wizzense/aitherzero:pr-1677

# You'll immediately see the AitherZero welcome screen!
# ✅ AitherZero loaded. Module is ready to use.

# Inside the container, the module is already loaded, so use:
Start-AitherZero                    # Launch interactive menu
az 0402                             # Run unit tests  
az 0510 -ShowAll                    # Generate project report
Get-Command -Module AitherZero      # List all available commands
```

## Understanding the `az` Alias

The `az` command is an alias automatically created when the AitherZero module is loaded:

### How It Works
When the AitherZero module is imported (which happens automatically in containers), the `az` alias is created:
```powershell
# Inside containers or when module is loaded
az 0402        # Runs automation-scripts/0402_Run-UnitTests.ps1
az 0404        # Runs automation-scripts/0404_Run-PSScriptAnalyzer.ps1
az 0510        # Runs automation-scripts/0510_Generate-ProjectReport.ps1
```

### Using from Outside Container
When executing commands from outside the container, ensure the module is loaded:
```bash
# Import module first, then use az alias
docker exec aitherzero-pr-1677 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"
```

### Available Commands
- `az 0402` - Run unit tests
- `az 0404` - Run PSScriptAnalyzer linting
- `az 0407` - Validate PowerShell syntax
- `az 0510` - Generate project report
- `az 0854` - Manage PR containers (requires repo clone)

## Container Management Features

The `0854_Manage-PRContainer.ps1` script provides these actions:

| Action | Description |
|--------|-------------|
| `QuickStart` | Automated: Pull + Run + Verify in one command |
| `Pull` | Pull the PR container image from registry |
| `Run` | Start the PR container |
| `Stop` | Stop the running container |
| `Status` | Check container status and health |
| `Logs` | View container logs (use `-Follow` for live logs) |
| `Shell` | Open interactive PowerShell shell in container |
| `Exec` | Execute a specific command in the container |
| `Cleanup` | Stop and remove the container |
| `List` | List all AitherZero PR containers |

### Example Workflows

**Quick Test PR Changes:**
```bash
cd AitherZero
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1677
# Container is now running and ready to use
```

**Run Tests in Container:**
```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 1677 -Command "az 0402"
```

**Interactive Debugging Session:**
```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1677
# Opens interactive shell in container (module auto-loads, az alias available)
# Use exit or Ctrl+D to close
```

**Monitor Container Activity:**
```bash
pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 1677 -Follow
# Use Ctrl+C to stop following
```

## Direct Docker Usage (Without Container Manager)

If you prefer using Docker commands directly without cloning the repo:

### Interactive Shell Access



```bash
# Access interactive PowerShell shell in a running container
docker exec -it aitherzero-pr-1677 pwsh

# Inside the container, module is auto-loaded, so you can use:
Start-AitherZero                    # Launch interactive menu
az 0402                             # Run unit tests
az 0510 -ShowAll                    # Generate project report
Get-Command -Module AitherZero      # List all commands
```

### Run Single Commands

Execute commands without entering the container:

```bash
# Run tests (import module first to get az alias)
docker exec aitherzero-pr-1677 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; az 0402"

# Run PSScriptAnalyzer
docker exec aitherzero-pr-1677 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; az 0404"

# Generate project report
docker exec aitherzero-pr-1677 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; az 0510 -ShowAll"

# List available scripts
docker exec aitherzero-pr-1677 pwsh -Command "cd /opt/aitherzero && ./Start-AitherZero.ps1 -Mode List -Target scripts"
```

### Port Mapping

Each PR gets a unique port based on its number:
- Formula: `8080 + (PR_NUMBER % 100)`
- PR #1677 → Port 8087
- PR #1634 → Port 8084
- PR #2500 → Port 8080 (rolls over after 100)

```bash
# Run with custom port mapping
docker run -d --name aitherzero-pr-1677 -p 8087:8080 ghcr.io/wizzense/aitherzero:pr-1677

# Access via localhost (if web interface is enabled)
curl http://localhost:8087
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
docker-compose exec aitherzero pwsh

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
