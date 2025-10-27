# AitherZero Container Image
# Multi-stage build for optimized image size

FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS base

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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
    PATH="/app:${PATH}"

# Install PowerShell modules
RUN pwsh -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser; \
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser; \
    "

# Create required directories
RUN mkdir -p /app/logs /app/reports /app/tests/results

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -Command "Test-Path /app/AitherZero.psd1 -PathType Leaf"

# Default command - start interactive shell
CMD ["pwsh", "-NoExit", "-Command", "Import-Module /app/AitherZero.psd1; Write-Host '✅ AitherZero loaded. Type Start-AitherZero to begin.' -ForegroundColor Green"]

# Expose ports for potential web interfaces (future use)
EXPOSE 8080 8443
