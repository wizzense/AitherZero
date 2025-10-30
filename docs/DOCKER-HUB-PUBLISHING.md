# Docker Hub Publishing Quick Reference

This guide shows you how to get AitherZero Docker images uploaded and available for Docker Desktop on Windows, macOS, and Linux.

## For End Users - Pulling Images from Docker Hub

**No authentication required!** Just pull and run:

```bash
# Pull latest stable version
docker pull wizzense/aitherzero:latest

# Run interactively
docker run -it --name aitherzero wizzense/aitherzero:latest

# Inside the container, use these commands:
# az 0402              # Run tests
# az 0510 -ShowAll     # Generate reports
# Start-AitherZero     # Interactive menu
```

**Docker Hub Repository**: https://hub.docker.com/r/wizzense/aitherzero

## For Maintainers - Publishing Images

### Prerequisites

1. **Docker Hub Account**
   - Create account at https://hub.docker.com
   - Create access token at https://hub.docker.com/settings/security

2. **Set Environment Variables**
   ```powershell
   # Windows PowerShell
   $env:DOCKER_HUB_USERNAME = "yourusername"
   $env:DOCKER_HUB_TOKEN = "dckr_pat_your_token_here"

   # Linux/macOS
   export DOCKER_HUB_USERNAME="yourusername"
   export DOCKER_HUB_TOKEN="dckr_pat_your_token_here"
   ```

### Manual Publishing

```powershell
# Build and publish to Docker Hub
.\automation-scripts\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "yourusername"

# Publish to both Docker Hub and GHCR
.\automation-scripts\0855_Publish-DockerImage.ps1 -Registry All -Username "yourusername"

# Publish specific version as latest
.\automation-scripts\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "yourusername" -Version "1.0.0" -PushLatest
```

### Automated Publishing via GitHub Actions

The repository automatically publishes images when you create a release:

1. **Set Repository Secrets** (Settings → Secrets → Actions):
   - `DOCKER_HUB_USERNAME`: Your Docker Hub username
   - `DOCKER_HUB_TOKEN`: Docker Hub access token

2. **Create a Release**:
   ```bash
   # Tag a release
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0

   # Or create via GitHub web UI
   ```

3. **GitHub Actions Will**:
   - Build multi-platform images (amd64, arm64)
   - Publish to Docker Hub as `wizzense/aitherzero:1.0.0`
   - Publish to GHCR as `ghcr.io/wizzense/aitherzero:1.0.0`
   - Tag as `latest` automatically
   - Run verification tests
   - Post comment on release with pull instructions

### Testing Before Publishing

```powershell
# Build locally without pushing
.\automation-scripts\0855_Publish-DockerImage.ps1 -BuildOnly

# Dry run to see what would happen
.\automation-scripts\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "yourusername" -DryRun

# Build for single platform (faster testing)
.\automation-scripts\0855_Publish-DockerImage.ps1 -BuildOnly -Platform linux/amd64
```

## Available Tags

After publishing version 1.0.0, these tags are created:

- `wizzense/aitherzero:1.0.0` - Specific version
- `wizzense/aitherzero:1.0` - Major.minor version
- `wizzense/aitherzero:1` - Major version
- `wizzense/aitherzero:latest` - Latest stable release

## Image Information

- **Size**: ~500MB compressed
- **Platforms**: linux/amd64, linux/arm64
- **Base**: PowerShell 7.4 on Ubuntu 22.04
- **Registry**: Docker Hub (public) and GHCR (authenticated)

## Troubleshooting

### "Permission denied" when pushing
- Verify your Docker Hub token is correct
- Ensure token has "Read, Write" permissions (Delete not required)
- Try logging in manually: `docker login`

### "Buildx not found"
- Install Docker Buildx: https://docs.docker.com/buildx/working-with-buildx/
- Or use Docker Desktop which includes Buildx

### Multi-platform build fails
- **SECURITY WARNING**: The following command uses `--privileged` which grants extensive system access to the container. Only run on trusted systems.
- Install QEMU for multi-platform emulation: `docker run --privileged --rm tonistiigi/binfmt --install all`
- Alternative: Build for single platform only: `-Platform linux/amd64`
- Note: Docker Desktop includes QEMU/buildx, so this is usually not needed

## See Also

- [Complete Docker Documentation](DOCKER.md)
- [Docker Hub Repository](https://hub.docker.com/r/wizzense/aitherzero)
- [GitHub Container Registry](https://github.com/wizzense/AitherZero/pkgs/container/aitherzero)
