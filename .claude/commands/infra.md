# /infra

Infrastructure deployment and management using OpenTofu/Terraform with enterprise-grade automation.

## Usage
```
/infra [action] [options]
```

## Actions

### `deploy` - Infrastructure deployment
Deploy infrastructure using OpenTofu/Terraform configurations with validation and compliance checks.

**Options:**
- `--env [environment]` - Target environment (dev, staging, production)
- `--template [template-name]` - Infrastructure template to deploy
- `--config [config-file]` - Custom configuration file
- `--validate` - Validate before deployment
- `--plan` - Show deployment plan without executing
- `--auto-approve` - Skip manual approval for automation
- `--sync` - Synchronize with Git remote before deployment
- `--powershell-mode [auto|5.1|7]` - PowerShell compatibility mode

**Examples:**
```bash
/infra deploy --env production --template web-cluster --validate
/infra deploy --env staging --config custom-vpc.tf --plan
/infra deploy --env dev --template minimal-web --auto-approve
```

### `status` - Infrastructure status and health
Check the current status and health of deployed infrastructure.

**Options:**
- `--all` - Show status for all environments
- `--env [environment]` - Specific environment status
- `--detailed` - Detailed resource information
- `--drift` - Check for configuration drift
- `--costs` - Show cost breakdown

**Examples:**
```bash
/infra status --all --detailed
/infra status --env production --drift --costs
/infra status --env staging --detailed
```

### `scale` - Infrastructure scaling operations
Scale infrastructure components up or down based on demand.

**Options:**
- `--service [service-name]` - Service to scale
- `--instances [number]` - Target instance count
- `--auto` - Enable auto-scaling
- `--cpu-target [percentage]` - CPU utilization target for auto-scaling
- `--schedule [cron]` - Scheduled scaling operations

**Examples:**
```bash
/infra scale --service webapp --instances 5
/infra scale --service api --auto --cpu-target 70
/infra scale --service worker --instances 10 --schedule "0 8 * * MON-FRI"
```

### `rollback` - Infrastructure rollback operations
Rollback infrastructure changes to previous stable state.

**Options:**
- `--deployment [deployment-id]` - Specific deployment to rollback
- `--reason [reason]` - Reason for rollback (required)
- `--validate` - Validate rollback plan
- `--force` - Force rollback without validation
- `--preserve-data` - Preserve data during rollback

**Examples:**
```bash
/infra rollback --deployment latest --reason "performance issues"
/infra rollback --deployment deploy-20241228 --validate --preserve-data
/infra rollback --deployment latest --force --reason "security vulnerability"
```

### `validate` - Infrastructure validation and compliance
Validate infrastructure against security standards and best practices.

**Options:**
- `--config [config-path]` - Configuration to validate
- `--standards [cis,nist,soc2,pci]` - Compliance standards to check
- `--security` - Security-focused validation
- `--report` - Generate compliance report
- `--fix` - Auto-fix minor compliance issues

**Examples:**
```bash
/infra validate --config production --standards cis,nist --report
/infra validate --config staging --security --fix
/infra validate --config all --standards soc2 --report
```

### `templates` - Infrastructure template management
Manage infrastructure templates and configurations.

**Options:**
- `--list` - List available templates
- `--category [web,database,network,security]` - Filter by category
- `--create [template-name]` - Create new template
- `--update [template-name]` - Update existing template
- `--export [template-name]` - Export template configuration

**Examples:**
```bash
/infra templates --list --category web,database
/infra templates --create secure-web-tier --category web
/infra templates --export production-vpc --format json
```

### `costs` - Infrastructure cost analysis
Analyze and optimize infrastructure costs with recommendations.

**Options:**
- `--analyze` - Analyze current costs
- `--timeframe [7d|30d|90d]` - Analysis timeframe
- `--optimize` - Get cost optimization recommendations
- `--budget [amount]` - Set budget alerts
- `--forecast` - Generate cost forecasts

**Examples:**
```bash
/infra costs --analyze --timeframe 30d --optimize
/infra costs --forecast --timeframe 90d
/infra costs --budget 5000 --currency USD --alert 80%
```

### `environments` - Environment management
Manage multiple infrastructure environments with promotion workflows.

**Options:**
- `--list` - List all environments
- `--create [env-name]` - Create new environment
- `--promote [from-env] [to-env]` - Promote configuration between environments
- `--clone [source-env] [target-env]` - Clone environment configuration
- `--destroy [env-name]` - Destroy environment (with confirmation)

**Examples:**
```bash
/infra environments --list
/infra environments --promote staging production --validate
/infra environments --clone production disaster-recovery
```

## Supported Infrastructure Components

### Compute Resources
- **Virtual Machines**: AWS EC2, Azure VMs, GCP Compute Engine
- **Container Platforms**: EKS, AKS, GKE, Docker Swarm
- **Serverless**: Lambda, Azure Functions, Cloud Functions
- **Bare Metal**: Physical server provisioning

### Networking
- **Virtual Networks**: VPCs, VNets, Cloud Networks
- **Load Balancers**: Application and Network Load Balancers
- **CDN**: CloudFront, Azure CDN, Cloud CDN
- **DNS**: Route53, Azure DNS, Cloud DNS

### Storage
- **Block Storage**: EBS, Azure Disks, Persistent Disks
- **Object Storage**: S3, Azure Blob, Cloud Storage
- **File Systems**: EFS, Azure Files, Cloud Filestore
- **Backup**: Automated backup solutions

### Databases
- **Relational**: RDS, SQL Database, Cloud SQL
- **NoSQL**: DynamoDB, Cosmos DB, Firestore
- **Data Warehousing**: Redshift, Synapse, BigQuery
- **Caching**: ElastiCache, Redis Cache, Memorystore

### Security
- **Identity Management**: IAM, Azure AD, Cloud IAM
- **Key Management**: KMS, Key Vault, Cloud KMS
- **Network Security**: Security Groups, NSGs, Firewall Rules
- **Compliance**: Automated compliance validation

## Advanced Features

### Multi-Cloud Support
- **Cloud-agnostic templates** for portability
- **Cross-cloud networking** configuration
- **Unified cost management** across providers
- **Multi-cloud disaster recovery** setups

### GitOps Integration
- **Infrastructure as Code** version control
- **Automated deployment pipelines** with CI/CD
- **Pull request workflows** for infrastructure changes
- **Automated testing** of infrastructure code

### Compliance and Governance
- **Policy as Code** with OPA (Open Policy Agent)
- **Automated compliance scanning** against standards
- **Governance rules** for resource deployment
- **Cost governance** and budget enforcement

### Disaster Recovery
- **Automated backup** of infrastructure state
- **Cross-region replication** capabilities
- **Disaster recovery testing** automation
- **Recovery time objective (RTO)** optimization

## Claude Code AI Integration

### Natural Language Infrastructure Management
- **Conversational Deployment**: "Deploy a high-availability web application in production"
- **Intelligent Recommendations**: AI-powered architecture suggestions
- **Cost Optimization**: ML-based cost optimization recommendations
- **Security Analysis**: AI-enhanced security posture assessment

### Automated Decision Making
- **Smart Scaling**: AI-driven auto-scaling decisions
- **Resource Optimization**: Intelligent resource rightsizing
- **Failure Prediction**: ML-based infrastructure failure prediction
- **Maintenance Scheduling**: AI-optimized maintenance windows

### Integration with Monitoring
- **Performance-driven Scaling**: Scale based on monitoring data
- **Health-based Deployments**: Deploy only when infrastructure is healthy
- **Alert-driven Actions**: Automated responses to infrastructure alerts
- **Predictive Maintenance**: Proactive infrastructure maintenance

This infrastructure management system provides enterprise-grade automation with AI-powered optimization and comprehensive multi-cloud support.