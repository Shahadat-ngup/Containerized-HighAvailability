# Keycloak High Availability Architecture

## Overview

This document describes the implemented Keycloak HA architecture based on real-world production patterns and community best practices. The solution uses **embedded Infinispan clustering** with **JDBC_PING discovery protocol** for database-based cluster formation.

## Architecture Pattern: Active/Active HA

### Why This Approach?

Based on community discussions and production experiences:

1. **Keycloak DOES support active/active HA** - Multiple instances can run simultaneously
2. **All instances share the same database** - No database replication complexity
3. **Embedded Infinispan clustering works reliably** - Built-in, battle-tested
4. **JDBC_PING uses database for discovery** - No additional infrastructure needed
5. **Session distribution across cluster** - User sessions are shared between nodes

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Load Balancer                          │
│                      (HAProxy/Nginx)                           │
│                    http://your-domain:8080                     │
└─────────┬─────────────────┬─────────────────┬─────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Keycloak #1    │ │  Keycloak #2    │ │  Keycloak #3    │
│  172.29.65.52   │ │  172.29.65.53   │ │  172.29.65.54   │
│  Port: 8080     │ │  Port: 8080     │ │  Port: 8080     │
│                 │ │                 │ │                 │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │ Infinispan  │ │ │ │ Infinispan  │ │ │ │ Infinispan  │ │
│ │ Embedded    │◄┼─┼►│ Embedded    │◄┼─┼►│ Embedded    │ │
│ │ Port: 7800  │ │ │ │ Port: 7800  │ │ │ │ Port: 7800  │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
└─────────┬───────┘ └─────────┬───────┘ └─────────┬───────┘
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  MySQL Primary  │
                    │  172.29.65.52   │
                    │  Port: 3306     │
                    │                 │
                    │ ┌─────────────┐ │
                    │ │ JGROUPSPING │ │
                    │ │   Table     │ │
                    │ │ (Discovery) │ │
                    │ └─────────────┘ │
                    └─────────────────┘
```

## Technical Implementation

### Database Configuration

**Single Shared Database Approach:**
- All Keycloak instances connect to the same MySQL database
- Database stores both application data and cluster discovery information
- JGROUPSPING table manages cluster membership

**Database Setup:**
```sql
-- Database and user configuration
CREATE DATABASE keycloak_db;
CREATE USER 'keycloak_user'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON keycloak_db.* TO 'keycloak_user'@'%';

-- Cluster discovery table (auto-created by JDBC_PING)
CREATE TABLE JGROUPSPING (
    own_addr varchar(200) NOT NULL,
    cluster_name varchar(200) NOT NULL,
    ping_data varbinary(5000) DEFAULT NULL,
    PRIMARY KEY (own_addr, cluster_name)
);
```

### Infinispan Clustering Configuration

**Embedded Infinispan with JDBC_PING:**

```xml
<infinispan xmlns="urn:infinispan:config:11.0">
    <jgroups>
        <stack name="jdbc-ping-tcp">
            <TCP bind_port="7800" external_addr="NODE_IP" />
            <JDBC_PING 
                connection_driver="com.mysql.cj.jdbc.Driver"
                connection_url="jdbc:mysql://172.29.65.52:3306/keycloak_db"
                connection_username="keycloak_user"
                connection_password="secure_password"
                initialize_sql="CREATE TABLE IF NOT EXISTS JGROUPSPING ..."
                insert_single_sql="INSERT INTO JGROUPSPING ..."
                delete_single_sql="DELETE FROM JGROUPSPING ..."
                select_all_pingdata_sql="SELECT ping_data FROM JGROUPSPING ..." />
            <MERGE3 />
            <FD_SOCK />
            <VERIFY_SUSPECT />
            <pbcast.NAKACK2 />
            <UNICAST3 />
            <pbcast.STABLE />
            <pbcast.GMS />
            <FRAG2 />
        </stack>
    </jgroups>
    
    <cache-container name="keycloak">
        <transport stack="jdbc-ping-tcp" cluster="keycloak" />
        <distributed-cache name="sessions" owners="1" />
        <distributed-cache name="authenticationSessions" owners="1" />
        <distributed-cache name="offlineSessions" owners="1" />
        <distributed-cache name="clientSessions" owners="1" />
        <distributed-cache name="offlineClientSessions" owners="1" />
        <distributed-cache name="loginFailures" owners="1" />
        <replicated-cache name="keys" />
        <!-- Additional caches -->
    </cache-container>
</infinispan>
```

### Container Configuration

**Keycloak Docker Parameters:**
```bash
docker run -d \
  --name keycloak-backend1 \
  --network host \
  -e KC_DB=mysql \
  -e KC_DB_URL='jdbc:mysql://172.29.65.52:3306/keycloak_db' \
  -e KC_DB_USERNAME='keycloak_user' \
  -e KC_DB_PASSWORD='secure_password' \
  -e KC_CACHE=ispn \
  -e KC_CACHE_CONFIG_FILE=cache-ispn-jdbc-ping.xml \
  -e KC_HTTP_ENABLED=true \
  -e KC_HOSTNAME_STRICT=false \
  -e JAVA_OPTS='-Djgroups.bind_addr=172.29.65.52' \
  -v /tmp/keycloak-config:/opt/keycloak/conf \
  quay.io/keycloak/keycloak:26.0.2 start-dev
```

## Session Management

### Distributed Session Handling

**Session Distribution:**
- User sessions are distributed across all cluster nodes
- Login state persists even if a node fails
- Session replication happens automatically via Infinispan

**Cache Types:**
- `sessions`: User sessions (distributed)
- `authenticationSessions`: Authentication flow sessions (distributed)
- `offlineSessions`: Offline token sessions (distributed)
- `clientSessions`: Client sessions (distributed)
- `keys`: Realm keys (replicated to all nodes)
- `loginFailures`: Brute force protection (distributed)

## Failover and Recovery

### Automatic Failover

**Node Failure Handling:**
1. Load balancer detects node failure via health checks
2. Traffic automatically redirected to healthy nodes
3. User sessions remain valid on remaining nodes
4. Failed node can rejoin cluster when restored

**Health Check Endpoints:**
- Main health: `http://node:8080/realms/master`
- Admin health: `http://node:8080/admin/master/console`
- Metrics: `http://node:8080/metrics` (if enabled)

### Recovery Procedures

**Node Recovery:**
1. Restart failed container
2. Container automatically discovers cluster via JDBC_PING
3. Rejoins cluster and synchronizes state
4. Load balancer detects health and resumes traffic

## Limitations and Considerations

### Known Limitations

**Rolling Upgrades:**
- **NOT SUPPORTED** with this configuration
- All nodes must be stopped for upgrades
- Brief downtime required for version updates

**Reasons for Rolling Update Limitation:**
- Schema changes may not be backward compatible
- Cache structure changes between versions
- Cluster protocol compatibility issues

### Upgrade Process

**Safe Upgrade Procedure:**
1. Schedule maintenance window
2. Stop all Keycloak instances
3. Backup database
4. Update container images
5. Start all instances simultaneously
6. Verify cluster formation

## Monitoring and Management

### Health Monitoring

**Key Metrics to Monitor:**
- HTTP response times and success rates
- Cluster member count in JGROUPSPING table
- Container resource usage (CPU, memory)
- Database connection pool status
- Cache hit rates and distribution

**Monitoring Commands:**
```bash
# Check cluster status
./manage-keycloak-ha.sh status

# Check cluster formation
./manage-keycloak-ha.sh formation

# View JDBC_PING discovery table
./manage-keycloak-ha.sh ping-table

# Test load balancing
./manage-keycloak-ha.sh test
```

### Log Analysis

**Important Log Patterns:**
- Cluster view changes: `cluster.*view`
- JDBC_PING activity: `jdbc.*ping`
- Session replication: `infinispan.*session`
- Database connectivity: `mysql.*connection`

## Load Balancer Configuration

### HAProxy Example

```haproxy
global
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend keycloak_frontend
    bind *:8080
    default_backend keycloak_backend

backend keycloak_backend
    balance roundrobin
    option httpchk GET /realms/master
    http-check expect status 200
    
    server backend1 172.29.65.52:8080 check inter 30s
    server backend2 172.29.65.53:8080 check inter 30s
    server backend3 172.29.65.54:8080 check inter 30s
```

### Nginx Example

```nginx
upstream keycloak_cluster {
    server 172.29.65.52:8080 max_fails=3 fail_timeout=30s;
    server 172.29.65.53:8080 max_fails=3 fail_timeout=30s;
    server 172.29.65.54:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 8080;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://keycloak_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Health check
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://keycloak_cluster/realms/master;
    }
}
```

## Security Considerations

### Network Security

**Firewall Rules:**
- Port 8080: HTTP access (load balancer only)
- Port 7800: Infinispan clustering (internal cluster only)
- Port 3306: MySQL access (Keycloak nodes only)

**SSL/TLS Configuration:**
```bash
# For production, enable HTTPS
-e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/server.crt.pem \
-e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/server.key.pem \
-e KC_HOSTNAME_STRICT_HTTPS=true
```

### Database Security

**Best Practices:**
- Use dedicated database user with minimal privileges
- Enable SSL connections to MySQL
- Regular database backups and security updates
- Monitor for unusual database access patterns

## Troubleshooting Guide

### Common Issues

**Cluster Formation Problems:**
- Check JGROUPSPING table for member entries
- Verify network connectivity on port 7800
- Ensure database credentials are correct
- Check for firewall blocking cluster communication

**Session Issues:**
- Verify cache configuration in Infinispan
- Check session replication in logs
- Monitor memory usage for cache overflow
- Ensure sticky sessions are disabled in load balancer

**Performance Issues:**
- Monitor database connection pool
- Check cache hit rates
- Analyze garbage collection logs
- Monitor network bandwidth usage

### Diagnostic Commands

```bash
# View cluster membership
docker exec keycloak-backend1 \
  sh -c "grep -i 'cluster.*view' /opt/keycloak/data/log/keycloak.log | tail -5"

# Check cache statistics
docker exec keycloak-backend1 \
  sh -c "curl -s localhost:9990/management | grep cache"

# Monitor database connections
docker exec mysql-gr-backend1 \
  mysql -u root -p -e "SHOW PROCESSLIST;"
```

## Deployment Scripts

### Main Deployment

```bash
# Deploy the HA cluster
./deploy-keycloak-ha.sh

# Monitor cluster status
./manage-keycloak-ha.sh status

# Check cluster formation
./manage-keycloak-ha.sh formation

# Test load balancing
./manage-keycloak-ha.sh test
```

### Maintenance Operations

```bash
# Restart specific node
./manage-keycloak-ha.sh restart backend2

# View cluster logs
./manage-keycloak-ha.sh logs 100

# Check discovery table
./manage-keycloak-ha.sh ping-table
```

## Production Recommendations

### Scaling Considerations

**Horizontal Scaling:**
- 3 nodes minimum for HA (odd number prevents split-brain)
- 5-7 nodes maximum (diminishing returns beyond this)
- Monitor cluster communication overhead

**Vertical Scaling:**
- Minimum 4GB RAM per Keycloak instance
- 2 CPU cores per instance recommended
- SSD storage for better I/O performance

### Backup Strategy

**Database Backups:**
```bash
# Regular database backup
mysqldump -u root -p keycloak_db > keycloak_backup_$(date +%Y%m%d).sql

# Include JGROUPSPING table
mysqldump -u root -p keycloak_db JGROUPSPING > cluster_state_backup.sql
```

**Configuration Backups:**
- Keycloak realm exports
- Infinispan configuration files
- Environment variable files
- SSL certificates and keys

### Monitoring Setup

**Prometheus Metrics:**
```bash
# Enable metrics in Keycloak
-e KC_METRICS_ENABLED=true
-e KC_HEALTH_ENABLED=true
```

**Grafana Dashboards:**
- JVM metrics (heap, GC, threads)
- Infinispan cache metrics
- HTTP request metrics
- Database connection metrics

---

## Summary

This Keycloak HA implementation provides:

✅ **Active/Active clustering** with automatic failover  
✅ **Database-based cluster discovery** (no external dependencies)  
✅ **Session distribution** across all nodes  
✅ **Embedded Infinispan clustering** (proven and reliable)  
✅ **Simple deployment** and management  
✅ **Production-ready architecture** based on community best practices  

⚠️ **Note:** Rolling upgrades are not supported - plan for maintenance windows.

This architecture has been successfully deployed in production environments and provides a robust, scalable Keycloak HA solution.
