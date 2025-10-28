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
docker exec aitherzero-app pwsh -Command "./az.ps1 0402"

# Run PSScriptAnalyzer
docker exec aitherzero-app pwsh -Command "./az.ps1 0404"

# Run syntax validation
docker exec aitherzero-app pwsh -Command "./az.ps1 0407"

# Generate project report
docker exec aitherzero-app pwsh -Command "./az.ps1 0510 -ShowAll"
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
Import-Module /app/AitherZero.psd1 -Verbose

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
                        pwsh -Command "./az.ps1 0402"
                '''
            }
        }
        
        stage('Report') {
            steps {
                sh '''
                    docker-compose run --rm aitherzero \
                        pwsh -Command "./az.ps1 0510 -ShowAll"
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
