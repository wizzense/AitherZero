# PR Branch Deployment Setup Checklist

Use this checklist to set up automated PR branch deployments for your organization.

## 📋 Pre-Setup Assessment

- [ ] Reviewed architecture documentation (`docs/PR-DEPLOYMENT-GUIDE.md`)
- [ ] Determined primary deployment target (Docker/Kubernetes/Azure)
- [ ] Assessed budget for cloud resources (if applicable)
- [ ] Identified team members responsible for setup and maintenance
- [ ] Reviewed security requirements and compliance needs

## 🔧 Docker Setup (Recommended for Quick Start)

### Prerequisites
- [ ] Docker Engine 20.10+ installed on Actions runners
- [ ] Docker Compose 2.0+ installed on Actions runners

### Configuration
- [ ] No additional configuration needed
- [ ] Test Docker availability: `docker --version`
- [ ] Test Compose availability: `docker-compose --version`

### Testing
- [ ] Build image locally: `docker build -t aitherzero:test .`
- [ ] Run container: `docker run -d --name test aitherzero:test`
- [ ] Test module loading: `docker exec test pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1"`
- [ ] Cleanup: `docker rm -f test`

**Status:** ✅ Ready for use immediately

---

## ☸️ Kubernetes Setup

### Prerequisites
- [ ] Kubernetes cluster available (AKS, EKS, GKE, or self-hosted)
- [ ] kubectl installed and configured
- [ ] Container registry accessible (ghcr.io, ACR, ECR, etc.)
- [ ] Ingress controller installed (nginx recommended)
- [ ] cert-manager installed (optional, for TLS)

### GitHub Secrets (if using private registry)
- [ ] `REGISTRY_USERNAME`: Container registry username
- [ ] `REGISTRY_PASSWORD`: Container registry password/token

### Configuration
- [ ] Update container registry in `.github/workflows/deploy-pr-environment.yml`:
  ```yaml
  env:
    CONTAINER_REGISTRY: ghcr.io  # Change if needed
    IMAGE_NAME: ${{ github.repository }}/aitherzero
  ```

- [ ] Update ingress hostname in `infrastructure/kubernetes/deployment.yml`:
  ```yaml
  spec:
    rules:
    - host: aitherzero-preview.example.com  # Change to your domain
  ```

- [ ] Configure TLS certificate (if using cert-manager):
  ```yaml
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Verify issuer exists
  ```

### Testing
- [ ] Verify cluster access: `kubectl get nodes`
- [ ] Create test namespace: `kubectl create namespace test-aitherzero`
- [ ] Apply manifests: `kubectl apply -f infrastructure/kubernetes/deployment.yml -n test-aitherzero`
- [ ] Check deployment: `kubectl get all -n test-aitherzero`
- [ ] Cleanup: `kubectl delete namespace test-aitherzero`

**Status:** Ready when prerequisites met

---

## ☁️ Azure Setup (Terraform)

### Prerequisites
- [ ] Azure subscription with appropriate permissions
- [ ] Azure CLI installed and authenticated
- [ ] Terraform 1.0+ installed
- [ ] Container registry (Azure Container Registry or ghcr.io)

### Azure Resources Setup
- [ ] Create service principal for Terraform:
  ```bash
  az ad sp create-for-rbac --name "aitherzero-terraform" --role contributor \
    --scopes /subscriptions/{subscription-id}
  ```
  
- [ ] Note the output values:
  - `appId` → `AZURE_CLIENT_ID`
  - `password` → `AZURE_CLIENT_SECRET`
  - `tenant` → `AZURE_TENANT_ID`

- [ ] Get subscription ID:
  ```bash
  az account show --query id -o tsv
  ```

### GitHub Secrets
- [ ] Add `AZURE_CLIENT_ID`
- [ ] Add `AZURE_CLIENT_SECRET`
- [ ] Add `AZURE_SUBSCRIPTION_ID`
- [ ] Add `AZURE_TENANT_ID`

### Terraform Backend (Optional but Recommended)
- [ ] Create storage account for Terraform state:
  ```bash
  az group create --name aitherzero-terraform-state --location eastus
  az storage account create --name aitherzerstate --resource-group aitherzero-terraform-state --location eastus --sku Standard_LRS
  az storage container create --name tfstate --account-name aitherzerstate
  ```

- [ ] Configure backend in `infrastructure/terraform/pr-environment.tf`:
  ```terraform
  backend "azurerm" {
    resource_group_name  = "aitherzero-terraform-state"
    storage_account_name = "aitherzerstate"
    container_name       = "tfstate"
    key                  = "preview-environments.tfstate"
  }
  ```

### Configuration
- [ ] Review and customize variables in `infrastructure/terraform/pr-environment.tf`:
  - `location`: Azure region (default: eastus)
  - `instance_size`: VM size (default: Standard_B2s)
  - `ttl_hours`: Cleanup time (default: 48)
  - `auto_shutdown_time`: Shutdown time (default: 20:00)

- [ ] Update container image in Terraform (if needed):
  ```terraform
  image = "aitherzero:latest"  # Update registry/image name
  ```

### Testing
- [ ] Initialize Terraform: `cd infrastructure/terraform && terraform init`
- [ ] Create test workspace: `terraform workspace new test-pr-999`
- [ ] Test plan:
  ```bash
  terraform plan \
    -var="pr_number=999" \
    -var="branch_name=test" \
    -var="commit_sha=test123"
  ```
- [ ] If plan succeeds, test apply (optional):
  ```bash
  terraform apply -auto-approve \
    -var="pr_number=999" \
    -var="branch_name=test" \
    -var="commit_sha=test123"
  ```
- [ ] Cleanup test resources:
  ```bash
  terraform destroy -auto-approve \
    -var="pr_number=999" \
    -var="branch_name=test" \
    -var="commit_sha=test123"
  terraform workspace select default
  terraform workspace delete test-pr-999
  ```

**Status:** Ready when all secrets configured

---

## 🔒 Security Configuration

### Secrets Management
- [ ] Review all secrets in GitHub repository settings
- [ ] Ensure secrets are scoped to appropriate environments
- [ ] Use GitHub Environments for production deployments
- [ ] Enable secret scanning in repository settings

### Access Control
- [ ] Configure branch protection rules for main branches
- [ ] Limit who can approve workflow runs
- [ ] Configure CODEOWNERS for infrastructure files
- [ ] Enable required reviews for PRs

### Network Security
- [ ] Review firewall rules (Docker: host firewall, K8s: NetworkPolicies, Azure: NSG)
- [ ] Configure private networking if required
- [ ] Enable DDoS protection for public endpoints (Azure/AWS)
- [ ] Set up VPN/bastion for admin access if needed

### Container Security
- [ ] Enable container scanning in registry
- [ ] Set up automated image updates
- [ ] Configure image signing (optional)
- [ ] Review and update base images regularly

**Status:** Ongoing maintenance required

---

## 💰 Cost Management

### Budget Setup
- [ ] Estimate monthly costs based on usage patterns
- [ ] Set up Azure/AWS cost budgets and alerts
- [ ] Configure spending limits if available
- [ ] Review and adjust resource limits

### Cost Optimization
- [ ] Configure appropriate TTL values (default: 48 hours)
- [ ] Set up auto-shutdown schedules
- [ ] Review instance sizes for right-sizing
- [ ] Enable spot/preemptible instances if applicable
- [ ] Set up cost tagging for tracking

### Monitoring
- [ ] Set up cost monitoring dashboard
- [ ] Configure alerts for unexpected spending
- [ ] Schedule weekly/monthly cost reviews
- [ ] Track cost per environment/PR

**Monthly Budget Estimates:**
- Docker (Local): $0
- Kubernetes (10 environments): $75-150
- Azure (10 environments): $20-40

---

## 📊 Monitoring & Logging

### GitHub Actions
- [ ] Enable detailed workflow logging
- [ ] Set up workflow failure notifications
- [ ] Configure Slack/Teams integration (optional)
- [ ] Review workflow run history regularly

### Container Monitoring
- [ ] Set up log aggregation (optional)
- [ ] Configure application monitoring (optional)
- [ ] Enable health check monitoring
- [ ] Set up alerting for failures

### Azure-Specific
- [ ] Enable Container Insights
- [ ] Configure Log Analytics workspace
- [ ] Set up custom metrics (optional)
- [ ] Create monitoring dashboard

**Status:** Basic monitoring included, advanced optional

---

## 🧪 Testing & Validation

### Pre-Production Testing
- [ ] Create test PR in non-production branch
- [ ] Verify automatic deployment triggers
- [ ] Test environment access and functionality
- [ ] Verify PR comments appear correctly
- [ ] Test manual deployment via comment (`/deploy`)
- [ ] Test cleanup on PR close
- [ ] Verify scheduled cleanup works

### Load Testing
- [ ] Test multiple concurrent deployments
- [ ] Verify resource limits are enforced
- [ ] Test cleanup of stale environments
- [ ] Verify TTL-based cleanup

### Failure Testing
- [ ] Test deployment failures (invalid image, etc.)
- [ ] Verify error reporting in PR comments
- [ ] Test cleanup of failed deployments
- [ ] Test manual cleanup procedures

**Status:** Complete testing before production rollout

---

## 📚 Documentation & Training

### Team Documentation
- [ ] Share PR-DEPLOYMENT-GUIDE.md with team
- [ ] Create internal wiki/documentation
- [ ] Document any organization-specific configurations
- [ ] Create troubleshooting runbooks

### Team Training
- [ ] Train developers on using PR environments
- [ ] Train ops team on monitoring and maintenance
- [ ] Train support team on troubleshooting
- [ ] Document escalation procedures

### Knowledge Base
- [ ] Document common issues and solutions
- [ ] Create FAQ document
- [ ] Set up support channels (Slack, Teams, etc.)
- [ ] Schedule regular review sessions

**Status:** Ongoing effort

---

## 🚀 Production Rollout

### Phase 1: Pilot (Week 1)
- [ ] Enable for 2-3 test PRs
- [ ] Monitor closely for issues
- [ ] Gather feedback from pilot users
- [ ] Document any issues encountered
- [ ] Make necessary adjustments

### Phase 2: Limited Release (Weeks 2-3)
- [ ] Enable for all feature branches
- [ ] Monitor resource usage and costs
- [ ] Continue gathering feedback
- [ ] Optimize based on usage patterns
- [ ] Document best practices

### Phase 3: General Availability (Week 4+)
- [ ] Enable for all PRs
- [ ] Full monitoring and alerting active
- [ ] Regular cost reviews scheduled
- [ ] Continuous optimization ongoing
- [ ] Team fully trained

**Current Phase:** Pre-rollout

---

## ✅ Go-Live Checklist

### Critical Items
- [ ] All prerequisites met for chosen deployment target
- [ ] All secrets configured in GitHub
- [ ] Security review completed
- [ ] Budget approved and alerts configured
- [ ] Team trained on usage
- [ ] Documentation accessible to team
- [ ] Support channels established
- [ ] Monitoring configured
- [ ] Rollback plan documented

### Validation
- [ ] Test deployment successful in pilot
- [ ] Cleanup working correctly
- [ ] PR comments displaying properly
- [ ] Costs within expected range
- [ ] No security issues identified
- [ ] Team comfortable with system

### Post-Launch
- [ ] Monitor first week closely
- [ ] Schedule daily check-ins
- [ ] Address issues promptly
- [ ] Gather continuous feedback
- [ ] Document lessons learned

---

## 📞 Support Contacts

### Technical Contacts
- **Infrastructure Lead**: _________________
- **DevOps Lead**: _________________
- **Security Lead**: _________________

### Escalation Path
1. Check documentation and logs
2. Review GitHub Actions workflow runs
3. Check repository issues
4. Contact infrastructure lead
5. Escalate to DevOps team

### Resources
- Documentation: `docs/PR-DEPLOYMENT-GUIDE.md`
- Quick Reference: `docs/PR-DEPLOYMENT-QUICKREF.md`
- Infrastructure Docs: `infrastructure/README.md`
- GitHub Issues: [Create Issue](../../issues/new)

---

## 📊 Success Metrics

Track these metrics for the first month:

- [ ] Deployment success rate: Target >95%
- [ ] Average deployment time: Target <5 minutes
- [ ] Cost per environment: Target <$5
- [ ] Developer satisfaction: Target >90%
- [ ] Cleanup success rate: Target >99%

**Review Date**: _________________  
**Status**: _________________  
**Notes**: _________________

---

**Setup Started**: _________________  
**Setup Completed**: _________________  
**Setup By**: _________________  
**Approved By**: _________________
