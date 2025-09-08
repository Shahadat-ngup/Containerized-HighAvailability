# Containerized High Availability Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying a containerized high-availability infrastructure with monitoring and authentication.

## Infrastructure Components

- **Backend Nodes (3)**: PostgreSQL Patroni cluster + Keycloak
- **Bastion Nodes (2)**: Nginx proxy + Monitoring stack
- **Monitoring**: Prometheus, Grafana, Loki, Promtail
- **Security**: Nginx reverse proxy with basic authentication

---

## Systematic Deployment Order

### Phase 1: Infrastructure Preparation

#### 1. Configure Ansible Inventory

```bash
# Verify inventory file
cat ansible/inventory/hosts

# Test connectivity to all nodes
ansible all -i ansible/inventory/hosts -m ping
```

#### 2. Deploy Backend Infrastructure

```bash
# Deploy PostgreSQL Patroni cluster
source docker/backend/.env && ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-setup.yml -u shahadat --become

# Patch Patroni for database access
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/patch_pg_hba.yml -u <your_user> --become

# Post-deployment configuration (Keycloak setup)
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-post.yml -u <your_user> --become
```

### Phase 2: Proxy and Load Balancing

#### 3. Deploy Bastion Services

```bash
# Deploy Nginx proxy and SSL termination
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/bastion.yml -u <your_user> --become
```

### Phase 3: Monitoring Infrastructure

#### 4. Deploy Basic Monitoring

```bash
# Deploy monitoring exporters on backend nodes
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/monitoring-backend.yml -u <your_user> --become

# Deploy monitoring stack on bastion nodes
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/monitoring-bastion.yml -u <your_user> --become
```

#### 5. Deploy Advanced Monitoring (Loki)

```bash
# Deploy Loki logging stack
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-loki.yml -u <your_user> --become
```

### Phase 4: Security Implementation

#### 6. Secure Monitoring Services

```bash
# Implement Option 1: Nginx Authentication
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/secure-monitoring.yml -u <your_user> --become
```

---

## Post-Deployment Access URLs

### Production Services

- **Keycloak Admin**: `https://skeycloak.loseyourip.com/admin/`
  - Username: `admin`
  - Password: `SecureKeycloakAdmin2024`

### Monitoring Services (Secured)

- **Prometheus**: `http://<bastion-ip>:9090`

  - Username: `prometheus_admin`
  - Password: `SecurePrometheus2024`

- **Grafana**: `http://<bastion-ip>:9003`

  - Username: `admin`
  - Password: `SecureGrafanaAdmin2024`

- **Loki API**: `http://<bastion-ip>:3101`
  - Username: `prometheus_admin`
  - Password: `SecurePrometheus2024`

---

## Troubleshooting Commands

### General System Health

#### Check All Container Status

```bash
# All nodes container status
ansible all -i ansible/inventory/hosts -m shell -a "docker ps -a"

# Specific service groups
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker ps | grep -E '(patroni|keycloak)'"
ansible bastion -i ansible/inventory/hosts -m shell -a "docker ps | grep -E '(nginx|prometheus|grafana|loki)'"
```

#### Check Service Logs

```bash
# Backend services
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker logs patroni --tail 20"
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker logs keycloak --tail 20"

# Bastion services
ansible bastion -i ansible/inventory/hosts -m shell -a "docker logs iam-bastion_nginx_1 --tail 20"
ansible bastion -i ansible/inventory/hosts -m shell -a "docker logs prometheus --tail 20"
ansible bastion -i ansible/inventory/hosts -m shell -a "docker logs grafana --tail 20"
ansible bastion -i ansible/inventory/hosts -m shell -a "docker logs loki --tail 20"
```

### Network and Port Diagnostics

#### Check Port Bindings

```bash
# Check all listening ports
ansible all -i ansible/inventory/hosts -m shell -a "netstat -tlnp"

# Check specific monitoring ports
ansible bastion -i ansible/inventory/hosts -m shell -a "netstat -tlnp | grep ':9090\\|:9003\\|:3101'"

# Check backend database ports
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "netstat -tlnp | grep ':5432\\|:8080'"
```

#### Test Service Connectivity

```bash
# Test Prometheus API
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -u prometheus_admin:SecurePrometheus2024 http://localhost:9090/api/v1/status/config"

# Test Loki readiness
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -u prometheus_admin:SecurePrometheus2024 http://localhost:3101/ready"

# Test Grafana response
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -I http://localhost:9003/"

# Test Keycloak health
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "curl -I http://localhost:8080/health/ready"
```

### Database Diagnostics

#### PostgreSQL Cluster Status

```bash
# Check Patroni cluster status
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni patronictl list"

# Check PostgreSQL connectivity
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni psql -U postgres -c 'SELECT version();'"

# Check replication status
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"
```

#### Database Connection Test

```bash
# Test database from Keycloak
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password Passw0rd21"
```

### Configuration Validation

#### Nginx Configuration Test

```bash
# Test nginx configuration syntax
ansible bastion -i ansible/inventory/hosts -m shell -a "docker exec iam-bastion_nginx_1 nginx -t"

# Reload nginx configuration
ansible bastion -i ansible/inventory/hosts -m shell -a "docker exec iam-bastion_nginx_1 nginx -s reload"
```

#### Authentication File Verification

```bash
# Check htpasswd file
ansible bastion -i ansible/inventory/hosts -m shell -a "cat /etc/nginx/.prometheus_htpasswd"

# Test htpasswd authentication
ansible bastion -i ansible/inventory/hosts -m shell -a "htpasswd -v /etc/nginx/.prometheus_htpasswd prometheus_admin"
```

### Monitoring Stack Diagnostics

#### Prometheus Targets Status

```bash
# Check Prometheus targets
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -s -u prometheus_admin:SecurePrometheus2024 http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'"
```

#### Grafana Data Sources

```bash
# Check Grafana data sources API
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -s -u admin:SecureGrafanaAdmin2024 http://localhost:3000/api/datasources"
```

#### Loki Ingestion Status

```bash
# Check Loki metrics
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -s http://localhost:3100/metrics | grep loki_ingester"

# Query Loki logs
ansible bastion -i ansible/inventory/hosts -m shell -a "curl -s -u prometheus_admin:SecurePrometheus2024 'http://localhost:3101/loki/api/v1/query?query={job=\"varlogs\"}'"
```

### Container Resource Usage

#### System Resource Monitoring

```bash
# Check system resources
ansible all -i ansible/inventory/hosts -m shell -a "free -h && df -h && top -bn1 | head -20"

# Check Docker resource usage
ansible all -i ansible/inventory/hosts -m shell -a "docker stats --no-stream"
```

#### Container Health Checks

```bash
# Check container health status
ansible all -i ansible/inventory/hosts -m shell -a "docker inspect --format='{{.State.Health.Status}}' \$(docker ps -q) 2>/dev/null || echo 'No health checks configured'"
```

### Service Restart Procedures

#### Safe Service Restart Order

```bash
# 1. Restart monitoring services
ansible bastion -i ansible/inventory/hosts -m shell -a "cd /opt/monitoring && docker-compose restart"

# 2. Restart nginx proxy
ansible bastion -i ansible/inventory/hosts -m shell -a "cd /opt/iam-bastion && docker-compose restart nginx"

# 3. Restart backend services (one at a time)
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker restart keycloak" --limit backend1
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker restart keycloak" --limit backend2
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker restart keycloak" --limit backend3
```

#### Emergency Full Restart

```bash
# Stop all services
ansible all -i ansible/inventory/hosts -m shell -a "docker stop \$(docker ps -q)"

# Start in order: Patroni -> Keycloak -> Nginx -> Monitoring
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker start patroni"
sleep 30
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker start keycloak"
ansible bastion -i ansible/inventory/hosts -m shell -a "cd /opt/iam-bastion && docker-compose up -d"
ansible bastion -i ansible/inventory/hosts -m shell -a "cd /opt/monitoring && docker-compose up -d"
```

---

## Common Issues and Solutions

### Issue 1: Port Conflicts

**Symptoms**: `bind() to 0.0.0.0:XXXX failed (98: Address already in use)`

**Solution**:

```bash
# Find what's using the port
ansible <node> -i ansible/inventory/hosts -m shell -a "netstat -tlnp | grep :<PORT>"

# Kill conflicting process or change port in configuration
```

### Issue 2: Container Communication Issues

**Symptoms**: `connection refused` between containers

**Solution**:

```bash
# Check Docker network
ansible <node> -i ansible/inventory/hosts -m shell -a "docker network ls && docker network inspect bridge"

# Verify container connectivity
ansible <node> -i ansible/inventory/hosts -m shell -a "docker exec <container1> ping <container2>"
```

### Issue 3: Authentication Failures

**Symptoms**: 401/403 errors on monitoring endpoints

**Solution**:

```bash
# Recreate htpasswd file
ansible bastion -i ansible/inventory/hosts -m shell -a "htpasswd -bc /etc/nginx/.prometheus_htpasswd prometheus_admin SecurePrometheus2024"

# Restart nginx
ansible bastion -i ansible/inventory/hosts -m shell -a "cd /opt/iam-bastion && docker-compose restart nginx"
```

### Issue 4: Grafana Data Source Errors

**Symptoms**: Cannot connect to Prometheus/Loki

**Solution**:

```bash
# Check container names and network connectivity
ansible bastion -i ansible/inventory/hosts -m shell -a "docker exec grafana nslookup prometheus"

# Update data source URLs in Grafana:
# Prometheus: http://prometheus:9090
# Loki: http://loki:3100
```

### Issue 5: PostgreSQL Connection Issues

**Symptoms**: Keycloak cannot connect to database

**Solution**:

```bash
# Check Patroni cluster status
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni patronictl list"

# Check pg_hba.conf
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni cat /var/lib/postgresql/data/pg_hba.conf | tail -10"

# Restart Patroni if needed
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker restart patroni"
```

---

## Maintenance Commands

### Regular Health Checks

```bash
# Weekly health check script
#!/bin/bash
echo "=== System Health Check $(date) ==="
ansible all -i ansible/inventory/hosts -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
ansible all -i ansible/inventory/hosts -m shell -a "df -h | grep -E '/$|/var'"
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni patronictl list"
```

### Log Rotation and Cleanup

```bash
# Clean old Docker logs
ansible all -i ansible/inventory/hosts -m shell -a "docker system prune -f"

# Check log sizes
ansible all -i ansible/inventory/hosts -m shell -a "du -sh /var/lib/docker/containers/*/*.log | sort -h | tail -10"
```

### Backup Procedures

```bash
# Backup PostgreSQL
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni pg_dump -U postgres keycloak > /tmp/keycloak_backup_\$(date +%Y%m%d).sql" --limit backend1

# Backup Grafana dashboards
ansible bastion -i ansible/inventory/hosts -m shell -a "docker exec grafana grafana-cli admin export-dashboard > /tmp/grafana_backup_\$(date +%Y%m%d).json" --limit bastion1
```

---

## Performance Tuning

### Resource Optimization

```bash
# Monitor resource usage
ansible all -i ansible/inventory/hosts -m shell -a "top -bn1 | head -20"
ansible all -i ansible/inventory/hosts -m shell -a "free -h"
ansible all -i ansible/inventory/hosts -m shell -a "iostat -x 1 3"

# Adjust container limits if needed
# Edit docker-compose.yml files to add:
# deploy:
#   resources:
#     limits:
#       memory: 512M
#       cpus: '0.5'
```

### Network Optimization

```bash
# Check network latency between nodes
ansible all -i ansible/inventory/hosts -m shell -a "ping -c 3 <other_node_ip>"

# Monitor network usage
ansible all -i ansible/inventory/hosts -m shell -a "iftop -t -s 10"
```

---

## Security Hardening

### SSL/TLS Certificates

```bash
# Check certificate expiration
ansible bastion -i ansible/inventory/hosts -m shell -a "openssl x509 -in /etc/ssl/certs/skeycloak.loseyourip.com.pem -noout -dates"

# Renew certificates (if using Let's Encrypt)
ansible bastion -i ansible/inventory/hosts -m shell -a "certbot renew --dry-run"
```

### Access Control Audit

```bash
# Check open ports
ansible all -i ansible/inventory/hosts -m shell -a "nmap -sT localhost"

# Review nginx access logs
ansible bastion -i ansible/inventory/hosts -m shell -a "tail -100 /var/log/nginx/access.log | grep -E '40[0-9]|50[0-9]'"
```

---

## Contact and Support

For issues not covered in this guide:

1. Check container logs first
2. Verify network connectivity
3. Test authentication credentials
4. Review configuration files
5. Restart services in proper order

Remember: Always test changes in a development environment first!
