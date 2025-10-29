# PR Branch Deployment - Quick Reference

## 🚀 Quick Commands

### Deploy PR Environment
```powershell
# Automatic (GitHub Actions) - Just open/update PR

# Manual (Docker)
./automation-scripts/0810_Deploy-PREnvironment.ps1 -PRNumber 123 -DeploymentTarget Docker

# Manual (Kubernetes)
./automation-scripts/0810_Deploy-PREnvironment.ps1 -PRNumber 123 -DeploymentTarget Kubernetes
```

### Access Environment
```bash
# Docker
http://localhost:808{last-digit}    # e.g., PR #123 → :8083
docker logs aitherzero-pr-123 -f

# Kubernetes
kubectl get ingress -n aitherzero-pr-123
kubectl logs -f deployment/aitherzero -n aitherzero-pr-123
```

### Test Environment
```bash
# Docker
docker exec aitherzero-pr-123 pwsh -Command "./az.ps1 0402"

# Kubernetes
kubectl exec deployment/aitherzero -n aitherzero-pr-123 -- pwsh -Command "./az.ps1 0402"
```

### Cleanup Environment
```powershell
# Automatic - Close/merge PR

# Manual
./automation-scripts/0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Force
```

## 📋 Workflow Triggers

### Automatic Deployment
- PR opened (non-draft)
- PR updated (new commits)
- Comment `/deploy` on PR

### Automatic Cleanup
- PR closed/merged
- Scheduled (daily 2 AM UTC)
- Environment age > 72 hours

## 🔍 Troubleshooting One-Liners

```bash
# Check if environment exists
docker ps -a | grep aitherzero-pr-123
kubectl get namespace | grep aitherzero-pr-123

# View deployment status
docker inspect aitherzero-pr-123
kubectl get all -n aitherzero-pr-123

# Force restart
docker restart aitherzero-pr-123
kubectl rollout restart deployment/aitherzero -n aitherzero-pr-123

# Complete cleanup
docker rm -f $(docker ps -a | grep aitherzero-pr- | awk '{print $1}')
kubectl delete namespace $(kubectl get ns | grep aitherzero-pr- | awk '{print $1}')
```

## 📊 Status Checks

```bash
# Deployment health
docker exec aitherzero-pr-123 pwsh -Command "Test-Path /opt/aitherzero/AitherZero.psd1"
kubectl exec deployment/aitherzero -n aitherzero-pr-123 -- pwsh -Command "Get-Module AitherZero"

# Resource usage
docker stats aitherzero-pr-123 --no-stream
kubectl top pod -n aitherzero-pr-123

# Logs (last 100 lines)
docker logs aitherzero-pr-123 --tail 100
kubectl logs deployment/aitherzero -n aitherzero-pr-123 --tail=100
```

## 🎛️ Common Configurations

### Docker Resource Limits
```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

### Kubernetes Resource Limits
```yaml
# deployment.yml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### Azure TTL
```terraform
# pr-environment.tf
variable "ttl_hours" {
  default = 48  # Change here
}
```

## 🔗 Important Files

| File | Purpose |
|------|---------|
| `.github/workflows/deploy-pr-environment.yml` | Deployment workflow |
| `.github/workflows/cleanup-pr-environment.yml` | Cleanup workflow |
| `automation-scripts/0810_Deploy-PREnvironment.ps1` | Deployment script |
| `automation-scripts/0851_Cleanup-PREnvironment.ps1` | Cleanup script |
| `Dockerfile` | Container definition |
| `docker-compose.yml` | Docker Compose config |
| `infrastructure/kubernetes/deployment.yml` | Kubernetes manifests |
| `infrastructure/terraform/pr-environment.tf` | Terraform config |
| `docs/PR-DEPLOYMENT-GUIDE.md` | Full documentation |

## 🆘 Emergency Procedures

### Complete Teardown
```bash
# Docker
docker stop $(docker ps -a | grep aitherzero-pr- | awk '{print $1}')
docker rm $(docker ps -a | grep aitherzero-pr- | awk '{print $1}')
docker volume prune -f
rm -f docker-compose.pr-*.yml

# Kubernetes
kubectl delete namespace $(kubectl get ns | grep aitherzero-pr- | awk '{print $1}')

# Azure
az group list --query "[?starts_with(name, 'aitherzero-pr-')].name" -o tsv | xargs -I {} az group delete -n {} --yes --no-wait
```

### Reset Everything
```bash
# Stop all AitherZero containers
docker ps -a | grep aitherzero | awk '{print $1}' | xargs docker rm -f

# Delete all AitherZero volumes
docker volume ls | grep aitherzero | awk '{print $2}' | xargs docker volume rm

# Clean all compose files
rm -f docker-compose.pr-*.yml

# Delete all K8s namespaces
kubectl get ns | grep aitherzero | awk '{print $1}' | xargs kubectl delete namespace
```

## 📞 Getting Help

1. **Check logs**: Always start with container/pod logs
2. **GitHub Actions**: Review workflow run details
3. **Documentation**: See `docs/PR-DEPLOYMENT-GUIDE.md`
4. **Issues**: Create issue with `deployment` label
5. **Command test**: Run with `-Verbose` for detailed output

---

**Pro Tip**: Add `export PRNUMBER=123` to your shell for easier commands:
```bash
export PRNUMBER=123
docker logs aitherzero-pr-$PRNUMBER -f
kubectl get all -n aitherzero-pr-$PRNUMBER
```
