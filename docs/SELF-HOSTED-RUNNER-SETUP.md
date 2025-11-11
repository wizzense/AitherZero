# 🏃 Self-Hosted GitHub Actions Runner Setup Guide

## Overview

This guide provides comprehensive instructions for deploying AitherZero GitHub Actions workflows on self-hosted runners. Self-hosted runners give you complete control over the build environment, better performance, and cost savings for private repositories.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Runner Architecture](#runner-architecture)
3. [Installation Methods](#installation-methods)
4. [Configuration](#configuration)
5. [Security Considerations](#security-considerations)
6. [Docker-Based Runner](#docker-based-runner)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

**Minimum:**
- **OS**: Windows Server 2019+, Ubuntu 20.04+, or macOS 11+
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 20 GB free space
- **Network**: Stable internet connection (1 Mbps+ upload/download)

**Recommended (for AitherZero):**
- **OS**: Ubuntu 22.04 LTS or Windows Server 2022
- **CPU**: 4-8 cores
- **RAM**: 8-16 GB
- **Disk**: 50-100 GB SSD
- **Network**: 10 Mbps+ connection

### Software Requirements

**Linux:**
```bash
# Required packages
sudo apt-get update
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    tar \
    unzip \
    docker.io \
    docker-compose

# PowerShell 7.4+
wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb
sudo dpkg -i powershell_7.4.0-1.deb_amd64.deb
sudo apt-get install -f

# Verify installations
pwsh --version
docker --version
git --version
```

**Windows:**
```powershell
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required software
choco install -y git docker-desktop powershell-core

# Verify installations
pwsh --version
docker --version
git --version
```

---

## Runner Architecture

### Deployment Options

AitherZero supports three deployment models for self-hosted runners:

```
┌─────────────────────────────────────────────────────────────┐
│                    Self-Hosted Runner Options                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Bare Metal / VM Runner                                   │
│     ├─ Direct installation on server                         │
│     ├─ Best for: Dedicated build servers                     │
│     └─ Performance: Highest                                   │
│                                                               │
│  2. Docker Container Runner                                   │
│     ├─ Containerized runner environment                      │
│     ├─ Best for: Development/testing                         │
│     └─ Performance: Medium, easy management                   │
│                                                               │
│  3. Kubernetes Pod Runner (Auto-scaling)                      │
│     ├─ Dynamic runner provisioning                           │
│     ├─ Best for: Production, variable load                   │
│     └─ Performance: Medium-High, auto-scales                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Installation Methods

### Method 1: Bare Metal / VM Installation

#### Step 1: Create Runner Directory

```bash
# Linux/macOS
mkdir -p ~/actions-runner && cd ~/actions-runner

# Windows
New-Item -ItemType Directory -Path "$HOME\actions-runner"
Set-Location "$HOME\actions-runner"
```

#### Step 2: Download GitHub Actions Runner

**Linux (x64):**
```bash
# Download latest runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Verify signature (optional but recommended)
echo "29fc8cf2dab4c195bb147384e7e2c94cfd4d4022c793b346a6175435265aa278  actions-runner-linux-x64-2.311.0.tar.gz" | shasum -a 256 -c
```

**Windows (x64):**
```powershell
# Download latest runner
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip" -OutFile "actions-runner-win-x64-2.311.0.zip"

# Extract
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.311.0.zip", "$PWD")
```

#### Step 3: Configure Runner

**For Repository-Level Runner:**
```bash
# Get your token from: https://github.com/YOUR_ORG/AitherZero/settings/actions/runners/new
./config.sh --url https://github.com/YOUR_ORG/AitherZero --token YOUR_TOKEN

# Windows
./config.cmd --url https://github.com/YOUR_ORG/AitherZero --token YOUR_TOKEN
```

**For Organization-Level Runner:**
```bash
# Get token from: https://github.com/organizations/YOUR_ORG/settings/actions/runners/new
./config.sh --url https://github.com/YOUR_ORG --token YOUR_TOKEN

# Windows
./config.cmd --url https://github.com/YOUR_ORG --token YOUR_TOKEN
```

Configuration prompts:
```
Enter the name of runner: [press Enter for default or type custom name]
  → aitherzero-runner-01

Enter any additional labels (comma-separated): [press Enter to skip]
  → aitherzero,powershell,docker

Enter name of work folder: [press Enter for _work]
  → _work
```

#### Step 4: Install as Service

**Linux (systemd):**
```bash
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

**Windows (Service):**
```powershell
# Run as Administrator
.\svc.cmd install
.\svc.cmd start
.\svc.cmd status
```

---

### Method 2: Docker Container Runner

#### Dockerfile for Self-Hosted Runner

Create `Dockerfile.runner`:

```dockerfile
FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    tar \
    unzip \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker (for docker-in-docker if needed)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install PowerShell 7.4+
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb && \
    dpkg -i powershell_7.4.0-1.deb_amd64.deb && \
    apt-get install -f -y && \
    rm powershell_7.4.0-1.deb_amd64.deb

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    usermod -aG docker runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to runner user
USER runner
WORKDIR /home/runner

# Download and install GitHub Actions Runner
RUN mkdir actions-runner && cd actions-runner && \
    curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
    https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz && \
    tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz && \
    rm actions-runner-linux-x64-2.311.0.tar.gz

WORKDIR /home/runner/actions-runner

# Copy entrypoint script
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

ENTRYPOINT ["/home/runner/entrypoint.sh"]
```

#### Create `entrypoint.sh`:

```bash
#!/bin/bash
set -e

# Check required environment variables
if [ -z "$GITHUB_URL" ]; then
    echo "ERROR: GITHUB_URL not set"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN not set"
    exit 1
fi

# Configure runner
./config.sh \
    --url "$GITHUB_URL" \
    --token "$GITHUB_TOKEN" \
    --name "${RUNNER_NAME:-aitherzero-docker-runner}" \
    --labels "${RUNNER_LABELS:-aitherzero,docker}" \
    --work "${RUNNER_WORKDIR:-_work}" \
    --unattended \
    --replace

# Cleanup on exit
cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token "$GITHUB_TOKEN"
}
trap 'cleanup' EXIT

# Start runner
./run.sh
```

#### Docker Compose Configuration

Create `docker-compose.runner.yml`:

```yaml
version: '3.8'

services:
  github-runner:
    build:
      context: .
      dockerfile: Dockerfile.runner
    container_name: aitherzero-runner
    environment:
      - GITHUB_URL=https://github.com/YOUR_ORG/AitherZero
      - GITHUB_TOKEN=${GITHUB_RUNNER_TOKEN}  # Set in .env file
      - RUNNER_NAME=aitherzero-docker-runner-01
      - RUNNER_LABELS=aitherzero,docker,powershell
      - RUNNER_WORKDIR=_work
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # For docker-in-docker
      - runner-work:/home/runner/actions-runner/_work
    restart: unless-stopped
    privileged: true  # Required for docker-in-docker
    networks:
      - runner-network

volumes:
  runner-work:

networks:
  runner-network:
    driver: bridge
```

#### Run Docker Runner:

```bash
# Build image
docker-compose -f docker-compose.runner.yml build

# Start runner
export GITHUB_RUNNER_TOKEN="your_token_here"
docker-compose -f docker-compose.runner.yml up -d

# View logs
docker-compose -f docker-compose.runner.yml logs -f

# Stop runner
docker-compose -f docker-compose.runner.yml down
```

---

### Method 3: Kubernetes Deployment

#### Using Actions Runner Controller (ARC)

**Install cert-manager (prerequisite):**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

**Install Actions Runner Controller:**
```bash
# Add Helm repository
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller

# Install controller
helm install arc \
    --namespace actions-runner-system \
    --create-namespace \
    actions-runner-controller/actions-runner-controller
```

**Create Runner Deployment (`aitherzero-runner-deployment.yaml`):**

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: aitherzero-runner
  namespace: actions-runner-system
spec:
  replicas: 2
  template:
    spec:
      repository: YOUR_ORG/AitherZero
      # Or use organization-wide:
      # organization: YOUR_ORG
      
      labels:
        - aitherzero
        - kubernetes
        - powershell
        - docker
      
      dockerdWithinRunnerContainer: true
      
      env:
        - name: RUNNER_FEATURE_FLAG_ONCE
          value: "true"
      
      resources:
        limits:
          cpu: "4"
          memory: "8Gi"
        requests:
          cpu: "2"
          memory: "4Gi"
      
      volumeMounts:
        - name: work
          mountPath: /runner/_work
      
      volumes:
        - name: work
          emptyDir: {}
```

**Create HorizontalRunnerAutoscaler (`runner-autoscaler.yaml`):**

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: aitherzero-runner-autoscaler
  namespace: actions-runner-system
spec:
  scaleTargetRef:
    name: aitherzero-runner
  
  minReplicas: 1
  maxReplicas: 10
  
  metrics:
    - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
      repositoryNames:
        - YOUR_ORG/AitherZero
  
  scaleDownDelaySecondsAfterScaleOut: 300
  scaleUpTriggers:
    - githubEvent:
        workflowJob: {}
      duration: 5m
```

**Deploy to Kubernetes:**
```bash
# Create secret with GitHub token
kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=YOUR_GITHUB_PAT

# Deploy runner
kubectl apply -f aitherzero-runner-deployment.yaml
kubectl apply -f runner-autoscaler.yaml

# Verify deployment
kubectl get runners -n actions-runner-system
kubectl get pods -n actions-runner-system
```

---

## Configuration

### Runner Labels

Use labels to target specific runners in workflows:

**Common Labels:**
- `aitherzero` - Identifies AitherZero runners
- `powershell` - Supports PowerShell 7+
- `docker` - Has Docker available
- `linux` / `windows` / `macos` - OS platform
- `gpu` - Has GPU capabilities
- `high-memory` - 16GB+ RAM
- `fast-storage` - SSD storage

**Workflow Usage:**
```yaml
jobs:
  build:
    runs-on: [self-hosted, aitherzero, powershell, docker]
    steps:
      - uses: actions/checkout@v4
      # ...
```

### Environment Variables

Configure runners with these environment variables:

```bash
# Runner identification
export RUNNER_NAME="aitherzero-runner-01"
export RUNNER_LABELS="aitherzero,powershell,docker"

# GitHub connection
export GITHUB_URL="https://github.com/YOUR_ORG/AitherZero"
export GITHUB_TOKEN="ghp_your_token_here"

# Work directory
export RUNNER_WORKDIR="/runner/_work"

# Optional: Proxy configuration
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1"
```

---

## Security Considerations

### Network Security

**Firewall Rules:**
```bash
# Allow outbound HTTPS (443) to GitHub
sudo ufw allow out 443/tcp

# Allow Docker if needed
sudo ufw allow 2375/tcp
sudo ufw allow 2376/tcp

# Block unnecessary inbound traffic
sudo ufw default deny incoming
sudo ufw enable
```

**GitHub IP Allowlist:**
```
# Add these GitHub IPs to your firewall allowlist
140.82.112.0/20
143.55.64.0/20
192.30.252.0/22
185.199.108.0/22
```

### Runner Isolation

**Best Practices:**
1. **Dedicated Networks**: Run self-hosted runners on isolated networks
2. **No Sensitive Data**: Don't store secrets/credentials on runners
3. **Regular Rotation**: Rebuild runner VMs/containers monthly
4. **Audit Logging**: Enable comprehensive logging
5. **Principle of Least Privilege**: Limit runner permissions

### Secret Management

**Use GitHub Secrets:**
```yaml
# Workflow file
jobs:
  deploy:
    runs-on: [self-hosted, aitherzero]
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          # Secrets are masked in logs
          echo "Deploying with API key"
```

**Never:**
- ❌ Hardcode secrets in runner configuration
- ❌ Store secrets in runner environment variables
- ❌ Log secrets to console/files

---

## Maintenance

### Regular Updates

**Update Runner Software:**
```bash
cd ~/actions-runner

# Stop runner
sudo ./svc.sh stop

# Update runner
./config.sh remove --token YOUR_TOKEN
curl -o actions-runner-linux-x64-latest.tar.gz -L \
  https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64-latest.tar.gz
tar xzf ./actions-runner-linux-x64-latest.tar.gz

# Reconfigure
./config.sh --url https://github.com/YOUR_ORG/AitherZero --token YOUR_TOKEN

# Restart
sudo ./svc.sh start
```

**Update System Packages:**
```bash
# Linux
sudo apt-get update && sudo apt-get upgrade -y

# Windows
choco upgrade all -y
```

### Monitoring

**Check Runner Status:**
```bash
# Linux
sudo ./svc.sh status

# Check logs
journalctl -u actions.runner.* -f

# Docker
docker logs -f aitherzero-runner

# Kubernetes
kubectl logs -f -n actions-runner-system -l app=aitherzero-runner
```

**Monitor Resources:**
```bash
# CPU/Memory usage
htop

# Disk usage
df -h

# Docker stats
docker stats
```

### Cleanup

**Clean Build Artifacts:**
```bash
# Remove old work directories
cd ~/actions-runner/_work
find . -type d -name "_temp" -exec rm -rf {} +
find . -type d -mtime +7 -exec rm -rf {} +

# Docker cleanup
docker system prune -af --volumes
```

---

## Troubleshooting

### Common Issues

**Issue: Runner not appearing in GitHub**
```bash
# Check runner status
./svc.sh status

# Check logs
tail -f _diag/Runner_*.log

# Verify network connectivity
curl -I https://api.github.com

# Test token
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.github.com/user
```

**Issue: Workflows failing with "No runners available"**
- Verify runner is online in GitHub settings
- Check runner labels match workflow requirements
- Ensure runner has capacity (not running max jobs)

**Issue: Docker builds failing**
```bash
# Verify Docker is running
docker ps

# Check Docker permissions
groups $USER
sudo usermod -aG docker $USER

# Restart Docker service
sudo systemctl restart docker
```

**Issue: PowerShell not found**
```bash
# Verify PowerShell installation
pwsh --version

# Install if missing (Linux)
wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb
sudo dpkg -i powershell_7.4.0-1.deb_amd64.deb
sudo apt-get install -f
```

---

## Performance Tuning

### Optimize for AitherZero Workflows

**Recommended System Configuration:**
```bash
# Increase file watchers (Linux)
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Increase open file limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Docker performance
# Use overlay2 storage driver
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
```

### Caching Strategies

**Docker Layer Caching:**
```yaml
- name: Build Docker Image
  uses: docker/build-push-action@v5
  with:
    context: .
    cache-from: type=local,src=/tmp/.buildx-cache
    cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max
```

**Dependency Caching:**
```yaml
- name: Cache PowerShell Modules
  uses: actions/cache@v4
  with:
    path: ~/.local/share/powershell/Modules
    key: ${{ runner.os }}-powershell-${{ hashFiles('**/*.psd1') }}
```

---

## Additional Resources

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AitherZero CI/CD Guide](./CICD-TROUBLESHOOTING.md)

---

## Support

For AitherZero-specific runner issues:
- 📧 Email: support@aitherium.org
- 💬 Discussions: https://github.com/YOUR_ORG/AitherZero/discussions
- 🐛 Issues: https://github.com/YOUR_ORG/AitherZero/issues

---

*Last Updated: 2025-11-11*
*Version: 1.0.0*
