# AitherZero Container Image
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# Add container metadata labels following OpenContainers specification
LABEL org.opencontainers.image.title="AitherZero" \
      org.opencontainers.image.description="Enterprise infrastructure automation platform with AI-powered orchestration. Provides PowerShell-based automation for infrastructure deployment, testing, and management across Windows, Linux, and macOS." \
      org.opencontainers.image.vendor="Aitherium Organization" \
      org.opencontainers.image.authors="wizzense" \
      org.opencontainers.image.url="https://github.com/wizzense/AitherZero" \
      org.opencontainers.image.documentation="https://github.com/wizzense/AitherZero/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/wizzense/AitherZero" \
      org.opencontainers.image.licenses="MIT"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash aitherzero

# Create installation directory
RUN mkdir -p /opt/aitherzero && \
    chown -R aitherzero:aitherzero /opt/aitherzero

# Switch to non-root user
USER aitherzero

# Copy application files
COPY --chown=aitherzero:aitherzero . /opt/aitherzero/

# Set environment variables
ENV AITHERZERO_ROOT=/opt/aitherzero \
    PATH="/home/aitherzero/.local/bin:${PATH}"

# Work in the installation directory
WORKDIR /opt/aitherzero

# Bootstrap the environment - this initializes the module and installs the global command
RUN pwsh -NoProfile -ExecutionPolicy Bypass -Command " \
    Write-Host '🚀 Bootstrapping AitherZero...' -ForegroundColor Cyan; \
    ./bootstrap.ps1 -Mode New -InstallProfile Minimal -NonInteractive -SkipAutoStart; \
    Write-Host '✅ Bootstrap complete' -ForegroundColor Green"

# Verify the global command was installed
RUN pwsh -NoProfile -Command " \
    if (Test-Path '/home/aitherzero/.local/bin/aitherzero') { \
        Write-Host '✅ Global aitherzero command installed' -ForegroundColor Green; \
    } else { \
        Write-Host '⚠️  Warning: Global command not found, attempting manual install...' -ForegroundColor Yellow; \
        if (Test-Path './tools/Install-GlobalCommand.ps1') { \
            ./tools/Install-GlobalCommand.ps1 -Action Install -InstallPath /opt/aitherzero; \
        } \
    }"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -NoProfile -Command "Test-Path /opt/aitherzero/AitherZero.psd1"

# Keep container running and ready for interactive use
CMD ["pwsh", "-NoLogo", "-NoExit", "-Command", "\
    Set-Location /opt/aitherzero; \
    if (-not (Get-Module -Name AitherZero)) { \
        try { Import-Module /opt/aitherzero/AitherZero.psd1 -Force -WarningAction SilentlyContinue } \
        catch { Write-Host \"⚠️  Module load warning: $_\" -ForegroundColor Yellow } \
    }; \
    Write-Host ''; \
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan; \
    Write-Host '║                    🚀 AitherZero Container                   ║' -ForegroundColor Cyan; \
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan; \
    Write-Host ''; \
    Write-Host '✅ Ready to use!' -ForegroundColor Green; \
    Write-Host ''; \
    Write-Host '💡 Quick commands:' -ForegroundColor Cyan; \
    Write-Host '   aitherzero                 - Launch interactive menu' -ForegroundColor White; \
    Write-Host '   Start-AitherZero           - Same as above' -ForegroundColor Gray; \
    Write-Host ''; \
    Write-Host '📍 Working directory: /opt/aitherzero' -ForegroundColor Gray; \
    Write-Host ''; \
    while($true) { Start-Sleep 3600 }"]
