# /service

Comprehensive service lifecycle management for Windows and Linux systems.

## Usage
```
/service [action] [options]
```

## Actions

### `list` - Service inventory and status
Display comprehensive service inventory across all managed systems.

**Options:**
- `--platform [windows|linux|all]` - Target platform (default: all)
- `--status [running|stopped|error|all]` - Filter by service status
- `--category [web,database,messaging,system]` - Service categories
- `--detailed` - Show detailed service information
- `--export` - Export service inventory

**Examples:**
```bash
/service list --platform all --status running
/service list --category web,database --detailed
/service list --status error --platform linux
```

### `restart` - Service restart operations
Restart services with safety checks and dependency management.

**Options:**
- `--name [service-name]` - Specific service to restart
- `--hosts [hostlist]` - Target specific hosts or host groups
- `--cascade` - Restart dependent services
- `--graceful` - Graceful shutdown before restart
- `--wait [seconds]` - Wait time between stop and start

**Examples:**
```bash
/service restart --name nginx --hosts web-cluster
/service restart --name webapp --graceful --cascade
/service restart --name database --wait 30 --notify admins
```

### `deploy` - Service deployment and updates
Deploy new service versions with rolling update strategies.

**Options:**
- `--package [package-name]` - Service package to deploy
- `--version [version]` - Specific version to deploy
- `--strategy [rolling|blue-green|canary]` - Deployment strategy
- `--rollback` - Rollback to previous version
- `--validate` - Validate deployment before proceeding

**Examples:**
```bash
/service deploy --package webapp --version v2.1.0 --strategy rolling
/service deploy --package api-service --strategy blue-green --validate
/service deploy --rollback --package webapp --reason "performance issues"
```

### `config` - Service configuration management
Manage service configurations with backup and validation.

**Options:**
- `--name [service-name]` - Target service
- `--update` - Update service configuration
- `--backup` - Backup current configuration
- `--restore [backup-id]` - Restore from backup
- `--validate` - Validate configuration changes
- `--restart` - Restart service after configuration change

**Examples:**
```bash
/service config --name nginx --backup --update --restart
/service config --name database --restore backup-20241228
/service config --name webapp --validate --update
```

### `dependencies` - Service dependency management
Analyze and manage service dependencies and startup order.

**Options:**
- `--analyze` - Analyze service dependencies
- `--service [service-name]` - Focus on specific service
- `--map` - Generate dependency map
- `--order` - Show startup order
- `--health` - Check dependency health

**Examples:**
```bash
/service dependencies --analyze --service webapp --map
/service dependencies --service database --health
/service dependencies --order --platform linux
```

### `recovery` - Automated service recovery
Configure and execute automated service recovery procedures.

**Options:**
- `--auto` - Enable automatic recovery
- `--service [service-name|critical-only]` - Target services
- `--attempts [number]` - Maximum recovery attempts
- `--escalate` - Escalate to manual intervention if needed
- `--notify` - Notification settings for recovery actions

**Examples:**
```bash
/service recovery --auto --service critical-only --attempts 3
/service recovery --service webapp --escalate --notify admins
/service recovery --auto --service all --attempts 2
```

### `orchestrate` - Service orchestration workflows
Execute complex service orchestration and maintenance workflows.

**Options:**
- `--workflow [workflow-name]` - Predefined workflow to execute
- `--schedule [cron|datetime]` - Schedule workflow execution
- `--preview` - Preview workflow steps without execution
- `--parallel` - Execute compatible steps in parallel
- `--rollback-plan` - Generate rollback plan

**Examples:**
```bash
/service orchestrate --workflow maintenance --schedule "2024-12-29 02:00"
/service orchestrate --workflow rolling-update --preview
/service orchestrate --workflow disaster-recovery --parallel
```

### `monitor` - Service monitoring and alerting
Configure and manage service-specific monitoring and alerting.

**Options:**
- `--enable` - Enable monitoring for services
- `--disable` - Disable monitoring
- `--thresholds` - Configure alert thresholds
- `--health-check` - Configure health check parameters
- `--sla` - Set SLA targets

**Examples:**
```bash
/service monitor --enable --service webapp --thresholds custom
/service monitor --health-check --service api --interval 30s
/service monitor --sla --service critical --uptime 99.9%
```

## Service Categories and Platforms

### Supported Platforms
- **Windows Services**: Windows Service Manager integration
- **Linux Services**: systemd, SysV init, and Upstart support
- **Docker Containers**: Container lifecycle management
- **Kubernetes Pods**: Kubernetes service orchestration

### Service Categories
- **Web Services**: Nginx, Apache, IIS, application servers
- **Database Services**: SQL Server, PostgreSQL, MySQL, MongoDB
- **Messaging**: RabbitMQ, Apache Kafka, Redis
- **System Services**: DNS, DHCP, NTP, backup services
- **Application Services**: Custom business applications
- **Monitoring Services**: Monitoring agents and collectors

## Advanced Features

### Rolling Deployments
- **Zero-downtime deployments** with health check validation
- **Traffic shifting** during deployment process
- **Automatic rollback** on deployment failure
- **Canary releases** with percentage-based traffic splitting

### Service Mesh Integration
- **Service discovery** and registration
- **Load balancing** configuration
- **Circuit breaker** pattern implementation
- **Distributed tracing** integration

### High Availability
- **Active-passive clustering** for database services
- **Load balancer integration** for web services
- **Failover automation** with health monitoring
- **Geographic distribution** support

### Security and Compliance
- **Service account management** with least privilege
- **Certificate management** and rotation
- **Access control** and authorization
- **Audit logging** for all service operations
- **Compliance reporting** for regulatory requirements

## Integration Points

### Claude Code AI Features
- **Natural Language Service Control**: "Restart the web servers in production"
- **Intelligent Dependency Resolution**: AI-powered dependency analysis
- **Predictive Maintenance**: ML-based service health prediction
- **Automated Troubleshooting**: AI-guided problem resolution

### Monitoring Integration
- **Performance Metrics**: Integration with /monitor commands
- **Alert Correlation**: Service alerts with system monitoring
- **Health Dashboards**: Service-specific monitoring views
- **SLA Tracking**: Service level agreement monitoring

### Infrastructure Integration
- **Load Balancer Updates**: Automatic load balancer configuration
- **DNS Updates**: Service discovery and DNS management
- **Firewall Rules**: Security rule management for services
- **Backup Integration**: Service-aware backup scheduling

This service management system provides enterprise-grade service lifecycle control with AI-powered automation and comprehensive platform support.