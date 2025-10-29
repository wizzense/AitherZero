# AitherZero Docker Container Guide

## 📦 Overview

This guide provides comprehensive instructions for using the AitherZero Docker container for development, testing, and automation workflows. The containerized version provides a consistent, isolated environment that works across all platforms.

## 🎯 Why Use Docker?

- **Consistency**: Same environment on Windows, macOS, and Linux
- **Isolation**: No conflicts with system packages or dependencies
- **Quick Start**: Skip manual dependency installation
- **CI/CD Ready**: Perfect for automated testing and deployments
- **Clean Testing**: Test changes without affecting your system

## 🚀 Quick Start

### Pull and Run (Fastest Method)

```bash
# Pull a PR container (replace 1634 with your PR number)
docker pull ghcr.io/wizzense/aitherzero:pr-1634

# Run interactively
docker run -it --name aitherzero-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# Module loads automatically! Start using immediately:
PS /opt/aitherzero> Start-AitherZero
```

### Using Docker Compose (For Local Development)

```bash
# Clone the repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Start the container
docker-compose up -d

# Access the container
docker exec -it aitherzero-app pwsh

# AitherZero is already loaded!
PS /opt/aitherzero> Start-AitherZero
```

### Building Locally

```bash
# Navigate to the repository
cd AitherZero

# Build the image
docker build -t aitherzero:latest .

# Run interactively
docker run -it --name aitherzero aitherzero:latest
```

## 📥 Container Images

### Pre-built Images (GitHub Container Registry)

Pre-built images are available for all PRs and releases:

```bash
# Latest main branch
docker pull ghcr.io/wizzense/aitherzero:latest

# Specific PR build
docker pull ghcr.io/wizzense/aitherzero:pr-1634

# Specific version tag (when available)
docker pull ghcr.io/wizzense/aitherzero:v2.0.0
```

**Note**: Container image names use lowercase per Docker conventions.

### Verifying Images

```bash
# List Docker images
docker images | grep aitherzero

# Inspect an image
docker inspect ghcr.io/wizzense/aitherzero:pr-1634

# Check image size
docker images ghcr.io/wizzense/aitherzero:pr-1634 --format "{{.Size}}"
```

## 🎮 Using the Container

### Interactive Mode (Recommended)

Start an interactive PowerShell session with AitherZero pre-loaded:

```bash
# New container
docker run -it --name aitherzero-test ghcr.io/wizzense/aitherzero:latest

# Access existing container
docker exec -it aitherzero-test pwsh

# You're in PowerShell with AitherZero loaded!
PS /opt/aitherzero> Start-AitherZero     # Launch interactive menu
PS /opt/aitherzero> az 0402              # Run unit tests
PS /opt/aitherzero> az 0510              # Generate reports
PS /opt/aitherzero> Get-Command -Module AitherZero  # List commands
```

### Running Specific Commands

Execute commands without entering the container:

```bash
# Run unit tests
docker exec aitherzero-test pwsh -Command "az 0402"

# Run syntax validation
docker exec aitherzero-test pwsh -Command "az 0407"

# Run PSScriptAnalyzer
docker exec aitherzero-test pwsh -Command "az 0404"

# Generate project report
docker exec aitherzero-test pwsh -Command "az 0510 -ShowAll"

# Run a playbook
docker exec aitherzero-test pwsh -Command \
  "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"
```

### Mounting Local Files

Mount your project directory for development:

```bash
# Mount current directory to /app
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  ghcr.io/wizzense/aitherzero:latest

# AitherZero is in /opt/aitherzero, your files are in /app
PS /opt/aitherzero> cd /app
PS /app> ls
```

## 🔧 Common Workflows

### Testing a Pull Request

```bash
# Pull and test specific PR
docker pull ghcr.io/wizzense/aitherzero:pr-1634
docker run -it --name test-pr-1634 ghcr.io/wizzense/aitherzero:pr-1634

# Inside container, run tests
az 0402  # Unit tests
az 0404  # Linter
az 0510  # Reports

# Cleanup
exit
docker rm test-pr-1634
```

### CI/CD Integration

```bash
# Run validation in CI
docker run --rm \
  -e AITHERZERO_CI=true \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0402"

# Run complete test suite
docker run --rm \
  -e AITHERZERO_CI=true \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full -NonInteractive"

# Extract reports
docker run --rm \
  -v $(pwd)/reports:/opt/aitherzero/reports \
  ghcr.io/wizzense/aitherzero:pr-1634 \
  pwsh -Command "az 0510 -ShowAll"
```

### Local Development

```bash
# Build local image
docker build -t aitherzero:dev .

# Run with code mounted for live changes
docker run -it \
  -v $(pwd)/domains:/opt/aitherzero/domains \
  -v $(pwd)/automation-scripts:/opt/aitherzero/automation-scripts \
  --name aitherzero-dev \
  aitherzero:dev

# Changes on host reflect immediately in container
```

## ⚙️ Configuration

### Environment Variables

Configure container behavior:

```bash
docker run -it \
  -e AITHERZERO_PROFILE=Developer \
  -e AITHERZERO_NONINTERACTIVE=false \
  -e AITHERZERO_LOG_LEVEL=Information \
  --name aitherzero \
  ghcr.io/wizzense/aitherzero:latest
```

**Available Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `AITHERZERO_ROOT` | Installation directory | `/opt/aitherzero` |
| `AITHERZERO_PROFILE` | Configuration profile | `Standard` |
| `AITHERZERO_NONINTERACTIVE` | Disable prompts | `true` |
| `AITHERZERO_CI` | CI/CD mode | `false` |
| `AITHERZERO_LOG_LEVEL` | Logging level | `Warning` |
| `AITHERZERO_DISABLE_TRANSCRIPT` | Disable transcript | `1` |

### Docker Compose Configuration

Edit `docker-compose.yml` to customize:

```yaml
services:
  aitherzero:
    image: ghcr.io/wizzense/aitherzero:latest
    environment:
      - AITHERZERO_PROFILE=Developer
      - AITHERZERO_LOG_LEVEL=Information
    volumes:
      - aitherzero-logs:/opt/aitherzero/logs
      - aitherzero-reports:/opt/aitherzero/reports
```

### Persisting Data

```bash
# Create named volumes
docker volume create aitherzero-logs
docker volume create aitherzero-reports

# Run with volumes
docker run -it --rm \
  -v aitherzero-logs:/opt/aitherzero/logs \
  -v aitherzero-reports:/opt/aitherzero/reports \
  ghcr.io/wizzense/aitherzero:latest
```

## 🐛 Troubleshooting

### Container Exits Immediately

The updated container now stays running. If it still exits:

```bash
# Check logs
docker logs <container-name>

# Run interactively to debug
docker run -it --name debug ghcr.io/wizzense/aitherzero:latest
```

### Module Not Loading

Verify module installation:

```bash
# Check module exists
docker exec <container> pwsh -Command \
  "Test-Path /opt/aitherzero/AitherZero.psd1"

# Manually import
docker exec -it <container> pwsh -Command \
  "Import-Module /opt/aitherzero/AitherZero.psd1 -Verbose"

# Check PowerShell version
docker exec <container> pwsh -Command '$PSVersionTable'
```

### First Run Shows OpenTofu Error

This is **expected behavior**. Some infrastructure scripts (like 0300) check for tools that aren't in the container. Skip these when using containers.

**Works in containers:**
- ✅ Testing (`az 0402`)
- ✅ Linting (`az 0404`)
- ✅ Validation (`az 0407`)
- ✅ Reports (`az 0510`)
- ✅ Interactive menu (`Start-AitherZero`)

**Requires full environment:**
- ❌ Infrastructure deployment (0300-0399)
- ❌ Hyper-V setup (Windows only)
- ❌ Some platform-specific features

### Permission Issues

Fix volume permission problems:

```bash
# Linux/Mac - fix ownership
sudo chown -R $(id -u):$(id -g) ./logs ./reports

# Run as root (not recommended)
docker exec -it -u root <container> pwsh
```

### Network Issues

Test container connectivity:

```bash
# Test DNS
docker exec <container> ping -c 3 google.com

# Test network
docker run --rm --network=host ghcr.io/wizzense/aitherzero:latest \
  pwsh -Command "Test-Connection -ComputerName github.com -Count 3"
```

## 🔍 Inspecting Containers

### View Container Details

```bash
# List running containers
docker ps

# List all containers
docker ps -a

# Inspect configuration
docker inspect <container>

# View resource usage
docker stats <container>

# View processes
docker top <container>
```

### Accessing Logs

```bash
# View logs
docker logs <container>

# Follow logs in real-time
docker logs -f <container>

# Last 50 lines
docker logs --tail 50 <container>

# With timestamps
docker logs -t <container>
```

### File System Access

```bash
# Copy files from container
docker cp <container>:/opt/aitherzero/logs ./local-logs
docker cp <container>:/opt/aitherzero/reports/test-results.xml ./

# Copy files to container
docker cp ./my-script.ps1 <container>:/opt/aitherzero/automation-scripts/

# Browse filesystem
docker exec <container> ls -la /opt/aitherzero
```

## 🧹 Cleanup

### Remove Containers

```bash
# Stop and remove container
docker stop <container> && docker rm <container>

# Remove all stopped containers
docker container prune

# Docker Compose cleanup
docker-compose down
```

### Remove Images

```bash
# Remove specific image
docker rmi ghcr.io/wizzense/aitherzero:pr-1634

# Remove unused images
docker image prune -a
```

### Remove Volumes

```bash
# Remove specific volume
docker volume rm aitherzero-logs

# Remove all unused volumes
docker volume prune

# Docker Compose with volumes
docker-compose down -v
```

## 📚 Advanced Usage

### Multi-Platform Builds

```bash
# Build for ARM64 (Apple Silicon)
docker buildx build --platform linux/arm64 -t aitherzero:arm64 .

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 \
  -t aitherzero:multiarch .
```

### Custom Entry Points

```bash
# Run specific command on startup
docker run --rm ghcr.io/wizzense/aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Validate"

# Run bash instead of PowerShell
docker run -it --rm ghcr.io/wizzense/aitherzero:latest bash
```

### Health Checks

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' <container>

# View health check logs
docker inspect --format='{{json .State.Health}}' <container> | jq
```

## 🎓 Best Practices

1. **Use descriptive names** for containers (e.g., `aitherzero-pr-1634`)
2. **Pull pre-built images** instead of building locally when possible
3. **Use `--rm` flag** for temporary testing containers
4. **Mount volumes** for persistent data (logs, reports)
5. **Set environment variables** for customization
6. **Test in containers** before deploying to ensure cross-platform compatibility
7. **Clean up regularly** to reclaim disk space
8. **Use specific tags** instead of `latest` in production
9. **Check logs** when troubleshooting issues
10. **Run as non-root** (already configured by default)

## 🔗 Related Documentation

- [Docker Usage Guide](DOCKER-USAGE.md) - Simplified usage instructions
- [Main README](../README.md) - General AitherZero documentation
- [Docker Compose File](../docker-compose.yml) - Compose configuration
- [Container Manager Script](../automation-scripts/0854_Manage-PRContainer.ps1)

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
3. Check container logs: `docker logs <container>`
4. Create a new issue with:
   - Docker version (`docker --version`)
   - Host OS and version
   - Full error messages
   - Steps to reproduce

---

**Last Updated**: 2025-10-28  
**Docker Image**: PowerShell 7.4 on Ubuntu 22.04  
**Maintainers**: AitherZero Team
