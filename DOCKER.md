# AitherZero Docker Usage Guide

This guide explains how to use AitherZero with Docker for easy deployment and access.

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the container
docker-compose up -d

# Access the web interface
open http://localhost:8080

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### Using Docker directly

```bash
# Build the image
docker build -t aitherzero:latest .

# Run the container
docker run -d \
  --name aitherzero \
  -p 8080:8080 \
  -p 8443:8443 \
  aitherzero:latest

# Access the web interface
open http://localhost:8080
```

## Container Features

When the container starts, it automatically:

1. ✅ Initializes and validates the AitherZero environment
2. 📊 Generates reports and dashboards
3. 🌐 Starts a web server on port 8080
4. 🖥️ Provides interactive CLI access via `docker exec`

## Access Methods

### Web Browser Access

Once the container is running, access the web interface at:
- **HTTP**: http://localhost:8080
- **HTTPS**: https://localhost:8443 (reserved for future use)

The web interface provides:
- 📊 Live dashboards with project metrics
- 🧪 Test results and coverage reports
- 🔒 Security scan results
- 📚 API documentation
- 📈 Historical trends and analytics

### Interactive CLI Access

To access PowerShell interactively inside the container:

```bash
# Open an interactive PowerShell session
docker exec -it aitherzero pwsh

# Once inside, you can use AitherZero commands
PS> Start-AitherZero
PS> az 0402  # Run unit tests
PS> az 0510  # Generate reports
```

### Run Single Commands

Execute AitherZero commands from outside the container:

```bash
# Run unit tests
docker exec aitherzero pwsh -Command "./Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402"

# Generate project report
docker exec aitherzero pwsh -Command "./Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0510"

# Run a playbook
docker exec aitherzero pwsh -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"

# List available scripts
docker exec aitherzero pwsh -Command "./Start-AitherZero.ps1 -Mode List -Target scripts"
```

## Custom Configuration

### Environment Variables

Configure AitherZero behavior using environment variables:

```bash
docker run -d \
  -e AITHERZERO_PROFILE=Developer \
  -e AITHERZERO_NONINTERACTIVE=true \
  -p 8080:8080 \
  aitherzero:latest
```

Available environment variables:
- `AITHERZERO_PROFILE`: Minimal, Standard, Developer, Full
- `AITHERZERO_NONINTERACTIVE`: true/false
- `AITHERZERO_CI`: true/false
- `AITHERZERO_LOG_LEVEL`: Debug, Information, Warning, Error

### Custom Startup Mode

Override the default startup behavior:

```bash
# Skip validation and report generation
docker run -d \
  -p 8080:8080 \
  aitherzero:latest \
  pwsh -File ./docker-entrypoint.ps1 -SkipValidation -SkipReports

# Run a specific mode instead
docker run -d \
  -p 8080:8080 \
  aitherzero:latest \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Test -NonInteractive"
```

### Volume Mounts

Persist data and configuration across container restarts:

```bash
docker run -d \
  -v aitherzero-logs:/app/logs \
  -v aitherzero-reports:/app/reports \
  -v aitherzero-results:/app/tests/results \
  -p 8080:8080 \
  aitherzero:latest
```

For local development with live code updates:

```bash
docker run -d \
  -v $(pwd):/app:rw \
  -p 8080:8080 \
  aitherzero:latest
```

## Docker Compose Advanced Usage

### Profiles

Docker compose supports optional services via profiles:

```bash
# Start with Redis cache
docker-compose --profile with-cache up -d

# Start with PostgreSQL database
docker-compose --profile with-database up -d

# Start with all optional services
docker-compose --profile with-cache --profile with-database up -d
```

### Custom Commands

Override the default command in docker-compose:

```yaml
services:
  aitherzero:
    # ... other config ...
    command: ["pwsh", "-Command", "./Start-AitherZero.ps1 -Mode Orchestrate -Sequence 0402 -NonInteractive"]
```

## Troubleshooting

### Container exits immediately

Check logs to see what happened:
```bash
docker logs aitherzero
```

### Web interface not accessible

1. Verify the container is running:
   ```bash
   docker ps
   ```

2. Check port mapping:
   ```bash
   docker port aitherzero
   ```

3. View server logs:
   ```bash
   docker logs aitherzero
   ```

### Python web server not starting

The entrypoint script requires Python to serve the web interface. If Python is not available, the container will stay alive for CLI access but the web interface won't work. Rebuild the image to ensure Python is installed:

```bash
docker-compose build --no-cache
```

### Permission issues

If you encounter permission errors with mounted volumes:

```bash
# Fix ownership on Linux/Mac
sudo chown -R $(id -u):$(id -g) ./logs ./reports ./tests
```

## Health Checks

Check if the container is healthy:

```bash
# Using Docker
docker inspect --format='{{.State.Health.Status}}' aitherzero

# Using docker-compose
docker-compose ps
```

The health check verifies that the AitherZero.psd1 manifest file exists.

## Stopping and Cleaning Up

```bash
# Stop the container
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Remove the image
docker rmi aitherzero:latest

# Complete cleanup
docker-compose down -v --rmi all
```

## Best Practices

1. **Production Use**: Always use docker-compose for easier management
2. **Security**: Don't mount sensitive credentials in production
3. **Updates**: Regularly rebuild images to get security updates
4. **Monitoring**: Use `docker logs` and the web dashboard to monitor status
5. **Backups**: Regularly backup volume data (logs, reports, results)

## Examples

### Development Workflow

```bash
# Start container in development mode
docker-compose up -d

# Watch logs
docker-compose logs -f

# Run tests
docker exec aitherzero pwsh -Command "az 0402"

# Generate fresh reports
docker exec aitherzero pwsh -Command "az 0510"

# View in browser
open http://localhost:8080
```

### CI/CD Integration

```bash
# Build for CI
docker build --tag aitherzero:ci .

# Run tests in container
docker run --rm aitherzero:ci \
  pwsh -Command "./Start-AitherZero.ps1 -Mode Test -NonInteractive -CI"

# Extract reports
docker run --rm \
  -v $(pwd)/reports:/output \
  aitherzero:ci \
  pwsh -Command "Copy-Item /app/reports/* /output/ -Recurse"
```

## Support

For more information:
- Main README: [README.md](README.md)
- Modern CLI Guide: [README-ModernCLI.md](README-ModernCLI.md)
- GitHub Issues: https://github.com/wizzense/AitherZero/issues
