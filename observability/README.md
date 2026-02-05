# Observability

Monitoring, logging, and observability configurations for the Hyperion Fleet Manager.

## Structure

```
observability/
└── dashboards/        # Monitoring dashboards
    ├── grafana/      # Grafana dashboards
    ├── cloudwatch/   # CloudWatch dashboards
    └── datadog/      # Datadog dashboards
```

## Overview

This directory contains monitoring dashboards and observability configurations for comprehensive system visibility.

## Key Metrics

### Infrastructure Metrics

- CPU utilization
- Memory usage
- Disk I/O
- Network throughput
- Instance health

### Application Metrics

- Request rate
- Response time (p50, p95, p99)
- Error rate
- Throughput
- Concurrent connections

### Business Metrics

- Active fleets
- Total vehicles
- Deployment frequency
- Mean time to recovery (MTTR)
- Change failure rate

## Dashboards

### Grafana Dashboards

Located in `dashboards/grafana/`:

- **System Overview** - High-level system health
- **Infrastructure** - EC2, RDS, Lambda metrics
- **API Performance** - API request/response metrics
- **Fleet Operations** - Fleet-specific metrics
- **Database Performance** - RDS and DynamoDB metrics
- **Cache Performance** - Redis metrics

### CloudWatch Dashboards

Located in `dashboards/cloudwatch/`:

- **Production Overview** - Production environment health
- **Lambda Functions** - Serverless function metrics
- **Auto Scaling** - Scaling activity and metrics
- **Alarms** - Active alarms and notifications

## Monitoring Stack

### Metrics Collection

- **CloudWatch** - AWS native metrics
- **Prometheus** - Application metrics
- **StatsD** - Custom metrics
- **X-Ray** - Distributed tracing

### Log Aggregation

- **CloudWatch Logs** - Centralized logging
- **ELK Stack** - Log search and analysis
- **Fluentd** - Log forwarding

### Alerting

- **CloudWatch Alarms** - Infrastructure alerts
- **PagerDuty** - Incident management
- **SNS** - Notification delivery
- **Slack** - Team notifications

## Alerts Configuration

### Critical Alerts

- API error rate > 5%
- Database connection failures
- Disk usage > 85%
- Memory usage > 90%
- Auto-scaling events

### Warning Alerts

- API latency p95 > 500ms
- Cache hit rate < 80%
- Deployment duration > 15 minutes
- Queue depth increasing

## Log Management

### Log Levels

- **ERROR** - Application errors
- **WARN** - Warning conditions
- **INFO** - Informational messages
- **DEBUG** - Debugging information

### Log Retention

- Production: 90 days
- Staging: 30 days
- Development: 7 days

### Log Structure

```json
{
  "timestamp": "2026-02-04T16:05:23Z",
  "level": "INFO",
  "service": "fleet-api",
  "request_id": "abc-123",
  "message": "Request processed",
  "duration_ms": 45,
  "status_code": 200
}
```

## Distributed Tracing

### X-Ray Integration

- Trace all API requests
- Track downstream service calls
- Identify performance bottlenecks
- Visualize service map

### Trace Sampling

- Production: 5% sampling
- Staging: 25% sampling
- Development: 100% sampling

## Service Level Objectives (SLOs)

### Availability

- API: 99.9% uptime
- Database: 99.95% uptime
- Cache: 99.5% uptime

### Performance

- API p95 latency < 500ms
- API p99 latency < 1000ms
- Database query p95 < 100ms

### Error Budget

- Monthly error budget: 0.1%
- Alert when 50% consumed
- Freeze deployments at 80%

## Dashboard Usage

### Grafana

Import dashboards:

```bash
# Import dashboard
grafana-cli admin dashboard import dashboards/grafana/overview.json

# Export dashboard
grafana-cli admin dashboard export <dashboard-id> > dashboard.json
```

### CloudWatch

Deploy dashboards:

```bash
cd infrastructure
terraform apply -target=module.cloudwatch_dashboards
```

## Best Practices

- Monitor what matters
- Set actionable alerts
- Avoid alert fatigue
- Use SLIs and SLOs
- Implement distributed tracing
- Centralize logs
- Automate runbooks
- Review metrics regularly
- Test alerts
- Document dashboards

## Troubleshooting

### High Error Rate

1. Check CloudWatch Logs
2. Review X-Ray traces
3. Check recent deployments
4. Review infrastructure changes

### Performance Degradation

1. Review API latency metrics
2. Check database performance
3. Review cache hit rate
4. Check auto-scaling activity

### Missing Metrics

1. Verify agent configuration
2. Check IAM permissions
3. Review network connectivity
4. Validate metric filters

## Integration

### Prometheus

Configure in `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'fleet-api'
    static_configs:
      - targets: ['api:8080']
```

### Grafana Data Sources

Add Prometheus data source:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
```

## Custom Metrics

### Application Metrics

Expose custom metrics:

```go
// Go example
requestDuration := prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
        Name: "http_request_duration_seconds",
        Help: "HTTP request latency",
    },
    []string{"method", "endpoint"},
)
```

### Business Metrics

Track business KPIs:

```python
# Python example
fleet_count = Gauge('active_fleets_total', 'Total active fleets')
fleet_count.set(len(active_fleets))
```

## Runbooks

Link dashboards to runbooks:

- High error rate: `docs/runbooks/high-error-rate.md`
- Database issues: `docs/runbooks/database-issues.md`
- Performance degradation: `docs/runbooks/performance.md`

## Documentation

Each dashboard should include:

- Purpose and scope
- Key metrics explained
- Alert thresholds
- Related runbooks
- Troubleshooting steps
