# PostgreSQL + Patroni + Keycloak HA - Deployment Guide

## Prerequisites

### Infrastructure Requirements
- 3 backend nodes (minimum 4GB RAM, 2 CPU cores each)
- 2 bastion hosts (optional, for external access)
- Network connectivity between nodes
- SSH key access to all nodes

### Software Requirements
- Docker 24.0+
- Docker Compose 2.20+
- SSH client
- Ansible (for automation, optional)

## Deployment Steps

### 1. Environment Configuration

```bash
# Copy environment template
cp postgres-ha.env .env

# Edit configuration
nano .env
```

Key variables to configure:
- `POSTGRES_ROOT_PASSWORD`: PostgreSQL superuser password
- `POSTGRES_PASSWORD`: Keycloak database user password
- `KEYCLOAK_ADMIN_PASSWORD`: Keycloak admin password
- Node IP addresses and network configuration

### 2. Infrastructure Cleanup (if needed)

```bash
# Clean any existing infrastructure
./scripts/cleanup-infrastructure.sh
```

### 3. Deploy the Stack

```bash
# Deploy complete HA stack
./scripts/deploy-postgres-patroni-ha.sh
```

This script will:
1. Deploy 3-node etcd consensus cluster
2. Deploy PostgreSQL + Patroni cluster
3. Initialize Keycloak database
4. Deploy Keycloak HA cluster with JDBC_PING
5. Configure automatic failover

### 4. Verify Deployment

```bash
# Check cluster health
./scripts/health-check-postgres-ha.sh

# Test specific components
./scripts/health-check-postgres-ha.sh etcd
./scripts/health-check-postgres-ha.sh patroni
./scripts/health-check-postgres-ha.sh keycloak
```

### 5. Test Failover

```bash
# Run failover tests
./scripts/test-failover-scenarios.sh
```

## Post-Deployment Configuration

### 1. Load Balancer Setup

Configure HAProxy or external load balancer:
```bash
# Copy HAProxy configuration
cp configs/haproxy/haproxy.cfg /etc/haproxy/
systemctl reload haproxy
```

### 2. SSL/TLS Configuration

For production environments:
1. Obtain SSL certificates
2. Update Keycloak configuration for HTTPS
3. Configure HAProxy for SSL termination

### 3. Monitoring Setup

Deploy monitoring stack:
```bash
# Deploy Prometheus + Grafana
docker-compose -f monitoring/docker-compose-monitoring.yml up -d
```

## Maintenance Operations

### Database Maintenance

```bash
# Check Patroni cluster status
curl http://172.29.65.52:8008/cluster

# Perform manual switchover
curl -X POST http://172.29.65.52:8008/switchover
```

### Backup Operations

```bash
# Create database backup
docker exec patroni-backend1 pg_dump -U postgres keycloak > backup.sql

# Restore from backup
docker exec -i patroni-backend1 psql -U postgres keycloak < backup.sql
```

### Scaling Operations

To add nodes:
1. Update inventory files
2. Run deployment script with new nodes
3. Verify cluster status

## Troubleshooting

### Common Issues

1. **Patroni not starting**: Check etcd connectivity
2. **Keycloak clustering issues**: Verify JDBC_PING table
3. **Database connection failures**: Check PostgreSQL logs

### Log Locations

- PostgreSQL: `/opt/postgres/logs/`
- Patroni: `docker logs patroni-<node>`
- Keycloak: `docker logs keycloak-<node>`
- etcd: `docker logs etcd-<node>`

### Health Check Commands

```bash
# Check all components
./scripts/health-check-postgres-ha.sh

# Individual component checks
curl http://172.29.65.52:8008/health     # Patroni
curl http://172.29.65.52:8080/health     # Keycloak
curl http://172.29.65.52:2379/health     # etcd
```

## Security Considerations

1. Change default passwords
2. Enable SSL/TLS for all components
3. Configure firewall rules
4. Implement network segmentation
5. Regular security updates

## Performance Tuning

### PostgreSQL Optimization
- Adjust `shared_buffers` based on available RAM
- Tune `work_mem` for query performance
- Configure connection pooling

### Keycloak Optimization
- Adjust JVM heap size
- Configure session timeouts
- Optimize cache settings

## Backup Strategy

1. **Database Backups**: Daily pg_dump backups
2. **Configuration Backups**: Version control for configs
3. **Volume Backups**: Snapshot persistent volumes
4. **Testing**: Regular restore testing

## Migration Guide

### From MySQL to PostgreSQL

1. Export MySQL data
2. Convert schema to PostgreSQL
3. Import data to PostgreSQL
4. Update Keycloak configuration
5. Test functionality

For detailed migration steps, see `MIGRATION-GUIDE.md`.
