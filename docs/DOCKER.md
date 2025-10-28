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

> **Note:** Container image names use lowercase per Docker conventions.

```bash
# When available, you'll be able to pull pre-built images from GitHub Container Registry:
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
docker run --rm aitherzero:latest pwsh -Command "az 0402"

# Run syntax validation
docker run --rm aitherzero:latest pwsh -Command "az 0407"

# Run PSScriptAnalyzer
docker run --rm aitherzero:latest pwsh -Command "az 0404"

# Generate project report
docker run --rm aitherzero:latest pwsh -Command "az 0510 -ShowAll"
```

**Using Docker Compose:**

```bash
# Start the container in background
docker-compose up -d

# Run commands
docker-compose exec aitherzero pwsh -Command "az 0402"
docker-compose exec aitherzero pwsh -Command "az 0404"

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
docker-compose exec aitherzero pwsh -Command "az 0402"

# 4. Run quality checks
docker-compose exec aitherzero pwsh -Command "az 0404"

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
  az 0407 && \
  az 0404 && \
  az 0402 \
"

# Run with exit code handling
docker run --rm aitherzero:latest pwsh -Command " \
  \$ErrorActionPreference = 'Stop'; \
  az 0402; \
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
  aitherzero:latest pwsh -Command "az 0402"
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
```

**Using Docker Compose, add to `docker-compose.yml`:**

```yaml
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
  aitherzero:latest pwsh -Command "az 0402"
```

**Docker Compose (already configured in `docker-compose.yml`):**

```yaml
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
  Import-Module /opt/aitherzero/AitherZero.psd1 -Verbose; \
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
  aitherzero:latest pwsh -Command "az 0402"

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

> **Note:**  
> The official AitherZero Docker image is based on PowerShell 7.4 (Ubuntu 22.04).  
> Using alternative base images (such as Alpine) is for advanced/custom builds only and may require Dockerfile modifications for compatibility (e.g., package installation, dependency changes). Alpine is **not officially supported** and may not work out-of-the-box.

```bash
# Use a different PowerShell base (custom build; may require Dockerfile changes)
docker build \
  --build-arg BASE_IMAGE=mcr.microsoft.com/powershell:7.4-alpine-3.19 \
  -t aitherzero:alpine .
```

### Debugging

```bash
# Run with debug output
docker run --rm \
  -e AITHERZERO_LOG_LEVEL=Verbose \
  aitherzero:latest pwsh -Command 'az 0402'

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
=======
# 🐳 Docker Usage Guide

## Overview

AitherZero provides Docker containers for consistent, isolated environments across development, testing, and CI/CD workflows. This guide covers building, running, and managing AitherZero in Docker containers.

## Quick Start

### Prerequisites

- **Docker Engine** 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose** 2.0+ (included with Docker Desktop)

#### Installing Docker on Linux

**Ubuntu/Debian (APT):**
```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Fedora/RHEL/CentOS (DNF/YUM):**
```bash
# Fedora (using moby-engine - Docker's open-source version)
sudo dnf install -y moby-engine docker-compose

# Or use Docker's official repository
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group (requires logout/login to take effect)
sudo usermod -aG docker $USER
```

**Arch Linux (Pacman):**
```bash
sudo pacman -S docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**Note**: After installation, you may need to log out and back in for group membership changes to take effect, or run `newgrp docker` to activate the group in your current session.

### Fastest Start

```bash
# Clone the repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Start with Docker Compose
docker-compose up -d

# Access the container
docker exec -it aitherzero-app pwsh

# Inside container, start AitherZero
Start-AitherZero
```

## Container Architecture

### Main Service: `aitherzero`

The primary container runs PowerShell 7.4 on Ubuntu 22.04 with:
- Complete AitherZero module installation
- Git, curl, wget, and SSH client
- Pester and PSScriptAnalyzer
- Non-root user (`aitherzero`) for security
- Persistent volumes for logs, reports, and test results

### Optional Services

Enable additional services using profiles:

- **Redis Cache** (`with-cache` profile): For future caching features
- **PostgreSQL Database** (`with-database` profile): For future data persistence

## Building the Container

### Build with Docker

```bash
# Build the image
docker build -t aitherzero:latest .

# Build with custom tag
docker build -t aitherzero:dev .

# Build with no cache (clean build)
docker build --no-cache -t aitherzero:latest .
```

### Build with Docker Compose

```bash
# Build the image
docker-compose build

# Build without cache
docker-compose build --no-cache

# Build with specific service
docker-compose build aitherzero
```

## Running the Container

### Using Docker Compose (Recommended)

#### Basic Usage

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f aitherzero

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

#### With Optional Services

```bash
# Start with Redis cache
docker-compose --profile with-cache up -d

# Start with PostgreSQL database
docker-compose --profile with-database up -d

# Start with both cache and database
docker-compose --profile with-cache --profile with-database up -d
```

### Using Docker Directly

```bash
# Run interactively
docker run -it --rm \
  --name aitherzero \
  -v aitherzero-logs:/app/logs \
  -v aitherzero-reports:/app/reports \
  aitherzero:latest

# Run in detached mode
docker run -d \
  --name aitherzero \
  -v aitherzero-logs:/app/logs \
  -v aitherzero-reports:/app/reports \
  aitherzero:latest

# Run with custom command
docker run -it --rm \
  aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode List"
```

## Environment Configuration

### Environment Variables

Configure AitherZero behavior using environment variables:

```bash
# Set in docker-compose.yml or via -e flag
AITHERZERO_ROOT=/app                    # Installation root (default: /app)
AITHERZERO_NONINTERACTIVE=false         # Run in non-interactive mode
AITHERZERO_CI=false # Enable CI mode
AITHERZERO_PROFILE=Standard # Profile: Minimal, Standard, Developer, Full
DEPLOYMENT_ENVIRONMENT=development # Environment: development, staging, production
PR_NUMBER= # PR number for PR deployments
BRANCH_NAME=main # Git branch name
COMMIT_SHA= # Git commit SHA
```

### Using .env File

Create a `.env` file in the project root:

```bash
# Copy the example
cp .env.example .env

# Edit with your values
nano .env
```

Docker Compose automatically loads `.env` files.

### Example .env File

```env
# AitherZero Configuration
AITHERZERO_NONINTERACTIVE=false
AITHERZERO_CI=false
AITHERZERO_PROFILE=Developer

# Deployment Context
DEPLOYMENT_ENVIRONMENT=development
BRANCH_NAME=main

# Optional Database Password (for with-database profile)
POSTGRES_PASSWORD=secure_password_here
```

## Common Workflows

### Interactive Development

```bash
# Start the container
docker-compose up -d

# Access PowerShell shell
docker exec -it aitherzero-app pwsh

# Inside container - run commands
Start-AitherZero
az 0402  # Run unit tests
az 0510 -ShowAll  # Generate reports
```

### Running Specific Scripts

```bash
# Run validation tests
docker exec aitherzero-app pwsh -Command "az 0402"

# Run PSScriptAnalyzer
docker exec aitherzero-app pwsh -Command "az 0404"

# Run syntax validation
docker exec aitherzero-app pwsh -Command "az 0407"

# Generate project report
docker exec aitherzero-app pwsh -Command "az 0510 -ShowAll"
```

### Running Orchestration Playbooks

```bash
# Quick test playbook
docker exec aitherzero-app pwsh -Command \
  "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"

# Full test playbook
docker exec aitherzero-app pwsh -Command \
  "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full"
```

### CI/CD Integration

```bash
# Run in CI mode with non-interactive flag
docker run --rm \
  -e AITHERZERO_CI=true \
  -e AITHERZERO_NONINTERACTIVE=true \
  aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full"
```

### Local Development with Hot Reload

Uncomment the volume mount in `docker-compose.yml`:

```yaml
volumes:
  # Uncomment for local development with hot-reload
  - .:/app:rw
```

Then:

```bash
# Start with local code mounted
docker-compose up -d

# Changes to local files reflect immediately in container
docker exec -it aitherzero-app pwsh
```

⚠️ **Warning**: Only use this for local development. Never mount source code in PR or production environments.

## Volume Management

### Persistent Volumes

Docker Compose creates named volumes for persistence:

- `aitherzero-logs`: Log files
- `aitherzero-reports`: Generated reports
- `aitherzero-results`: Test results
- `aitherzero-redis`: Redis data (when using `with-cache` profile)
- `aitherzero-postgres`: PostgreSQL data (when using `with-database` profile)

### Managing Volumes

```bash
# List volumes
docker volume ls | grep aitherzero

# Inspect a volume
docker volume inspect aitherzero-logs

# Copy files from volume
docker run --rm -v aitherzero-logs:/data -v $(pwd):/backup ubuntu tar czf /backup/logs-backup.tar.gz /data

# Remove all volumes (caution: deletes data)
docker-compose down -v
```

### Accessing Volume Data

```bash
# View logs
docker exec aitherzero-app ls -la /app/logs

# Copy logs to host
docker cp aitherzero-app:/app/logs ./local-logs

# View reports
docker exec aitherzero-app ls -la /app/reports
```

## Resource Management

### Default Resource Limits

Configure in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'          # Maximum 2 CPU cores
      memory: 2G         # Maximum 2GB RAM
    reservations:
      cpus: '0.5'        # Reserve 0.5 CPU core
      memory: 512M       # Reserve 512MB RAM
```

### Monitoring Resources

```bash
# View container resource usage
docker stats aitherzero-app

# View all containers
docker stats

# One-time stats
docker stats --no-stream aitherzero-app
```

### Adjusting Resources

Edit `docker-compose.yml` to change resource limits, then:

```bash
# Recreate container with new limits
docker-compose up -d --force-recreate
```

## Networking

### Default Network

Docker Compose creates an isolated bridge network (`aitherzero-network`) with subnet `172.28.0.0/16`.

### Port Exposure

By default, ports 8080 and 8443 are exposed for future web interfaces.

### Custom Ports

Add to `docker-compose.yml`:

```yaml
ports:
  - "8080:8080"  # HTTP
  - "8443:8443"  # HTTPS
```

### Connecting Services

Services can communicate using service names:

```bash
# From aitherzero container to redis
redis-cli -h redis -p 6379

# From aitherzero container to postgres
psql -h postgres -U aitherzero -d aitherzero
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs aitherzero

# Check detailed logs
docker logs aitherzero-app --tail 100

# Check container status
docker-compose ps
```

### Module Not Loading

```bash
# Access container
docker exec -it aitherzero-app pwsh

# Manually import module
Import-Module /opt/aitherzero/AitherZero.psd1 -Verbose

# Check module
Get-Module AitherZero
```

### Permission Issues

```bash
# Check ownership
docker exec aitherzero-app ls -la /app

# Fix permissions (if needed)
docker exec -u root aitherzero-app chown -R aitherzero:aitherzero /app
```

### Out of Disk Space

```bash
# Remove unused containers and images
docker system prune -a

# Remove unused volumes
docker volume prune

# Check disk usage
docker system df
```

### Health Check Failing

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' aitherzero-app

# View health check logs
docker inspect --format='{{json .State.Health}}' aitherzero-app | jq
```

## Security Considerations

### Non-Root User

The container runs as the `aitherzero` user (non-root) for security. If you need root access:

```bash
# Access as root
docker exec -it -u root aitherzero-app bash
```

### Secrets Management

⚠️ **Never commit secrets to the repository or Dockerfile**

Use Docker secrets or environment variables:

```bash
# Pass secrets as environment variables
docker run -e GITHUB_TOKEN=your_token aitherzero:latest

# Use Docker secrets (Swarm mode)
echo "my_secret" | docker secret create my_secret -
```

### Git Credentials

For local development, you can mount Git credentials (commented out by default in `docker-compose.yml`):

```yaml
volumes:
  # SECURITY WARNING: Only for local development
  - ~/.gitconfig:/home/aitherzero/.gitconfig:ro
  - ~/.ssh:/home/aitherzero/.ssh:ro
```

⚠️ **Never mount SSH keys or credentials in CI/CD or PR environments.** Use deployment keys or token-based authentication instead.

### Network Isolation

The container runs in an isolated Docker network. Only expose ports you need:

```yaml
ports:
  - "127.0.0.1:8080:8080"  # Only localhost can access
```

## Production Considerations

### Image Tagging

Use semantic versioning for production:

```bash
# Build with version tag
docker build -t aitherzero:1.0.0 .
docker build -t aitherzero:1.0 .
docker build -t aitherzero:latest .

# Push to registry
docker tag aitherzero:1.0.0 myregistry/aitherzero:1.0.0
docker push myregistry/aitherzero:1.0.0
```

### Multi-Stage Builds

The Dockerfile uses multi-stage builds for optimized image size. The current image is ~500MB.

### Container Registry

For production deployments, push to a container registry:

```bash
# Docker Hub
docker tag aitherzero:latest username/aitherzero:latest
docker push username/aitherzero:latest

# GitHub Container Registry
docker tag aitherzero:latest ghcr.io/wizzense/aitherzero:latest
docker push ghcr.io/wizzense/aitherzero:latest

# Azure Container Registry
docker tag aitherzero:latest myregistry.azurecr.io/aitherzero:latest
docker push myregistry.azurecr.io/aitherzero:latest
```

### Healthchecks

The container includes a health check that verifies the module manifest exists. Monitor health in production:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' aitherzero-app

# In Kubernetes
kubectl describe pod aitherzero-pod
```

### Logging

Configure logging drivers for production:

```yaml
services:
  aitherzero:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Advanced Usage

### Custom Configuration

Mount a custom configuration file:

```bash
docker run -v /path/to/config.psd1:/app/config.psd1:ro aitherzero:latest
```

### Multi-Container Orchestration

Use Docker Compose profiles for different deployment scenarios:

```bash
# Development environment (no extra services)
docker-compose up -d

# Testing environment (with cache)
docker-compose --profile with-cache up -d

# Full stack (all services)
docker-compose --profile with-cache --profile with-database up -d
```

### Building for Different Architectures

```bash
# Build for ARM64 (Apple Silicon)
docker buildx build --platform linux/arm64 -t aitherzero:arm64 .

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 -t aitherzero:multiarch .
```

### Custom Entry Points

Override the default command:

```bash
# Run specific playbook
docker run --rm aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"

# Run interactive PowerShell
docker run -it --rm aitherzero:latest pwsh

# Run bash shell
docker run -it --rm aitherzero:latest bash
```

## Integration Examples

### GitHub Actions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: docker-compose build
      
      - name: Run tests
        run: |
          docker-compose run --rm aitherzero \
            pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full"
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: tests/results/
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'docker-compose build'
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    docker-compose run --rm aitherzero \
                        pwsh -Command "az 0402"
                '''
            }
        }
        
        stage('Report') {
            steps {
                sh '''
                    docker-compose run --rm aitherzero \
                        pwsh -Command "az 0510 -ShowAll"
                '''
            }
        }
    }
    
    post {
        always {
            sh 'docker-compose down -v'
        }
    }
}
```

### Azure Pipelines

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Docker@2
  displayName: 'Build container'
  inputs:
    command: build
    Dockerfile: Dockerfile
    tags: |
      latest
      $(Build.BuildId)

- script: |
    docker-compose run --rm aitherzero \
      pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full"
  displayName: 'Run tests'

- task: PublishTestResults@2
  displayName: 'Publish test results'
  inputs:
    testResultsFormat: 'NUnit'
    testResultsFiles: '**/test-results.xml'
```

## Best Practices

### Development

1. **Use Docker Compose** for local development (easier than raw Docker commands)
2. **Mount volumes** for persistent data (logs, reports)
3. **Use .env files** for configuration (don't hardcode values)
4. **Tag images** with meaningful versions (not just `latest`)
5. **Clean up regularly** (`docker system prune` to reclaim space)

### Testing

1. **Use fresh containers** for each test run (`--rm` flag)
2. **Set AITHERZERO_CI=true** for CI environments
3. **Capture logs and reports** (mount volume or copy with `docker cp`)
4. **Test in isolation** (don't rely on host environment)
5. **Validate health checks** before running tests

### Production

1. **Use specific version tags** (not `latest`)
2. **Enable health checks** and monitor them
3. **Set resource limits** (CPU, memory)
4. **Configure logging drivers** (don't fill disk with logs)
5. **Use secrets management** (not environment variables for sensitive data)
6. **Run as non-root** (already configured by default)
7. **Scan for vulnerabilities** (use Trivy or similar tools)
8. **Use read-only root filesystem** where possible

## Further Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PowerShell in Docker](https://hub.docker.com/_/microsoft-powershell)
- [AitherZero Main Documentation](../README.md)
- [AitherZero CI/CD Guide](CI-CD-GUIDE.md)
- [AitherZero PR Deployment Guide](PR-DEPLOYMENT-GUIDE.md)

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review container logs: `docker-compose logs aitherzero`
3. Search existing [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
4. Open a new issue with:
   - Docker version (`docker --version`)
   - Docker Compose version (`docker-compose --version`)
   - Error messages
   - Steps to reproduce

---

**Last Updated**: 2025-10-28  
**Docker Image Version**: Based on PowerShell 7.4 (Ubuntu 22.04)  
**Maintainers**: AitherZero Team

