# AitherZero Container Image
# Multi-stage build for optimized image size

FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN useradd -m -s /bin/bash aitherzero && \
    chown -R aitherzero:aitherzero /app

# Switch to non-root user
USER aitherzero

# Copy application files
COPY --chown=aitherzero:aitherzero . /app/

# Set environment variables
ENV AITHERZERO_ROOT=/app \
    AITHERZERO_NONINTERACTIVE=true \
    AITHERZERO_CI=false \
    AITHERZERO_DISABLE_TRANSCRIPT=1 \
    AITHERZERO_LOG_LEVEL=Warning \
    PATH="/app:${PATH}"

# Install PowerShell modules
RUN pwsh -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser; \
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser; \
    "

# Create required directories
RUN mkdir -p /app/logs /app/reports /app/tests/results

# Health check - run silently
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -NoProfile -Command "Test-Path /app/AitherZero.psd1 -PathType Leaf" > /dev/null 2>&1

# Default command - start interactive shell with minimal logging
CMD ["pwsh", "-NoExit", "-NoProfile", "-Command", "$VerbosePreference='SilentlyContinue'; $InformationPreference='SilentlyContinue'; Import-Module /app/AitherZero.psd1 -WarningAction SilentlyContinue; Write-Host '✅ AitherZero loaded. Type Start-AitherZero to begin.' -ForegroundColor Green"]

# Expose ports for potential web interfaces (future use)
EXPOSE 8080 8443
