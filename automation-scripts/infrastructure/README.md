# AitherZero Infrastructure

This directory contains infrastructure-as-code definitions for deploying AitherZero environments.

## 📁 Directory Structure

```
infrastructure/
├── kubernetes/         # Kubernetes manifests
│   └── deployment.yml  # K8s deployment, service, ingress
├── terraform/          # Terraform/OpenTofu configurations
│   └── pr-environment.tf  # Azure container instances
├── examples/           # Example configurations
├── infrastructure/     # Additional infrastructure modules
├── main.tf            # Root Terraform configuration
└── README.md          # This file
```

## 🚀 Deployment Targets

### 1. Kubernetes

**Use when:** Production-like environments, scalability testing, cloud-native deployments

**Requirements:**
- kubectl configured with cluster access
- Container registry with images
- Ingress controller (nginx recommended)
- cert-manager for TLS (optional)

**Deploy:**
```bash
cd infrastructure/kubernetes

# Apply manifests
kubectl apply -f deployment.yml

# Or with customizations
kubectl apply -f - <<EOF
$(cat deployment.yml | sed 's/PR_NUMBER: ""/PR_NUMBER: "123"/')
EOF

# Check status
kubectl get all -n aitherzero-preview
```

**Resources Created:**
- Namespace: `aitherzero-preview`
- Deployment: `aitherzero`
- Service: `aitherzero-service` (ClusterIP)
- Ingress: `aitherzero-ingress` (with TLS)
- ConfigMap: Environment configuration
- Secret: Sensitive data (passwords, keys)

### 2. Terraform (Azure)

**Use when:** Full infrastructure provisioning, cost control, production deployments

**Requirements:**
- Terraform 1.0+
- Azure CLI with authentication
- Azure subscription with permissions

**Deploy:**
```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Create workspace for PR
terraform workspace new pr-123

# Plan deployment
terraform plan \
    -var="pr_number=123" \
    -var="branch_name=feature/my-feature" \
    -var="commit_sha=abc123def456"

# Apply
terraform apply \
    -var="pr_number=123" \
    -var="branch_name=feature/my-feature" \
    -var="commit_sha=abc123def456" \
    -auto-approve

# Get outputs
terraform output environment_url
```

**Resources Created:**
- Resource Group: `aitherzero-pr-{number}-rg-{suffix}`
- Virtual Network: `aitherzero-pr-{number}-vnet`
- Subnet: `aitherzero-pr-{number}-subnet`
- NSG: Network security group with rules
- Public IP: Static IP with DNS label
- Container Instance: Running AitherZero

**Cost Controls:**
- Auto-shutdown: Configurable time (default 8 PM)
- TTL: Auto-cleanup after X hours (default 48)
- Resource limits: 1 vCPU, 2GB RAM
- Tags: Track costs by PR number

**Cleanup:**
```bash
# Destroy resources
terraform destroy \
    -var="pr_number=123" \
    -var="branch_name=cleanup" \
    -var="commit_sha=cleanup" \
    -auto-approve

# Delete workspace
terraform workspace select default
terraform workspace delete pr-123
```

## 🔧 Configuration

### Environment Variables

**Kubernetes ConfigMap:**
```yaml
AITHERZERO_NONINTERACTIVE: "true"
AITHERZERO_CI: "false"
AITHERZERO_PROFILE: "Standard"
DEPLOYMENT_ENVIRONMENT: "preview"
```

**Terraform Variables:**
```terraform
pr_number          = "123"
branch_name        = "feature/my-feature"
commit_sha         = "abc123def456"
environment        = "preview"
location           = "eastus"
instance_size      = "Standard_B2s"
auto_shutdown_time = "20:00"
ttl_hours          = 48
```

### Resource Limits

**Kubernetes:**
```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

**Azure Container Instance:**
```terraform
cpu    = "1.0"
memory = "2.0"
```

## 🔒 Security

### Network Security

**Kubernetes:**
- Network policies isolate namespaces
- Ingress with TLS termination
- Service mesh (optional): Istio, Linkerd

**Azure:**
- NSG rules limit access to HTTP/HTTPS/SSH
- Private networking available
- Azure Firewall integration

### Secrets Management

**Kubernetes Secrets:**
```bash
# Create secret
kubectl create secret generic aitherzero-secrets \
  --from-literal=postgres-password=changeme \
  -n aitherzero-preview

# Use in deployment
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: aitherzero-secrets
        key: postgres-password
```

**Azure Key Vault:**
```terraform
# Reference in Terraform
data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = azurerm_key_vault.main.id
}

# Use in container
environment_variables = {
  DB_PASSWORD = data.azurerm_key_vault_secret.db_password.value
}
```

### RBAC

**Kubernetes:**
```bash
# Create service account with limited permissions
kubectl create serviceaccount aitherzero-sa -n aitherzero-preview

# Bind to role
kubectl create rolebinding aitherzero-binding \
  --clusterrole=edit \
  --serviceaccount=aitherzero-preview:aitherzero-sa \
  -n aitherzero-preview
```

**Azure:**
```terraform
# Use managed identity
identity {
  type = "SystemAssigned"
}
```

## 📊 Monitoring

### Kubernetes

**Prometheus & Grafana:**
```bash
# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack

# Create ServiceMonitor
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: aitherzero
  namespace: aitherzero-preview
spec:
  selector:
    matchLabels:
      app: aitherzero
  endpoints:
  - port: http
    path: /metrics
EOF
```

**Logs:**
```bash
# View logs
kubectl logs -f deployment/aitherzero -n aitherzero-preview

# Aggregate with Loki
kubectl apply -f https://raw.githubusercontent.com/grafana/loki/main/production/loki-stack/loki-stack.yaml
```

### Azure

**Container Insights:**
```terraform
# Enable monitoring
log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

diagnostics {
  log_analytics {
    workspace_id = azurerm_log_analytics_workspace.main.workspace_id
  }
}
```

**View Logs:**
```bash
# Azure CLI
az container logs -g aitherzero-pr-123-rg-* -n aitherzero-pr-123-aci

# Azure Portal
az container show -g aitherzero-pr-123-rg-* -n aitherzero-pr-123-aci --query id -o tsv | \
  xargs -I {} az monitor log-analytics query \
    --workspace <workspace-id> \
    --analytics-query "ContainerInstanceLog_CL | where ContainerInstanceId_s == '{}'"
```

## 🔄 CI/CD Integration

### GitHub Actions

The infrastructure is automatically managed by GitHub Actions workflows:

1. **deploy-pr-environment.yml**: Creates environments on PR events
2. **cleanup-pr-environment.yml**: Removes environments on PR close

**Manual Trigger:**
```bash
# Deploy
gh workflow run deploy-pr-environment.yml \
  -f pr_number=123 \
  -f force_redeploy=true

# Cleanup
gh workflow run cleanup-pr-environment.yml \
  -f pr_number=123 \
  -f force_cleanup=true
```

### Automation Scripts

Located in `automation-scripts/`:

- **0850_Deploy-PREnvironment.ps1**: Deployment automation
- **0851_Cleanup-PREnvironment.ps1**: Cleanup automation

## 📈 Scaling

### Kubernetes Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: aitherzero-hpa
  namespace: aitherzero-preview
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: aitherzero
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Azure Scale Sets (Future)

For production deployments, consider Azure Container Apps or AKS with auto-scaling.

## 💰 Cost Optimization

### Best Practices

1. **Use TTL**: Set appropriate cleanup times
2. **Right-Size**: Choose smallest instance sizes that work
3. **Auto-Shutdown**: Configure shutdown schedules
4. **Spot Instances**: Use spot pricing where available
5. **Monitor**: Track costs with tags

### Cost Estimates

| Target | Monthly Cost (10 avg environments) |
|--------|-------------------------------------|
| Kubernetes (AKS) | $75-150 |
| Azure Container Instances | $20-40 |
| AWS Fargate | $25-50 |

## 🐛 Troubleshooting

### Common Issues

**Kubernetes Pod Won't Start:**
```bash
# Check events
kubectl describe pod -n aitherzero-preview

# Check logs
kubectl logs -f deployment/aitherzero -n aitherzero-preview --previous

# Common causes:
# 1. Image pull errors - check registry credentials
# 2. Resource limits - check node capacity
# 3. ConfigMap/Secret missing - verify they exist
```

**Azure Container Won't Start:**
```bash
# Check container logs
az container logs -g <resource-group> -n <container-name>

# Check events
az container show -g <resource-group> -n <container-name> --query instanceView.events

# Common causes:
# 1. Image not found - check registry/image name
# 2. Quota exceeded - check subscription limits
# 3. Network issues - verify NSG rules
```

**Terraform Apply Fails:**
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply ...

# Common causes:
# 1. Authentication - check az login
# 2. Quota - check subscription limits
# 3. Name conflicts - ensure unique names
```

## 📚 Additional Resources

- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Azure Container Instances**: https://learn.microsoft.com/en-us/azure/container-instances/
- **AitherZero Deployment Guide**: [../docs/PR-DEPLOYMENT-GUIDE.md](../docs/PR-DEPLOYMENT-GUIDE.md)

## 🤝 Contributing

Improvements to infrastructure definitions are welcome:

1. Test changes in dev environment first
2. Update documentation
3. Follow security best practices
4. Consider cost implications

---

**Last Updated**: 2025-10-27  
**Maintainers**: AitherZero Team
