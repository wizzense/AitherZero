# AitherZero Docker Container Guide

## 📦 Overview

This guide provides comprehensive instructions for obtaining and using the AitherZero Docker container for development, testing, and automation workflows. The containerized version of AitherZero provides a consistent, isolated environment that works across all platforms.

## 🎯 Why Use Docker?

- **Consistency**: Same environment on Windows, macOS, and Linux
- **Isolation**: No conflicts with system packages or dependencies
- **Quick Start**: Skip manual dependency installation
- **CI/CD Ready**: Perfect for automated testing and deployments
- **Clean Testing**: Test changes without affecting your system

## 🚀 Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Start the container
docker-compose up -d

# Access the container
docker-compose exec aitherzero pwsh

# You're now in PowerShell inside the container!
# Run AitherZero commands:
./Start-AitherZero.ps1
```

### Option 2: Using Docker CLI

```bash
# Build the image
docker build -t aitherzero:latest .

# Run the container
docker run -it --rm aitherzero:latest pwsh

# Inside the container, run:
./Start-AitherZero.ps1
```

## 📥 Obtaining the Container

### Building Locally

**Build the image from source:**

```bash
# Navigate to the repository
cd /path/to/AitherZero

# Build using Docker CLI
docker build -t aitherzero:latest .

# Or build with a specific tag
docker build -t aitherzero:1.0.0 .

# Build with custom Dockerfile
docker build -f Dockerfile -t aitherzero:custom .
```

**Build using Docker Compose:**

```bash
# Build the image defined in docker-compose.yml
docker-compose build

# Build with no cache (fresh build)
docker-compose build --no-cache

# Build and start
docker-compose up --build
```

### Pulling from Registry (Future)

> **Note**: Public container registry support is planned for future releases. For now, build locally using the instructions above.

```bash
# When available, you'll be able to pull pre-built images:
# docker pull ghcr.io/wizzense/aitherzero:latest
# docker pull ghcr.io/wizzense/aitherzero:v1.0.0
```

### Verifying the Image

```bash
# List Docker images
docker images | grep aitherzero

# Inspect the image
docker inspect aitherzero:latest

# Check image size
docker images aitherzero:latest --format "{{.Size}}"

# View image layers
docker history aitherzero:latest
```

## 🎮 Using the Container

### Interactive Mode

**Start an interactive PowerShell session:**

```bash
# Using Docker Compose
docker-compose run --rm aitherzero pwsh

# Using Docker CLI
docker run -it --rm aitherzero:latest pwsh
```

**Run the interactive AitherZero UI:**

```bash
# Start container and run Start-AitherZero.ps1
docker run -it --rm aitherzero:latest pwsh -Command "./Start-AitherZero.ps1"

# With Docker Compose
docker-compose exec aitherzero pwsh -Command "./Start-AitherZero.ps1"
```

### Running Specific Commands

**Execute single commands:**

```bash
# Run unit tests
docker run --rm aitherzero:latest pwsh -Command "./az.ps1 0402"

# Run syntax validation
docker run --rm aitherzero:latest pwsh -Command "./az.ps1 0407"

# Run PSScriptAnalyzer
docker run --rm aitherzero:latest pwsh -Command "./az.ps1 0404"

# Generate project report
docker run --rm aitherzero:latest pwsh -Command "./az.ps1 0510 -ShowAll"
```

**Using Docker Compose:**

```bash
# Start the container in background
docker-compose up -d

# Run commands
docker-compose exec aitherzero pwsh -Command "./az.ps1 0402"
docker-compose exec aitherzero pwsh -Command "./az.ps1 0404"

# Stop the container
docker-compose down
```

### Mounting Local Files

**Mount your local code for development:**

```bash
# Mount current directory to /app in container
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  aitherzero:latest pwsh

# With specific subdirectory
docker run -it --rm \
  -v $(pwd)/domains:/app/domains \
  -v $(pwd)/automation-scripts:/app/automation-scripts \
  aitherzero:latest pwsh
```

**Using Docker Compose with volume mounts:**

Edit `docker-compose.yml` and uncomment the volume mount:

```yaml
services:
  aitherzero:
    volumes:
      # Uncomment this line for development:
      - .:/app:rw
```

Then:

```bash
docker-compose up -d
# Changes to files on your host are immediately reflected in the container
```

### Persisting Data

**Keep logs and reports:**

```bash
# Docker Compose automatically creates volumes
docker-compose up -d

# View volumes
docker volume ls | grep aitherzero

# Inspect a volume
docker volume inspect aitherzero-logs

# Backup a volume
docker run --rm \
  -v aitherzero-logs:/data \
  -v $(pwd)/backup:/backup \
  busybox tar czf /backup/logs-backup.tar.gz -C /data .
```

**Manual volume mounts:**

```bash
# Create named volumes
docker volume create aitherzero-logs
docker volume create aitherzero-reports

# Run with volumes
docker run -it --rm \
  -v aitherzero-logs:/app/logs \
  -v aitherzero-reports:/app/reports \
  aitherzero:latest pwsh
```

## 🔧 Common Workflows

### Development Workflow

```bash
# 1. Start container with code mounted
docker-compose up -d

# 2. Make changes to code on your host machine

# 3. Test changes in container
docker-compose exec aitherzero pwsh -Command "./az.ps1 0402"

# 4. Run quality checks
docker-compose exec aitherzero pwsh -Command "./az.ps1 0404"

# 5. View logs
docker-compose logs -f aitherzero
```

### Testing Workflow

```bash
# Run complete test suite
docker run --rm aitherzero:latest pwsh -Command " \
  Import-Module ./AitherZero.psd1; \
  Invoke-Pester -Path ./tests -Output Detailed \
"

# Run specific test file
docker run --rm aitherzero:latest pwsh -Command " \
  Invoke-Pester -Path ./tests/unit/Configuration.Tests.ps1 -Output Detailed \
"

# Run with code coverage
docker run --rm \
  -v $(pwd)/reports:/app/reports \
  aitherzero:latest pwsh -Command " \
  Invoke-Pester -Path ./tests -CodeCoverage ./domains/**/*.psm1 -Output Detailed \
"
```

### CI/CD Workflow

```bash
# Run validation sequence
docker run --rm aitherzero:latest pwsh -Command " \
  ./az.ps1 0407 && \
  ./az.ps1 0404 && \
  ./az.ps1 0402 \
"

# Run with exit code handling
docker run --rm aitherzero:latest pwsh -Command " \
  \$ErrorActionPreference = 'Stop'; \
  ./az.ps1 0402; \
  if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } \
"
```

### Orchestration Workflow

```bash
# Run playbook sequence
docker run --rm aitherzero:latest pwsh -Command " \
  ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -NonInteractive \
"

# Run specific sequence
docker run --rm aitherzero:latest pwsh -Command " \
  ./Start-AitherZero.ps1 -Mode Orchestrate -Sequence 0400-0406 -NonInteractive \
"
```

## ⚙️ Configuration

### Environment Variables

The container supports several environment variables for configuration:

```bash
# Run with custom configuration
docker run --rm \
  -e AITHERZERO_NONINTERACTIVE=true \
  -e AITHERZERO_CI=true \
  -e AITHERZERO_PROFILE=Developer \
  -e AITHERZERO_LOG_LEVEL=Verbose \
  aitherzero:latest pwsh -Command "./az.ps1 0402"
```

**Available Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `AITHERZERO_ROOT` | Installation root directory | `/app` |
| `AITHERZERO_NONINTERACTIVE` | Disable interactive prompts | `true` |
| `AITHERZERO_CI` | CI/CD mode | `false` |
| `AITHERZERO_PROFILE` | Configuration profile | `Standard` |
| `AITHERZERO_LOG_LEVEL` | Logging level | `Warning` |
| `AITHERZERO_DISABLE_TRANSCRIPT` | Disable transcript logging | `1` |

**Using with Docker Compose:**

Edit `docker-compose.yml`:

```yaml
services:
  aitherzero:
    environment:
      - AITHERZERO_PROFILE=Developer
      - AITHERZERO_LOG_LEVEL=Verbose
```

### Custom Configuration Files

```bash
# Mount custom config
docker run --rm \
  -v $(pwd)/my-config.psd1:/app/config.psd1:ro \
  aitherzero:latest pwsh -Command "./Start-AitherZero.ps1"

# Using Docker Compose, add to volumes:
services:
  aitherzero:
    volumes:
      - ./my-config.psd1:/app/config.psd1:ro
```

### Resource Limits

**Set CPU and memory limits:**

```bash
# Docker CLI
docker run --rm \
  --cpus=2 \
  --memory=2g \
  aitherzero:latest pwsh -Command "./az.ps1 0402"

# Docker Compose (already configured in docker-compose.yml)
services:
  aitherzero:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## 🐛 Troubleshooting

### Container Won't Start

**Problem**: Container exits immediately

```bash
# Check container logs
docker logs <container-id>

# Run with interactive shell to debug
docker run -it --rm aitherzero:latest /bin/bash

# Check health status
docker inspect aitherzero:latest --format='{{.State.Health.Status}}'
```

**Common causes:**
- Dockerfile syntax errors → Check build logs
- Missing dependencies → Rebuild with `--no-cache`
- Port conflicts → Use different port mapping

### Permission Issues

**Problem**: Permission denied errors in container

```bash
# Container runs as non-root user (aitherzero)
# Check file ownership
docker run --rm aitherzero:latest ls -la /app

# If mounting volumes, ensure correct permissions:
chmod -R 755 ./logs ./reports
```

### Module Loading Errors

**Problem**: PowerShell modules not loading

```bash
# Verify module files exist
docker run --rm aitherzero:latest ls -la /app/domains

# Test module import manually
docker run --rm aitherzero:latest pwsh -Command " \
  Import-Module /app/AitherZero.psd1 -Verbose; \
  Get-Module \
"

# Check PowerShell version
docker run --rm aitherzero:latest pwsh -Command '$PSVersionTable'
```

### Network Issues

**Problem**: Cannot access external resources

```bash
# Test connectivity
docker run --rm aitherzero:latest ping -c 3 google.com

# Check DNS resolution
docker run --rm aitherzero:latest nslookup github.com

# Run with host network (bypasses Docker network)
docker run --rm --network=host aitherzero:latest pwsh
```

### Build Failures

**Problem**: Docker build fails

```bash
# Build with verbose output
docker build -t aitherzero:latest --progress=plain .

# Build with no cache
docker build -t aitherzero:latest --no-cache .

# Check disk space
docker system df

# Clean up old images
docker system prune -a
```

### Performance Issues

**Problem**: Container runs slowly

```bash
# Check resource usage
docker stats <container-id>

# Increase allocated resources
docker run --rm \
  --cpus=4 \
  --memory=4g \
  aitherzero:latest pwsh -Command "./az.ps1 0402"

# Check Docker daemon settings
docker info
```

## 🔍 Inspecting the Container

### View Container Details

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Inspect container configuration
docker inspect <container-id>

# View container resource usage
docker stats <container-id>

# View container processes
docker top <container-id>
```

### Accessing Logs

```bash
# View logs
docker logs <container-id>

# Follow logs in real-time
docker logs -f <container-id>

# View last 50 lines
docker logs --tail 50 <container-id>

# View logs with timestamps
docker logs -t <container-id>

# Docker Compose logs
docker-compose logs -f aitherzero
```

### File System Access

```bash
# Copy files from container
docker cp <container-id>:/app/logs ./local-logs
docker cp <container-id>:/app/reports/test-results.xml ./

# Copy files to container
docker cp ./my-script.ps1 <container-id>:/app/automation-scripts/

# Browse container filesystem
docker run --rm -it aitherzero:latest /bin/bash
ls -la /app
```

## 🧹 Cleanup

### Remove Containers

```bash
# Stop and remove all AitherZero containers
docker-compose down

# Remove specific container
docker rm -f <container-id>

# Remove all stopped containers
docker container prune
```

### Remove Images

```bash
# Remove specific image
docker rmi aitherzero:latest

# Remove all AitherZero images
docker images | grep aitherzero | awk '{print $3}' | xargs docker rmi

# Remove unused images
docker image prune -a
```

### Remove Volumes

```bash
# Remove Docker Compose volumes
docker-compose down -v

# Remove specific volume
docker volume rm aitherzero-logs

# Remove all unused volumes
docker volume prune
```

### Complete Cleanup

```bash
# WARNING: This removes ALL Docker resources (not just AitherZero)
docker system prune -a --volumes

# Safer: Remove only AitherZero resources
docker-compose down -v
docker rmi $(docker images | grep aitherzero | awk '{print $3}')
```

## 📚 Advanced Usage

### Multi-Stage Builds

The Dockerfile uses multi-stage builds for optimization. To customize:

```dockerfile
# Build only the base stage
docker build --target base -t aitherzero:base .
```

### Custom Base Images

```bash
# Use a different PowerShell base
docker build \
  --build-arg BASE_IMAGE=mcr.microsoft.com/powershell:7.4-alpine-3.19 \
  -t aitherzero:alpine .
```

### Debugging

```bash
# Run with debug output
docker run --rm \
  -e AITHERZERO_LOG_LEVEL=Verbose \
  aitherzero:latest pwsh -Command './az.ps1 0402'

# Attach to running container
docker exec -it <container-id> pwsh

# Run shell for debugging
docker run --rm -it aitherzero:latest /bin/bash
```

### Security Scanning

```bash
# Scan image for vulnerabilities (requires trivy)
trivy image aitherzero:latest

# Scan with Docker Scout (if available)
docker scout cves aitherzero:latest
```

## 🎓 Best Practices

1. **Use Docker Compose for development** - Easier to manage volumes and services
2. **Mount code as volumes** - Faster iteration without rebuilding
3. **Use named volumes for persistence** - Logs and reports survive container restarts
4. **Set resource limits** - Prevent container from consuming all system resources
5. **Run as non-root** - Container already configured with `aitherzero` user
6. **Keep images updated** - Regularly rebuild to get security updates
7. **Use .dockerignore** - Reduce build context size and speed up builds
8. **Tag your images** - Use semantic versioning for tracking
9. **Clean up regularly** - Remove unused containers, images, and volumes
10. **Test in container first** - Catch cross-platform issues early

## 🔗 Related Documentation

- [PR Deployment Guide](PR-DEPLOYMENT-GUIDE.md) - Using Docker in CI/CD workflows
- [Development Setup](DEVELOPMENT-SETUP.md) - Local development environment
- [Main README](../README.md) - General AitherZero documentation
- [Docker Documentation](https://docs.docker.com/) - Official Docker docs
- [PowerShell in Docker](https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian) - Microsoft PowerShell docs

## 📞 Support

If you encounter issues with the Docker container:

1. Check this troubleshooting section
2. Review [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
3. Search [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
4. Create a new issue with:
   - Docker version (`docker --version`)
   - Host OS and version
   - Full error messages
   - Steps to reproduce

---

**Last Updated**: 2025-10-28  
**Docker Image Version**: Based on PowerShell 7.4 (Ubuntu 22.04)  
**Maintainers**: AitherZero Team
