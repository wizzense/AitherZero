# PR Branch Deployment System - Complete Guide

## 📋 Overview

The AitherZero PR Branch Deployment System provides automated, ephemeral test environments for every pull request. This enables thorough testing in isolated environments before merging code to main branches.

## 🎯 Key Features

- **Automatic Deployment**: Environments automatically created when PR is opened or updated
- **Isolated Testing**: Each PR gets its own isolated environment with unique URLs/ports
- **Multiple Targets**: Support for Docker, Kubernetes, Azure, and AWS deployments
- **Cost Optimization**: Auto-cleanup of environments when PRs close or after TTL expires
- **Security**: Proper isolation, secrets management, and resource limits
- **Developer Experience**: Clear status updates, easy access to environments, comprehensive logging

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Pull Request                          │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow Triggers                    │
│  • deploy-pr-environment.yml - Creates environment               │
│  • cleanup-pr-environment.yml - Removes environment              │
└───────────────────┬─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┬──────────────┐
        ▼                       ▼              ▼
┌───────────────┐      ┌───────────────┐   ┌──────────────┐
│ Docker Compose│      │  Kubernetes   │   │ Cloud (IaaS) │
│   (Local)     │      │  (Container)  │   │ Azure/AWS    │
└───────────────┘      └───────────────┘   └──────────────┘
        │                       │                   │
        └───────────────────────┴───────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   PR Environment      │
                    │  • Container Running  │
                    │  • Unique Port/URL    │
                    │  • Isolated Resources │
                    └───────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

**Choose your deployment target:**

1. **Docker (Recommended for local/simple deployments)**
   - Docker Engine 20.10+
   - Docker Compose 2.0+
   
2. **Kubernetes (For scalable cloud deployments)**
   - kubectl configured
   - Access to Kubernetes cluster
   - Container registry access

3. **Azure (For managed cloud infrastructure)**
   - Azure CLI
   - Terraform 1.0+
   - Azure subscription with permissions

### Automatic Deployment (GitHub Actions)

**PR environments are automatically deployed when:**
- A pull request is opened (except drafts)
- A PR is updated with new commits
- Someone comments `/deploy` on the PR
- Manual workflow dispatch is triggered

**No manual setup required** - workflows handle everything automatically!

### Manual Deployment

If you need to deploy locally or test the deployment process:

```powershell
# Deploy a PR environment
./automation-scripts/0810_Deploy-PREnvironment.ps1 `
    -PRNumber 123 `
    -BranchName "feature/my-feature" `
    -CommitSHA "abc123def456" `
    -DeploymentTarget Docker

# Cleanup a PR environment
./automation-scripts/0851_Cleanup-PREnvironment.ps1 `
    -PRNumber 123 `
    -Target All
```

## 📦 Deployment Targets

### 1. Docker Compose (Default)

**Best for:** Local testing, simple deployments, rapid iteration

**Setup:**
```bash
# Ensure Docker is installed and running
docker --version
docker-compose --version

# Deploy
./automation-scripts/0810_Deploy-PREnvironment.ps1 -PRNumber 123 -DeploymentTarget Docker
```

**Access:**
- URL: `http://localhost:808{last-digit-of-PR}`
- Example: PR #123 → `http://localhost:8083`

**Resources Created:**
- Container: `aitherzero-pr-{number}`
- Volumes: `aitherzero-pr-{number}-logs`, `aitherzero-pr-{number}-reports`
- Compose file: `docker-compose.pr-{number}.yml`

### 2. Kubernetes

**Best for:** Production-like testing, scalability testing, cloud environments

**Setup:**
```bash
# Ensure kubectl is configured
kubectl version
kubectl get nodes

# Deploy
./automation-scripts/0810_Deploy-PREnvironment.ps1 -PRNumber 123 -DeploymentTarget Kubernetes
```

**Resources Created:**
- Namespace: `aitherzero-pr-{number}`
- Deployment: `aitherzero`
- Service: `aitherzero-service`
- Ingress: `aitherzero-ingress` (with TLS)

**Access:**
- Via Service IP or Ingress hostname
- Check: `kubectl get ingress -n aitherzero-pr-{number}`

### 3. Azure (Terraform)

**Best for:** Full cloud infrastructure, realistic production testing

**Setup:**
```bash
# Ensure Azure CLI and Terraform are installed
az --version
terraform --version

# Login to Azure
az login

# Configure Terraform backend (optional but recommended)
# Edit infrastructure/terraform/pr-environment.tf backend configuration

# Deploy via GitHub Actions or manual:
cd infrastructure/terraform
terraform init
terraform workspace new pr-123
terraform apply \
    -var="pr_number=123" \
    -var="branch_name=feature/my-feature" \
    -var="commit_sha=abc123"
```

**Resources Created:**
- Resource Group: `aitherzero-pr-{number}-rg-{suffix}`
- Virtual Network & Subnet
- Network Security Group
- Container Instance
- Public IP with DNS label

**Access:**
- URL: `http://pr-{number}-{suffix}.{region}.azurecontainer.io`
- Public IP displayed in Terraform outputs

**Cost Control:**
- Auto-shutdown configured (default: 8 PM local time)
- TTL: 48 hours (configurable)
- Resource limits: 1 CPU, 2GB RAM

## 🔧 Configuration

### Environment Variables

**Required for deployment workflows:**
```yaml
# GitHub Repository Secrets (for cloud deployments)
AZURE_CLIENT_ID: Azure service principal client ID
AZURE_CLIENT_SECRET: Azure service principal secret
AZURE_SUBSCRIPTION_ID: Azure subscription ID
AZURE_TENANT_ID: Azure tenant ID

AWS_ACCESS_KEY_ID: AWS access key (if using AWS)
AWS_SECRET_ACCESS_KEY: AWS secret key (if using AWS)
```

### Customization

**Modify deployment settings in workflow files:**

`.github/workflows/deploy-pr-environment.yml`:
```yaml
env:
  DEPLOYMENT_TYPE: preview
  CONTAINER_REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/aitherzero
```

**Modify resource limits in Terraform:**

`infrastructure/terraform/pr-environment.tf`:
```terraform
variable "instance_size" {
  default = "Standard_B2s"  # Change for different VM sizes
}

variable "ttl_hours" {
  default = 48  # Change auto-cleanup time
}
```

**Modify container resources in Docker Compose:**

`docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'      # Adjust CPU limit
      memory: 2G     # Adjust memory limit
```

## 🧪 Testing Deployed Environments

### Docker Compose Environments

```bash
# Check container status
docker ps -a | grep aitherzero-pr-

# View logs
docker logs aitherzero-pr-123 -f

# Execute commands in container
docker exec aitherzero-pr-123 pwsh -Command "Import-Module /app/AitherZero.psd1; Get-Module"

# Run tests
docker exec aitherzero-pr-123 pwsh -Command "./az.ps1 0402"

# Access interactive shell
docker exec -it aitherzero-pr-123 pwsh
```

### Kubernetes Environments

```bash
# Check deployment status
kubectl get all -n aitherzero-pr-123

# View logs
kubectl logs -f deployment/aitherzero -n aitherzero-pr-123

# Execute commands
kubectl exec -it deployment/aitherzero -n aitherzero-pr-123 -- pwsh -Command "./az.ps1 0402"

# Port forward for local access
kubectl port-forward service/aitherzero-service 8080:80 -n aitherzero-pr-123
```

### Azure Environments

```bash
# List container instances
az container list -o table | grep pr-123

# View logs
az container logs -g aitherzero-pr-123-rg-* -n aitherzero-pr-123-aci

# Execute commands
az container exec -g aitherzero-pr-123-rg-* -n aitherzero-pr-123-aci --exec-command "pwsh -Command './az.ps1 0402'"

# Get connection info
az container show -g aitherzero-pr-123-rg-* -n aitherzero-pr-123-aci --query ipAddress.fqdn
```

## 🧹 Cleanup

### Automatic Cleanup

Environments are automatically cleaned up:
- **PR Closed/Merged**: Immediate cleanup triggered
- **TTL Expired**: Scheduled job runs daily at 2 AM UTC
- **Stale Detection**: Environments older than 72 hours cleaned up

### Manual Cleanup

```powershell
# Cleanup specific PR environment
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123

# Cleanup only Docker resources
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Target Docker

# Force cleanup without confirmation
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Force

# Cleanup all targets
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Target All
```

### Verify Cleanup

```bash
# Docker
docker ps -a | grep aitherzero-pr-
docker volume ls | grep pr-

# Kubernetes
kubectl get namespaces | grep aitherzero-pr-

# Azure
az group list --query "[?starts_with(name, 'aitherzero-pr-')].name"
```

## 🔒 Security Best Practices

1. **Network Isolation**
   - Each environment has its own network namespace
   - Firewall rules restrict access to necessary ports only
   - Use private networks where possible

2. **Secrets Management**
   - Never commit secrets to repository
   - Use GitHub Secrets for sensitive values
   - Use Kubernetes Secrets or Azure Key Vault for cloud deployments
   - Rotate secrets regularly

3. **Resource Limits**
   - Enforce CPU and memory limits
   - Set storage quotas
   - Implement auto-shutdown for cost control

4. **Access Control**
   - Use RBAC in Kubernetes
   - Use managed identities in Azure
   - Limit who can trigger deployments
   - Audit deployment actions

5. **Container Security**
   - Run as non-root user (UID 1000)
   - Use minimal base images
   - Scan images for vulnerabilities
   - Keep base images updated

## 📊 Monitoring & Logging

### Health Checks

All deployments include health checks:
- **Docker**: Container health check every 30s
- **Kubernetes**: Liveness and readiness probes
- **Azure**: Container instance health monitoring

### Logging

Logs are available in multiple locations:
- **Container logs**: `docker logs` or `kubectl logs`
- **Volume mounts**: `/app/logs` persisted
- **Cloud monitoring**: Azure Container Insights, AWS CloudWatch

### Metrics

Track deployment metrics:
- Deployment duration
- Success/failure rates
- Resource utilization
- Cost per environment

## 🐛 Troubleshooting

### Deployment Fails

**Problem**: Container fails to start

```bash
# Check logs
docker logs aitherzero-pr-123

# Common causes:
# 1. Image build failed - check workflow logs
# 2. Port already in use - check docker ps
# 3. Resource limits - check available memory/CPU
```

**Problem**: Kubernetes pod stays in Pending

```bash
# Check pod status
kubectl describe pod -n aitherzero-pr-123

# Common causes:
# 1. Insufficient cluster resources
# 2. Image pull errors
# 3. PVC provisioning issues
```

### Access Issues

**Problem**: Cannot access environment URL

```bash
# Docker: Check port mapping
docker ps | grep aitherzero-pr-123

# Kubernetes: Check service
kubectl get svc -n aitherzero-pr-123

# Azure: Check public IP
az container show -g <resource-group> -n <container> --query ipAddress
```

### Cleanup Issues

**Problem**: Resources not cleaned up

```bash
# Force cleanup with script
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Force

# Manual cleanup
docker rm -f aitherzero-pr-123
docker volume prune -f
kubectl delete namespace aitherzero-pr-123
az group delete -n aitherzero-pr-123-rg-* --yes --no-wait
```

## 💰 Cost Optimization

### Best Practices

1. **Use TTL**: Set appropriate TTL values (default: 48 hours)
2. **Auto-Shutdown**: Configure shutdown times for non-critical testing
3. **Right-Size Resources**: Use smallest instance sizes that meet requirements
4. **Cleanup Promptly**: Close PRs when testing is complete
5. **Use Spot Instances**: For Azure/AWS deployments (if available)

### Cost Estimates

**Docker Compose (Local)**: Free (using local resources)

**Kubernetes (Cloud)**:
- Small cluster: ~$75-150/month
- Per environment: ~$0.02-0.05/hour
- Monthly (10 environments avg): ~$15-40

**Azure Container Instances**:
- 1 vCPU, 2GB RAM: ~$0.05/hour
- 48-hour TTL: ~$2.40/environment
- Monthly (10 environments): ~$24

## 📚 Additional Resources

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **Docker Documentation**: https://docs.docker.com/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **AitherZero Main Documentation**: [README.md](../README.md)

## 🤝 Contributing

Improvements to the PR deployment system are welcome!

1. Test changes locally first
2. Update documentation
3. Add workflow tests
4. Submit PR with clear description

## 📞 Support

- **Issues**: [Create an issue](../../issues/new)
- **Discussions**: [GitHub Discussions](../../discussions)
- **Workflow Logs**: Check GitHub Actions tab for detailed logs

---

**Last Updated**: 2025-10-27  
**Maintainers**: AitherZero Team
