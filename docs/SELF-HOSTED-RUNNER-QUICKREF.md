# Self-Hosted Runner Quick Reference

## 🚀 Installation (2 Minutes - Automated)

### Using AitherZero Automation (Recommended)

```bash
# One-command deployment
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
./az.ps1 0724 -GitHubToken "ghp_your_token_here"

# That's it! ✅
```

## 🚀 Installation (5 Minutes - Manual)

```bash
# 1. Clone repo
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero/infrastructure/self-hosted-runner

# 2. Configure
cp .env.example .env
nano .env  # Add your GitHub token

# 3. Install
sudo ./install-runner.sh

# 4. Verify
sudo systemctl status aitherzero-runner
curl http://localhost:8080
```

## 📝 Get GitHub Token

1. Go to: https://github.com/settings/tokens/new
2. Name: "AitherZero Self-Hosted Runner"
3. Expiration: 90 days (recommended)
4. Scopes: `repo`, `workflow`
5. Click "Generate token"
6. Copy token to `.env` file

## 🎛️ Management Commands

```bash
# Service Control
sudo systemctl start aitherzero-runner      # Start
sudo systemctl stop aitherzero-runner       # Stop
sudo systemctl restart aitherzero-runner    # Restart
sudo systemctl status aitherzero-runner     # Status

# View Logs
docker logs -f aitherzero-runner            # Runner logs
docker logs -f aitherzero-main              # Deployment logs
sudo journalctl -u aitherzero-runner -f     # Service logs

# Updates
sudo /opt/aitherzero-runner/scripts/update-main.sh    # Update deployment
/opt/aitherzero-runner/scripts/health-check.sh        # Health check

# Container Status
docker ps | grep aitherzero                 # List containers
docker stats aitherzero-runner              # Resource usage
```

## 🔍 Troubleshooting

### Runner Not in GitHub?
```bash
# Check logs
docker logs aitherzero-runner
# Look for: "Connected to GitHub" or authentication errors
```

### Deployment Not Accessible?
```bash
# Check container
docker ps | grep aitherzero-main
# Check port
sudo netstat -tlnp | grep 8080
# Restart deployment
docker restart aitherzero-main
```

### Out of Disk Space?
```bash
# Clean Docker
docker system prune -a --volumes
# Clean logs
sudo journalctl --vacuum-time=7d
```

## 📍 Key Locations

```
/opt/aitherzero-runner/          # Installation root
  ├── .env                       # Your config
  ├── docker-compose.yml         # Container setup
  ├── scripts/
  │   ├── update-main.sh         # Update script
  │   └── health-check.sh        # Health check
  └── data/                      # Persistent data
```

## 🌐 Access Points

- **Web Dashboard**: http://localhost:8080
- **Runner Status**: https://github.com/wizzense/AitherZero/settings/actions/runners
- **Workflow Logs**: https://github.com/wizzense/AitherZero/actions

## 🔄 What Happens Automatically?

- ✅ Runner starts on system boot
- ✅ Deployment updates when main branch changes
- ✅ Containers restart on failure
- ✅ Daily health check at 2 AM UTC
- ✅ Reports accessible via web dashboard

## 🛑 Uninstall

```bash
sudo systemctl stop aitherzero-runner
sudo systemctl disable aitherzero-runner
sudo rm /etc/systemd/system/aitherzero-runner.service
sudo systemctl daemon-reload
cd /opt/aitherzero-runner && docker-compose down -v
sudo rm -rf /opt/aitherzero-runner
```

## 📚 Full Documentation

- Setup Guide: `docs/SELF-HOSTED-RUNNER-SETUP.md`
- Infrastructure README: `infrastructure/self-hosted-runner/README.md`

## 🆘 Quick Checks

```bash
# Is service running?
sudo systemctl is-active aitherzero-runner

# Are containers running?
docker ps | grep aitherzero

# Is web interface up?
curl -I http://localhost:8080

# Is runner connected to GitHub?
docker logs aitherzero-runner | grep "Connected"

# Run full health check
/opt/aitherzero-runner/scripts/health-check.sh
```

## 💡 Pro Tips

1. **Monitor disk space**: Set up alerts for >80% disk usage
2. **Rotate tokens**: Update GitHub token every 90 days
3. **Backup config**: Keep a backup of your `.env` file
4. **Test updates**: Test runner updates in dev environment first
5. **Check logs**: Review logs weekly for any issues

## 🔐 Security Checklist

- [ ] .env file has 600 permissions
- [ ] Firewall rules configured (if needed)
- [ ] GitHub token has minimal required scopes
- [ ] System updates are automated
- [ ] Docker images are regularly updated

## ⚡ Quick Fixes

```bash
# Container won't start
docker-compose build --no-cache
docker-compose up -d

# Runner disconnected
sudo systemctl restart aitherzero-runner

# Web interface not responding
docker restart aitherzero-main

# Complete reset (no data loss)
cd /opt/aitherzero-runner
docker-compose down
docker-compose up -d
```

---

**Need More Help?** 
- Full Guide: `docs/SELF-HOSTED-RUNNER-SETUP.md`
- Create Issue: https://github.com/wizzense/AitherZero/issues
