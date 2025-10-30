# AitherZero Development Container

This directory contains the Development Container (DevContainer) configuration for AitherZero, providing a consistent, pre-configured development environment.

## What is a Dev Container?

A Dev Container is a Docker container specifically configured for development. It includes:
- All required tools and dependencies
- Pre-configured VS Code settings and extensions
- Environment variables and workspace configuration
- Post-creation scripts for additional setup

## Benefits

✅ **Consistency**: Same environment for all developers
✅ **Isolation**: No conflicts with local system
✅ **Quick Setup**: Ready to code in minutes
✅ **Reproducible**: Identical setup every time
✅ **Clean**: Easy to reset and rebuild

## Prerequisites

1. **Docker Desktop**: Install from https://www.docker.com/products/docker-desktop
2. **VS Code**: Install from https://code.visualstudio.com/
3. **Remote - Containers Extension**: Install in VS Code

## Quick Start

1. **Open the repository** in VS Code
2. **Reopen in Container**: 
   - Press `F1`
   - Select "Remote-Containers: Reopen in Container"
   - Wait for build to complete (first time only)
3. **Start coding!** All tools are ready

## Included Tools

The container includes:

### Core Tools
- **PowerShell 7+**: Latest PowerShell release
- **Git**: Version control
- **GitHub CLI (gh)**: GitHub command-line tool
- **Node.js LTS**: For MCP servers and tooling
- **Docker-in-Docker**: Container support within container

### PowerShell Modules
- **Pester**: Testing framework
- **PSScriptAnalyzer**: Code analysis and linting

### VS Code Extensions (Auto-installed)
- GitHub Copilot & Copilot Chat
- PowerShell
- YAML
- Markdown Lint
- Docker
- GitLens
- GitHub Pull Requests
- Code Spell Checker

## Configuration

### Environment Variables

The container sets these environment variables:

- `AITHERZERO_ROOT`: Points to workspace folder
- `AITHERZERO_ENVIRONMENT`: Set to "development"

### Port Forwarding

Ports 8080 and 8443 are forwarded for web services and testing.

### Volume Mounts

The `.env` file is mounted from the host (if it exists) for secrets and tokens.

## Using the Container

### Terminal

The default terminal profile is PowerShell 7. All AitherZero commands work immediately:

```powershell
# Run scripts
./Start-AitherZero.ps1

# Use shortcuts
az 0402  # Run unit tests
az 0404  # Run PSScriptAnalyzer

# Access all functions
Import-Module ./AitherZero.psd1
Write-CustomLog "Test message"
```

### Tasks and Debugging

All VS Code tasks and launch configurations work in the container:

- Press `Ctrl+Shift+B` to run build tasks
- Press `F5` to start debugging
- Use Task menu for common operations

### GitHub Integration

To use GitHub features (MCP server, CLI):

1. Create a GitHub Personal Access Token
2. Add to `.env` file in repository root:
   ```
   GITHUB_TOKEN=your_token_here
   ```
3. Rebuild container or restart VS Code

## Customization

### Modify Tools

Edit `devcontainer.json` to add features:

```json
"features": {
  "ghcr.io/devcontainers/features/python:1": {
    "version": "3.11"
  }
}
```

### Add Extensions

Add to `customizations.vscode.extensions`:

```json
"customizations": {
  "vscode": {
    "extensions": [
      "ms-vscode.powershell",
      "your-extension-id"
    ]
  }
}
```

### Change Settings

Modify `customizations.vscode.settings`:

```json
"settings": {
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

## Rebuilding

If you modify the configuration:

1. **Rebuild Container**:
   - Press `F1`
   - Select "Remote-Containers: Rebuild Container"
   - Wait for rebuild to complete

2. **Or from command line**:
   ```bash
   # From host machine
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

## Troubleshooting

### Container Won't Build

1. **Check Docker is running**: Ensure Docker Desktop is running
2. **Clear cache**: Rebuild with `--no-cache` flag
3. **Check disk space**: Ensure sufficient disk space
4. **Review logs**: Check Docker Desktop logs

### Extensions Not Installing

1. **Wait for completion**: Extensions install after container starts
2. **Reload window**: `Ctrl+Shift+P` → "Reload Window"
3. **Manual install**: Install from Extensions view

### GitHub Token Issues

1. **Verify token**: Check `.env` file has valid token
2. **Rebuild container**: Token is loaded at container start
3. **Check permissions**: Token needs `repo` scope

### Permission Errors

1. **Check file ownership**: Files may be owned by container user
2. **Fix permissions**: 
   ```bash
   # From host
   sudo chown -R $USER:$USER .
   ```

## Advanced Usage

### Multiple Containers

Run multiple AitherZero instances:

```bash
# Copy repository to different directory
cp -r AitherZero AitherZero-dev2

# Open in VS Code
code AitherZero-dev2

# Reopen in container - will create separate container
```

### Attach to Running Container

```bash
# List running containers
docker ps

# Attach to container
docker exec -it <container_id> pwsh
```

### Custom Dockerfile

For more control, create a custom Dockerfile and reference it:

```json
{
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  }
}
```

## Performance Tips

### On Windows
- Use WSL2 backend for Docker (faster)
- Clone repo in WSL2 filesystem
- Open from WSL: `\\wsl$\Ubuntu\home\user\AitherZero`

### On macOS
- Allocate more RAM to Docker Desktop (Preferences → Resources)
- Use VirtioFS for file sharing (experimental feature)

### On Linux
- Use native Docker engine (fastest)
- No special configuration needed

## Resources

- [Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Dev Container Specification](https://containers.dev/)
- [Available Features](https://github.com/devcontainers/features)
- [Docker Documentation](https://docs.docker.com/)

## Getting Help

- **VS Code**: Check Remote - Containers output panel
- **Docker**: Review Docker Desktop logs
- **AitherZero**: See main documentation in `docs/`
- **Issues**: Report problems in GitHub Issues

---

**Enjoy consistent development environment! 🐳**
