# /monitor

Real-time system monitoring and health management for AitherZero infrastructure.

## Usage
```
/monitor [action] [options]
```

## Actions

### `dashboard` - System overview and metrics
Display comprehensive system health and performance metrics.

**Options:**
- `--system [all|specific]` - Target systems (default: all)
- `--timeframe [1h|4h|24h|7d]` - Time range for metrics (default: 1h)
- `--detailed` - Show detailed performance breakdown
- `--export` - Export dashboard data

**Examples:**
```bash
/monitor dashboard --system all --timeframe 4h
/monitor dashboard --system web-servers --detailed
/monitor dashboard --timeframe 24h --export
```

### `alerts` - Alert management and notification
View and manage active alerts and notifications.

**Options:**
- `--active` - Show only active alerts
- `--severity [critical|high|medium|low]` - Filter by severity level
- `--acknowledge` - Acknowledge specified alerts
- `--mute [duration]` - Temporarily mute alerts

**Examples:**
```bash
/monitor alerts --active --severity critical
/monitor alerts --acknowledge --id ALERT001,ALERT002
/monitor alerts --mute 30m --type maintenance
```

### `performance` - Detailed performance analysis
Analyze system performance metrics and identify bottlenecks.

**Options:**
- `--host [hostname]` - Target specific host
- `--metrics [cpu,memory,disk,network]` - Specific metrics to analyze
- `--baseline` - Compare against established baseline
- `--optimize` - Suggest performance optimizations

**Examples:**
```bash
/monitor performance --host webserver01 --metrics cpu,memory
/monitor performance --host database --baseline --optimize
/monitor performance --metrics network --timeframe 1h
```

### `services` - Service status monitoring
Monitor the health and status of system services.

**Options:**
- `--status [running|stopped|error]` - Filter by service status
- `--category [web,database,messaging]` - Filter by service category
- `--restart` - Restart services with errors
- `--dependencies` - Show service dependencies

**Examples:**
```bash
/monitor services --status error --restart
/monitor services --category web --dependencies
/monitor services --status all --detailed
```

### `logs` - Log analysis and monitoring
Search, analyze, and monitor system logs in real-time.

**Options:**
- `--search [query]` - Search pattern or keywords
- `--since [timeframe]` - Time range for log search
- `--tail [lines]` - Show latest N lines
- `--follow` - Continue monitoring new logs
- `--severity [error|warn|info|debug]` - Filter by log level

**Examples:**
```bash
/monitor logs --search "database connection" --since 1h
/monitor logs --severity error --tail 50 --follow
/monitor logs --search "authentication failed" --since 24h
```

### `baseline` - Performance baseline management
Establish and manage performance baselines for systems.

**Options:**
- `--establish` - Create new baseline from current metrics
- `--hosts [hostlist]` - Target specific hosts
- `--duration [timeframe]` - Baseline collection period
- `--compare` - Compare current performance to baseline
- `--update` - Update existing baseline

**Examples:**
```bash
/monitor baseline --establish --hosts production --duration 7d
/monitor baseline --compare --hosts web-cluster
/monitor baseline --update --hosts all
```

### `health` - Comprehensive health checking
Perform comprehensive health checks with automated remediation.

**Options:**
- `--comprehensive` - Full system health check
- `--autofix [minor|major|all]` - Automatic issue remediation
- `--report` - Generate health report
- `--schedule [cron]` - Schedule recurring health checks

**Examples:**
```bash
/monitor health --comprehensive --autofix minor
/monitor health --report --schedule "0 */6 * * *"
/monitor health --autofix all --notify admins
```

## Integration Features

### Claude Code AI Integration
- **Natural Language Queries**: "Show me CPU usage for web servers in the last hour"
- **Intelligent Alerts**: AI-powered alert correlation and root cause analysis
- **Predictive Monitoring**: ML-based performance trend prediction
- **Automated Insights**: AI-generated recommendations for optimization

### Real-time Capabilities
- **Live Dashboards**: Real-time metrics visualization
- **Streaming Alerts**: Instant notification of critical issues
- **Auto-scaling Triggers**: Automated scaling based on performance metrics
- **Self-healing**: Automatic remediation of common issues

### Security Integration
- **Access Control**: Role-based monitoring permissions
- **Audit Logging**: Complete audit trail of monitoring actions
- **Secure Metrics**: Encrypted metric transmission and storage
- **Compliance Reporting**: Automated compliance status reporting

## Configuration

### Default Monitoring Targets
- System performance (CPU, Memory, Disk, Network)
- Service health and availability
- Application performance metrics
- Infrastructure resource utilization
- Security event monitoring

### Alert Thresholds
- **Critical**: CPU > 90%, Memory > 95%, Disk > 98%
- **High**: CPU > 80%, Memory > 85%, Disk > 90%
- **Medium**: CPU > 70%, Memory > 75%, Disk > 80%
- **Low**: Performance degradation trends

### Retention Policies
- **Real-time metrics**: 1 hour granularity, 7 days retention
- **Hourly aggregates**: 1 hour granularity, 30 days retention
- **Daily aggregates**: 1 day granularity, 1 year retention
- **Alert history**: Full detail, 90 days retention

This monitoring system provides comprehensive visibility into AitherZero infrastructure with AI-powered insights and automated remediation capabilities.