# AitherZero Container Image
# Multi-stage build for optimized image size

FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS base

# Install system dependencies including Python for web server
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    openssh-client \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -s /bin/bash aitherzero

# Create AitherZero installation directory (separate from /app working directory)
RUN mkdir -p /opt/aitherzero && \
    chown -R aitherzero:aitherzero /opt/aitherzero

# Create working directory for user files
RUN mkdir -p /app && \
    chown -R aitherzero:aitherzero /app

# Switch to non-root user
USER aitherzero

# Copy application files to /opt/aitherzero
COPY --chown=aitherzero:aitherzero . /opt/aitherzero/

# Set environment variables
ENV AITHERZERO_ROOT=/opt/aitherzero \
    AITHERZERO_NONINTERACTIVE=true \
    AITHERZERO_CI=false \
    AITHERZERO_DISABLE_TRANSCRIPT=1 \
    AITHERZERO_LOG_LEVEL=Warning \
    PATH="/opt/aitherzero:${PATH}"

# Install PowerShell modules (optional - modules can be installed at runtime if needed)
# Note: PSGallery configuration may require network access or additional setup in containerized environments
# The modules will be installed on first use if not present
RUN pwsh -NoProfile -Command " \
    \$ErrorActionPreference = 'Continue'; \
    try { \
        Get-PSRepository -Name PSGallery -ErrorAction Stop | Set-PSRepository -InstallationPolicy Trusted -ErrorAction Stop; \
        Write-Host 'Attempting to install PowerShell modules...'; \
        Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber -ErrorAction Continue; \
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber -ErrorAction Continue; \
        Get-InstalledModule -ErrorAction SilentlyContinue | Format-Table Name, Version -AutoSize; \
    } catch { \
        Write-Host 'Module installation skipped. Modules can be installed at runtime with: Install-Module -Name Pester,PSScriptAnalyzer -Force'; \
    } \
    "

# Create required directories in /opt/aitherzero
RUN mkdir -p /opt/aitherzero/logs /opt/aitherzero/reports /opt/aitherzero/tests/results

# Set working directory to /app for user files
WORKDIR /app

# Health check - verify manifest file exists in installation directory
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -NoProfile -Command "Test-Path /opt/aitherzero/AitherZero.psd1 -PathType Leaf"

# Default command - keep container running for interactive use or automation
# Import module from /opt/aitherzero, work in /app directory
CMD ["pwsh", "-NoProfile", "-Command", "$VerbosePreference='SilentlyContinue'; $InformationPreference='SilentlyContinue'; Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue; Write-Host '✅ AitherZero loaded. Type Start-AitherZero to begin.' -ForegroundColor Green; Start-Sleep -Seconds 2147483"]

# Expose ports for potential web interfaces (future use)
EXPOSE 8080 8443
