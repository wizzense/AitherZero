# Self-Hosted GitHub Actions Runner for AitherZero

This directory contains everything needed to set up a self-hosted GitHub Actions runner with a persistent deployment of AitherZero's main branch.

## 🚀 Quick Start

```bash
# 1. Navigate to this directory
cd infrastructure/self-hosted-runner

# 2. Copy and configure the environment file
cp .env.example .env
nano .env  # Edit with your GitHub token

# 3. Run the installation script
sudo ./install-runner.sh

# 4. Verify the installation
sudo systemctl status aitherzero-runner
docker ps | grep aitherzero
```

## 📁 Files in This Directory

| File | Purpose |
|------|---------|
| `install-runner.sh` | Main installation script - sets up everything |
| `docker-compose.yml` | Container definitions for runner and deployment |
| `.env.example` | Template configuration file |
| `.env` | Your actual configuration (created from .env.example) |
| `scripts/update-main.sh` | Manually update the main deployment |
| `scripts/health-check.sh` | Check health of runner and deployment |

## 🔧 What Gets Installed

### 1. Docker Containers

**GitHub Actions Runner** (`aitherzero-runner`):
- Monitors GitHub for workflow jobs
- Executes workflows labeled with `runs-on: self-hosted`
- Has Docker-in-Docker capability for building/testing
- Auto-restarts on failure

**Main Branch Deployment** (`aitherzero-main`):
- Always runs the latest main branch code
- Accessible via http://localhost:8080
- Includes web dashboard with reports
- Auto-updates when main branch changes

### 2. Systemd Service

**Service Name**: `aitherzero-runner.service`
- Manages both containers
- Starts automatically on boot
- Restarts containers on failure
- Integrated with system logging

### 3. Installation Location

All files are installed to: `/opt/aitherzero-runner/`

```
/opt/aitherzero-runner/
├── docker-compose.yml      # Container configuration
├── .env                    # Your settings (secured)
├── data/                   # Persistent data
│   ├── runner/            # Runner workspace
│   ├── deployment/        # Deployment data
│   └── logs/              # Application logs
└── scripts/               # Management scripts
    ├── update-main.sh     # Update deployment
    └── health-check.sh    # Health monitoring
```

## 🔑 Configuration

### Required Settings in `.env`

```bash
# Your GitHub Personal Access Token
# Create at: https://github.com/settings/tokens/new
# Required scopes: repo, workflow
GITHUB_TOKEN=ghp_your_token_here

# Repository information
GITHUB_OWNER=wizzense
GITHUB_REPO=AitherZero

# Runner name (must be unique)
RUNNER_NAME=aitherzero-prod-runner

# Labels for targeting workflows
RUNNER_LABELS=self-hosted,linux,x64,aitherzero
```

### Optional Settings

```bash
# Port for web dashboard
DEPLOYMENT_PORT=8080

# Auto-update main deployment
DEPLOYMENT_AUTO_UPDATE=true

# Resource limits
RUNNER_CPU_LIMIT=2
RUNNER_MEMORY_LIMIT=4G
```

## 📊 Usage

### Service Management

```bash
# Start the runner
sudo systemctl start aitherzero-runner

# Stop the runner
sudo systemctl stop aitherzero-runner

# Restart the runner
sudo systemctl restart aitherzero-runner

# Check status
sudo systemctl status aitherzero-runner

# Enable auto-start on boot
sudo systemctl enable aitherzero-runner
```

### View Logs

```bash
# Service logs (systemd)
sudo journalctl -u aitherzero-runner -f

# Runner container logs
docker logs -f aitherzero-runner

# Deployment container logs
docker logs -f aitherzero-main

# All logs from both containers
docker-compose -f /opt/aitherzero-runner/docker-compose.yml logs -f
```

### Manual Updates

```bash
# Update the main deployment manually
sudo /opt/aitherzero-runner/scripts/update-main.sh

# Run health checks
/opt/aitherzero-runner/scripts/health-check.sh

# Update runner image
docker pull myoung34/github-runner:latest
sudo systemctl restart aitherzero-runner
```

### Access the Deployment

```bash
# Web dashboard
curl http://localhost:8080

# Or open in browser
xdg-open http://localhost:8080  # Linux
open http://localhost:8080       # macOS
```

## 🔄 Automatic Updates

The deployment automatically updates when:
1. New commits are pushed to the main branch
2. Workflow runs via scheduled trigger (daily at 2 AM UTC)
3. Manual workflow dispatch from GitHub Actions

**Workflow**: `.github/workflows/update-self-hosted-deployment.yml`

## 🏥 Health Monitoring

Run health checks anytime:

```bash
/opt/aitherzero-runner/scripts/health-check.sh
```

This checks:
- ✅ Systemd service status
- ✅ Runner container status
- ✅ Deployment container status
- ✅ Web interface accessibility
- ✅ GitHub API connectivity
- ✅ Disk space usage

## 🔒 Security

### Token Security

```bash
# Secure the .env file
sudo chmod 600 /opt/aitherzero-runner/.env
sudo chown root:root /opt/aitherzero-runner/.env
```

### Network Security

```bash
# Restrict access to web dashboard (example)
sudo ufw allow from 192.168.1.0/24 to any port 8080
sudo ufw enable
```

### Container Security

- Containers run as non-root users
- Docker socket access is controlled
- Regular security updates via base image updates

## 🔥 Troubleshooting

### Runner Not Showing in GitHub

1. Check token has correct permissions: `repo`, `workflow`
2. Check runner logs: `docker logs aitherzero-runner`
3. Verify token hasn't expired
4. Ensure network connectivity to GitHub

### Deployment Container Won't Start

1. Check logs: `docker logs aitherzero-main`
2. Verify port 8080 is not in use: `sudo netstat -tlnp | grep 8080`
3. Rebuild image: `cd /opt/aitherzero-runner && docker-compose build --no-cache`

### Out of Disk Space

```bash
# Clean Docker resources
docker system prune -a --volumes

# Clean old logs
sudo journalctl --vacuum-time=7d
```

### Service Won't Start

```bash
# Check service status
sudo systemctl status aitherzero-runner

# View recent logs
sudo journalctl -u aitherzero-runner -n 50

# Restart Docker
sudo systemctl restart docker
sudo systemctl restart aitherzero-runner
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

# Remove containers and volumes
cd /opt/aitherzero-runner
docker-compose down -v

# Remove installation directory
sudo rm -rf /opt/aitherzero-runner

# Optional: Remove Docker images
docker rmi $(docker images -q aitherzero)
docker rmi myoung34/github-runner:latest
```

## 📚 Additional Documentation

- **Complete Setup Guide**: [docs/SELF-HOSTED-RUNNER-SETUP.md](../../docs/SELF-HOSTED-RUNNER-SETUP.md)
- **Main README**: [README.md](../../README.md)
- **Docker Guide**: [DOCKER.md](../../DOCKER.md)

## 🆘 Getting Help

1. Check the troubleshooting section above
2. Review logs: `sudo journalctl -u aitherzero-runner -f`
3. Check Docker status: `docker ps -a`
4. Create an issue: https://github.com/wizzense/AitherZero/issues

## 📝 Notes

- The runner connects to GitHub automatically using the token in `.env`
- The main deployment auto-updates via GitHub Actions workflow
- Both containers auto-restart on failure
- The systemd service starts automatically on boot
- All data is persisted in Docker volumes

## ✅ Verification Checklist

After installation, verify:
- [ ] Service is running: `sudo systemctl status aitherzero-runner`
- [ ] Containers are up: `docker ps | grep aitherzero`
- [ ] Runner appears in GitHub: https://github.com/wizzense/AitherZero/settings/actions/runners
- [ ] Web dashboard accessible: http://localhost:8080
- [ ] Health check passes: `/opt/aitherzero-runner/scripts/health-check.sh`

## 🎯 Next Steps

After successful installation:
1. ✅ Verify runner appears in GitHub repository settings
2. ✅ Test the main deployment web interface
3. ✅ Run a test workflow to verify runner functionality
4. ✅ Set up monitoring and alerts (optional)
5. ✅ Configure backups for persistent data (optional)
