# Self-Hosted GitHub Actions Runner Setup Guide

This guide explains how to set up a self-hosted GitHub Actions runner with a persistent deployment of AitherZero's main branch.

## 📋 Overview

The self-hosted runner setup provides:

- **Persistent Runner**: A GitHub Actions runner that runs continuously on your infrastructure
- **Main Branch Deployment**: Automatically updated deployment of the main branch
- **Docker-Based**: Uses Docker containers for isolation and easy management
- **Auto-Updates**: Automatically pulls and deploys latest main branch changes
- **Health Monitoring**: Systemd service with automatic restarts

## 🎯 Architecture

```
┌─────────────────────────────────────────────────┐
│ Host System (Linux Server/VM)                  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ Self-Hosted Runner Container              │  │
│  │ - Monitors GitHub for jobs               │  │
│  │ - Executes workflows                     │  │
│  │ - Has Docker-in-Docker capability        │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ AitherZero Main Deployment Container     │  │
│  │ - Always running main branch             │  │
│  │ - Auto-updates on push to main           │  │
│  │ - Accessible via port 8080               │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ Systemd Service                          │  │
│  │ - Manages containers lifecycle           │  │
│  │ - Auto-restart on failure                │  │
│  │ - Logs to journald                       │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 🔧 Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 22.04+ recommended)
- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 20GB minimum free space
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+

### GitHub Repository Access

You'll need:
1. **Repository Admin Access**: To register the runner
2. **GitHub Personal Access Token (PAT)**: With `repo` scope for private repos or `public_repo` for public repos
   - Create at: https://github.com/settings/tokens/new
   - Required scopes: `repo`, `workflow`, `admin:org` (if org-level runner)

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
# On your host system
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
```

### Step 2: Configure Runner

```bash
# Set up your runner configuration
cd infrastructure/self-hosted-runner

# Copy and edit the configuration file
cp .env.example .env
nano .env
```

Edit `.env` with your settings:
```bash
# GitHub Configuration
GITHUB_OWNER=wizzense
GITHUB_REPO=AitherZero
GITHUB_TOKEN=your_github_personal_access_token

# Runner Configuration
RUNNER_NAME=aitherzero-prod-runner
RUNNER_LABELS=self-hosted,linux,x64,aitherzero
RUNNER_WORKDIR=/runner/_work

# Deployment Configuration
DEPLOYMENT_PORT=8080
DEPLOYMENT_AUTO_UPDATE=true
```

### Step 3: Install Runner

```bash
# Run the installation script
sudo ./install-runner.sh

# This will:
# - Install Docker and Docker Compose if needed
# - Create necessary directories
# - Set up systemd service
# - Start the runner and deployment containers
```

### Step 4: Verify Installation

```bash
# Check service status
sudo systemctl status aitherzero-runner

# View runner logs
sudo journalctl -u aitherzero-runner -f

# Check containers
docker ps | grep aitherzero

# Test main deployment
curl http://localhost:8080
```

### Step 5: Register Runner in GitHub

The runner should automatically appear in your repository:
1. Go to `https://github.com/wizzense/AitherZero/settings/actions/runners`
2. You should see your runner listed as "Idle" or "Active"

## 📦 What Gets Installed

### 1. Docker Containers

**Self-Hosted Runner Container** (`aitherzero-runner`):
- Based on `myoung34/github-runner:latest`
- Runs GitHub Actions jobs
- Has Docker-in-Docker capability
- Auto-restarts on failure

**Main Deployment Container** (`aitherzero-main`):
- Runs the latest main branch code
- Exposed on port 8080
- Auto-updates when main branch changes
- Includes web dashboard

### 2. Systemd Service

**Service Name**: `aitherzero-runner.service`
- Manages all containers
- Auto-starts on boot
- Auto-restarts on failure
- Integrated logging

### 3. File Structure

```
/opt/aitherzero-runner/
├── .env                    # Configuration
├── docker-compose.yml      # Container definitions
├── data/                   # Persistent data
│   ├── runner/            # Runner workspace
│   ├── deployment/        # Deployment data
│   └── logs/              # Application logs
└── scripts/
    ├── update-main.sh     # Manual update script
    └── health-check.sh    # Health monitoring
```

## 🔄 Auto-Update Workflow

The repository includes a workflow that automatically updates the main deployment:

**Workflow**: `.github/workflows/update-self-hosted-deployment.yml`

**Triggers**:
- Push to main branch
- Manual trigger via workflow_dispatch
- Scheduled daily at 2 AM UTC

**Actions**:
1. Pulls latest main branch code
2. Rebuilds Docker image
3. Restarts deployment container
4. Runs health checks
5. Reports status

## 🛠️ Management Commands

### Service Management

```bash
# Start the runner
sudo systemctl start aitherzero-runner

# Stop the runner
sudo systemctl stop aitherzero-runner

# Restart the runner
sudo systemctl restart aitherzero-runner

# View status
sudo systemctl status aitherzero-runner

# Enable auto-start on boot
sudo systemctl enable aitherzero-runner

# Disable auto-start
sudo systemctl disable aitherzero-runner
```

### Manual Updates

```bash
# Update main deployment manually
cd /opt/aitherzero-runner
sudo ./scripts/update-main.sh

# Pull latest runner image
docker pull myoung34/github-runner:latest
sudo systemctl restart aitherzero-runner
```

### View Logs

```bash
# Service logs
sudo journalctl -u aitherzero-runner -f

# Runner container logs
docker logs -f aitherzero-runner

# Deployment container logs
docker logs -f aitherzero-main

# All logs
docker-compose -f /opt/aitherzero-runner/docker-compose.yml logs -f
```

### Health Checks

```bash
# Run health check script
/opt/aitherzero-runner/scripts/health-check.sh

# Check runner connectivity
curl http://localhost:8080/health

# Check GitHub API connectivity
docker exec aitherzero-runner curl -s https://api.github.com/rate_limit
```

## 🔒 Security Considerations

### Network Security

```bash
# Restrict port access (example using ufw)
sudo ufw allow from 192.168.1.0/24 to any port 8080  # Local network only
sudo ufw enable
```

### Token Security

- Store GitHub token in `.env` file with restricted permissions
- Never commit `.env` to version control
- Rotate tokens regularly
- Use organization-level runners for better security

```bash
# Secure the .env file
sudo chmod 600 /opt/aitherzero-runner/.env
sudo chown root:root /opt/aitherzero-runner/.env
```

### Container Security

```bash
# Run containers as non-root user (configured in docker-compose.yml)
# Enable Docker content trust
export DOCKER_CONTENT_TRUST=1

# Scan images for vulnerabilities
docker scan aitherzero:main
```

### Runner Sudo Permissions

The auto-update workflow requires sudo access to run deployment scripts. Configure limited sudo permissions for security:

```bash
# Create sudoers entry for the runner user (replace 'runner' with actual username)
echo 'runner ALL=(ALL) NOPASSWD: /opt/aitherzero-runner/scripts/update-main.sh' | sudo tee /etc/sudoers.d/aitherzero-runner
sudo chmod 440 /etc/sudoers.d/aitherzero-runner

# Verify the configuration
sudo visudo -c
```

**Security Benefits:**
- Runner can only execute specific script, not any sudo command
- No password required (NOPASSWD) for automated workflows
- Full path prevents PATH manipulation attacks
- Limited to single script with known functionality

## 🔥 Troubleshooting

### Runner Not Appearing in GitHub

**Problem**: Runner doesn't show up in GitHub settings

**Solutions**:
1. Check token permissions: `repo`, `workflow`, `admin:org`
2. Verify token hasn't expired
3. Check runner logs: `docker logs aitherzero-runner`
4. Ensure network connectivity to GitHub
5. Verify organization settings allow self-hosted runners

### Runner Goes Offline

**Problem**: Runner shows as offline in GitHub

**Solutions**:
```bash
# Check service status
sudo systemctl status aitherzero-runner

# Restart service
sudo systemctl restart aitherzero-runner

# Check container status
docker ps -a | grep aitherzero-runner

# View recent logs
sudo journalctl -u aitherzero-runner -n 100
```

### Deployment Container Fails to Start

**Problem**: Main deployment container won't start

**Solutions**:
```bash
# Check container logs
docker logs aitherzero-main

# Verify Docker image
docker images | grep aitherzero

# Rebuild image
cd /opt/aitherzero-runner
docker-compose build --no-cache aitherzero-main
docker-compose up -d aitherzero-main

# Check port conflicts
sudo netstat -tlnp | grep 8080
```

### Out of Disk Space

**Problem**: System runs out of disk space

**Solutions**:
```bash
# Clean up Docker resources
docker system prune -a --volumes

# Check disk usage
df -h
du -sh /opt/aitherzero-runner/*

# Clean old logs
sudo journalctl --vacuum-time=7d

# Clean runner workspace
rm -rf /opt/aitherzero-runner/data/runner/_work/*/_temp
```

### SSL/TLS Certificate Errors

**Problem**: Certificate validation errors

**Solutions**:
```bash
# Update CA certificates
sudo apt-get update
sudo apt-get install -y ca-certificates
sudo update-ca-certificates

# Test GitHub connectivity
curl -v https://api.github.com
```

## 📊 Monitoring

### Prometheus Metrics (Optional)

Add Prometheus monitoring:

```yaml
# Add to docker-compose.yml
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

### Grafana Dashboard (Optional)

Add Grafana for visualization:

```yaml
# Add to docker-compose.yml
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

## 🔄 Updating the Runner

### Update Runner Software

```bash
# Pull latest runner image
docker pull myoung34/github-runner:latest

# Restart service to apply update
sudo systemctl restart aitherzero-runner
```

### Update AitherZero Deployment

The deployment automatically updates when main branch changes. For manual update:

```bash
cd /opt/aitherzero-runner
sudo ./scripts/update-main.sh
```

## 🗑️ Uninstallation

To completely remove the self-hosted runner:

```bash
# Stop and disable service
sudo systemctl stop aitherzero-runner
sudo systemctl disable aitherzero-runner

# Remove service file
sudo rm /etc/systemd/system/aitherzero-runner.service
sudo systemctl daemon-reload

# Remove containers
cd /opt/aitherzero-runner
docker-compose down -v

# Remove installation directory
sudo rm -rf /opt/aitherzero-runner

# Remove Docker images (optional)
docker rmi $(docker images -q aitherzero)
```

## 💡 Best Practices

1. **Regular Updates**: Keep runner and deployment images updated
2. **Monitor Resources**: Set up monitoring for CPU, memory, disk usage
3. **Backup Configuration**: Keep backups of `.env` and custom configurations
4. **Log Rotation**: Configure log rotation to prevent disk filling
5. **Security Patches**: Regularly update host OS and Docker
6. **Token Rotation**: Rotate GitHub tokens every 90 days
7. **Test Updates**: Test runner updates in non-production first
8. **Documentation**: Document any customizations you make

## 📚 Additional Resources

- [GitHub Self-Hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AitherZero Main Documentation](../README.md)
- [Docker Usage Guide](./DOCKER.md)

## 🆘 Support

For issues or questions:
1. Check troubleshooting section above
2. Review GitHub Actions runner logs
3. Check AitherZero issues: https://github.com/wizzense/AitherZero/issues
4. Create new issue with `self-hosted-runner` label

## 📝 Changelog

- **2025-01-28**: Initial self-hosted runner setup guide created
