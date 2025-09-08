# Grafana Loki Centralized Logging Setup

This setup implements Grafana Loki for centralized log aggregation across your containerized high-availability infrastructure.

## Architecture Overview

- **Bastion Nodes**: Run Loki server, Grafana, Prometheus, and Promtail
- **Backend Nodes**: Run Promtail agents to forward logs to Loki
- **Services Monitored**: Nginx, Keycloak, PostgreSQL/Patroni, etcd, Docker containers

## Components Added

### 1. Loki Server (Port 3100)

- Centralized log storage and indexing
- Configured with filesystem storage
- Accessible at `http://<bastion-ip>:3100`

### 2. Promtail Agents (Port 9080)

- **Bastion nodes**: Collect system logs, Docker logs, Nginx logs
- **Backend nodes**: Collect application logs (Keycloak, PostgreSQL, etcd)

### 3. Grafana Integration

- Loki data source automatically configured
- Access logs through Grafana at `http://<bastion-ip>:3000`

## Deployment Instructions

### 1. Deploy the Complete Stack

```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/deploy-loki.yml
```

### 2. Manual Step-by-Step Deployment

#### Deploy monitoring stack with Loki on bastion nodes:

```bash
ansible-playbook -i inventory/hosts playbooks/monitoring-bastion.yml
```

#### Deploy Promtail on backend nodes:

```bash
ansible-playbook -i inventory/hosts playbooks/monitoring-backend.yml
```

#### Configure application-specific logging:

```bash
# Configure Nginx structured logging
ansible-playbook -i inventory/hosts playbooks/nginx-logs.yml

# Configure Keycloak logging
ansible-playbook -i inventory/hosts playbooks/keycloak-logs.yml

# Configure PostgreSQL/Patroni logging
ansible-playbook -i inventory/hosts playbooks/patroni-logs.yml
```

## Accessing Logs

### 1. Through Grafana (Recommended)

1. Open Grafana: `http://<bastion-ip>:3000`
2. Login: admin/admin
3. Go to "Explore" section
4. Select "Loki" data source
5. Use LogQL queries to search logs

### 2. Direct Loki API

```bash
# Query logs directly
curl -G -s "http://<bastion-ip>:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="nginx"}' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-01-01T23:59:59Z'
```

## Log Query Examples

### LogQL Query Examples:

```logql
# All nginx access logs
{job="nginx"}

# Error logs from all services
{level="error"}

# Keycloak authentication events
{job="keycloak"} |= "authentication"

# PostgreSQL slow queries
{job="patroni"} |= "slow query"

# Docker container logs for specific service
{job="docker",container_name="keycloak"}

# System logs with specific service
{job="syslog",service="systemd"}

# Logs from specific backend node
{job="docker",node="backend"}
```

## Configuration Files

### Loki Configuration

- **File**: `monitoring/loki-config.yml`
- **Purpose**: Loki server configuration with filesystem storage

### Promtail Configurations

- **Bastion**: `monitoring/promtail-config.yml`
  - Collects: Docker logs, system logs, Nginx logs
- **Backend**: `monitoring/promtail-backend-config.yml`
  - Collects: Docker logs, Keycloak logs, PostgreSQL logs, etcd logs

### Updated Docker Compose

- **File**: `monitoring/docker-compose.yml`
- **Added**: Loki and Promtail services alongside Prometheus and Grafana

## Troubleshooting

### 1. Check Container Status

```bash
# On bastion nodes
docker ps | grep -E "(loki|promtail|grafana)"

# On backend nodes
docker ps | grep promtail
```

### 2. Check Loki Health

```bash
curl http://<bastion-ip>:3100/ready
curl http://<bastion-ip>:3100/metrics
```

### 3. Check Promtail Health

```bash
curl http://<bastion-ip>:9080/ready
curl http://<bastion-ip>:9080/metrics
```

### 4. View Container Logs

```bash
# Loki logs
docker logs loki

# Promtail logs
docker logs promtail
```

### 5. Test Log Ingestion

```bash
# Send test log to Loki
curl -v -H "Content-Type: application/json" -XPOST \
  "http://<bastion-ip>:3100/loki/api/v1/push" \
  --data-raw '{"streams": [{ "stream": { "job": "test" }, "values": [ [ "'$(date +%s)'000000000", "test log message" ] ] }]}'
```

## Ports Used

- **3100**: Loki server
- **9080**: Promtail
- **3000**: Grafana (existing)
- **9090**: Prometheus (existing)

## Log Retention

- **Loki**: Configured for long-term storage with filesystem backend
- **Local logs**: Rotated daily, kept for 30 days via logrotate
- **Docker logs**: Limited to 100MB per container, 3 files max

## Performance Considerations

1. **Storage**: Loki uses `/loki` volume for log storage
2. **Memory**: Loki configured with 100MB embedded cache
3. **Network**: Backend Promtail agents send logs to bastion Loki
4. **Retention**: Configure retention policies based on storage capacity

## Security Notes

1. Loki runs without authentication (internal network)
2. Promtail reads logs with appropriate permissions
3. Network traffic between Promtail and Loki is unencrypted (internal)
4. Consider adding authentication and TLS for production deployments
