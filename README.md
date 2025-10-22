````markdown
# Containerized High Availability Keycloak Stack - Complete Deployment Guide

This guide provides comprehensive step-by-step instructions to replicate, deploy, and operate the full high-availability Keycloak stack with monitoring using this repository.

---

## 1. Prerequisites & Environment

### Required Software

- **Host OS:** Windows 10/11
- **Linux Subsystem:** WSL2 (Ubuntu 22.04 recommended)
- **Docker:** Docker Desktop for Windows (with WSL2 integration enabled)
- **Ansible:** Installed in WSL Ubuntu (`sudo apt install ansible`)
- **Other tools:** `curl`, `docker-compose`, `keepalived`, `postgresql-client`, `htpasswd`

### SSH Key Requirement

- Your **Windows user's public SSH key** (e.g., `C:\Users\<YourUser>\.ssh\id_ed25519.pub`) **must be present in the `~/.ssh/authorized_keys` file of all remote backend and bastion machines**. This is required for Ansible to connect and automate deployment.
- Test SSH connectivity from WSL2 to each remote node before proceeding:
  ```bash
  ssh <remote_user>@<backend1_ip>
  ssh <remote_user>@<bastion1_ip>
  ```

---

## 2. Architecture Overview

### Infrastructure Components

#### Backend Cluster (Private Subnet)

- **Backend Nodes (backend1, backend2, backend3):**
  - **Patroni** (HA PostgreSQL with automatic failover)
  - **etcd** (Distributed key-value store for cluster coordination)
  - **Keycloak** (Identity and Access Management server, clustered with JDBC_PING)
  - **PostgreSQL VIP:** 172.29.65.100 (managed by Keepalived, follows Patroni leader)
  - **Monitoring Exporters:** postgres-exporter, cAdvisor, node-exporter, Promtail

#### Bastion Cluster (Public Subnet)

- **Bastion Nodes (bastion1, bastion2):**
  - **Nginx** (Reverse proxy with SSL termination for Keycloak and Grafana)
  - **Public VIP:** 193.136.194.100 (Keepalived managed for HA)
  - **Monitoring Stack:** Prometheus, Grafana, Loki, Promtail
  - **Exporters:** nginx-exporter, keepalived-exporter, node-exporter, cAdvisor

### High Availability Features

- **Database HA:** Patroni manages PostgreSQL cluster with automatic leader election and VIP migration
- **Proxy HA:** Keepalived manages public VIP on bastion nodes for seamless failover
- **Keycloak HA:** JDBC_PING discovery for session replication across 3 nodes
- **Monitoring HA:** Dual Grafana instances (grafana1, grafana2) with independent access

---

## 3. Directory Structure

```
Containerized-HighAvailability-master/
├── ansible/
│   ├── inventory/
│   │   ├── hosts                          # Main inventory with all nodes
│   │   ├── group_vars/                    # Group-level variables
│   │   └── host_vars/                     # Host-specific variables
│   ├── playbooks/
│   │   ├── backend-setup.yml              # Initial backend cluster setup (etcd, Patroni, Keycloak, DB VIP)
│   │   ├── backend-keepalived-patroni.yml # Configure Patroni-aware DB VIP failover
│   │   ├── backend-post.yml               # Post-deployment Keycloak configuration
│   │   ├── patch_pg_hba.yml               # PostgreSQL access control configuration
│   │   ├── bastion.yml                    # Bastion proxy and public VIP setup
│   │   ├── monitoring-bastion.yml         # Deploy Prometheus, Grafana, Loki on bastions
│   │   ├── monitoring-backend.yml         # Deploy exporters and Promtail on backends
│   │   ├── secure-monitoring.yml          # Add authentication to monitoring endpoints
│   │   └── deploy-loki.yml                # Loki stack deployment (deprecated, now in monitoring-bastion)
│   └── templates/
│       ├── keepalived.conf.j2             # Keepalived configuration template
│       ├── check_nginx.sh.j2              # Nginx health check script
│       └── check_patroni_leader.sh.j2     # Patroni leader detection script
├── docker/
│   ├── backend/
│   │   ├── docker-compose.yml             # Backend services (etcd, Patroni, Keycloak)
│   │   ├── Dockerfile                     # Custom Docker image for backend services
│   │   ├── entrypoint.sh                  # Container entrypoint script
│   │   ├── patroni.yml                    # Patroni runtime configuration
│   │   ├── patroni.yml.j2                 # Patroni configuration template
│   │   └── .env                           # Backend environment variables (see section 4.3)
│   └── bastion/
│       ├── docker-compose.yml             # Bastion nginx service
│       └── nginx.conf                     # Nginx reverse proxy configuration
├── monitoring/
│   ├── docker-compose.yml                 # Monitoring stack (Prometheus, Grafana, Loki, Promtail)
│   ├── prometheus.yml                     # Prometheus scrape configuration
│   ├── loki-config.yml                    # Loki log aggregation configuration
│   ├── promtail-config.yml                # Promtail config for bastion nodes
│   ├── promtail-backend-config.yml        # Promtail config for backend nodes
│   ├── promtail-config-enhanced.yml       # Enhanced Promtail with Docker SD (not actively used)
│   ├── grafana-datasources.yml            # Grafana data source provisioning
│   └── grafana-dashboard-ha.json          # Pre-configured HA monitoring dashboard (import in Grafana)
├── secrets/
│   ├── .lego/certificates/
│   │   ├── keycloak.ipb.pt.pem
│   │   ├── keycloak.ipb.pt.key
│   │   ├── grafana1.ccom.ipb.pt.pem
│   │   ├── grafana1.ccom.ipb.pt.key
│   │   ├── grafana2.ccom.ipb.pt.pem
│   │   └── grafana2.ccom.ipb.pt.key
│   ├── vault.yaml                         # Ansible vault for secrets (not committed)
│   └── request_cert.sh                    # SSL certificate request script (Lego/Dynu)
├── monitoring.env                          # Monitoring stack environment (NOT committed to git)
├── backend1.env                            # Example backend node environment
├── ansible.cfg                             # Ansible configuration
└── README.md                               # This file
```

---

## 4. Step-by-Step Deployment

### 4.1. Prepare Remote Machines

**Node Requirements:**

- **Backend nodes:** 3 Linux VMs (private subnet recommended: 172.29.65.52-54)
- **Bastion nodes:** 2 Linux VMs (public IPs recommended: 193.136.194.103-104)
- **VIPs:**
  - PostgreSQL VIP: 172.29.65.100 (internal, follows Patroni leader)
  - Public VIP: 193.136.194.100 (external, for Keycloak access)

**Important:** While you can keep the same private subnet IPs (172.29.65.x) for your backend nodes, you **must change** the three public IPs in your deployment:

- `bastion1`: Change `193.136.194.103` to your first public IP
- `bastion2`: Change `193.136.194.104` to your second public IP
- `Public VIP`: Change `193.136.194.100` to your public VIP

**SSH Setup:**

- Ensure your Windows SSH public key is in `~/.ssh/authorized_keys` on all remote nodes
- Test SSH connectivity:
  ```bash
  ssh <remote_user>@<backend1_ip>
  ssh <remote_user>@<bastion1_ip>
  # Repeat for all nodes
  ```

### 4.2. Clone the Repository

```bash
git clone https://github.com/Shahadat-ngup/Containerized-HighAvailability.git
cd Containerized-HighAvailability-master
```

### 4.3. Configure Environment Variables

#### Backend Node Environment File (`docker/backend/.env`)

Create and configure the `.env` file for each backend node. This file contains all environment variables needed for the backend services:

```bash
# Backend Docker environment - exported for Ansible compatibility

# Node identification
export NODE_ID=
export NODE_IP=

# Domain and URL configuration
export DOMAIN_NAME=
export HOSTNAME_URL=

# Database configuration
export POSTGRES_DB=
export POSTGRES_USER=
export POSTGRES_PASSWORD=
export REPLICATOR_PASSWORD=
export DB_URL=

# etcd cluster token
export ETCD_TOKEN=

# Keycloak admin credentials
export KC_BOOTSTRAP_ADMIN_PASSWORD=

# Keepalived VIP configuration
export KEEPALIVED_VIP_CIDR=
export INTERFACE=

# Monitoring authentication (for secure-monitoring.yml playbook)
export PROMETHEUS_AUTH_USER=
export PROMETHEUS_AUTH_PASSWORD=
export MONITORING_HTPASSWD_PATH=
```

**Example values** (replace with your own):

```bash
export NODE_ID=1
export NODE_IP=172.29.65.52
export DOMAIN_NAME=keycloak.yourdomain.com
export HOSTNAME_URL=https://keycloak.yourdomain.com
export POSTGRES_DB=keycloak
export POSTGRES_USER=keycloak
export POSTGRES_PASSWORD=YourSecurePassword123
export REPLICATOR_PASSWORD=YourReplicatorPassword123
export DB_URL=jdbc:postgresql://172.29.65.100:5432/keycloak
export ETCD_TOKEN=etcd-cluster-patroni
export KC_BOOTSTRAP_ADMIN_PASSWORD=YourAdminPassword123
export KEEPALIVED_VIP_CIDR=23
export INTERFACE=enX0
export PROMETHEUS_AUTH_USER=prometheus_admin
export PROMETHEUS_AUTH_PASSWORD=YourPrometheusPassword123
export MONITORING_HTPASSWD_PATH=/etc/nginx/.prometheus_htpasswd
```

**Notes:**

- Create separate `.env` files for each backend node (or use Ansible host_vars)
- `NODE_ID` should be 1, 2, 3 for backend1, backend2, backend3
- `NODE_IP` must match the actual IP address of each backend node
- `DB_URL` should point to the PostgreSQL VIP (172.29.65.100)
- `INTERFACE` is typically `enX0` or `eth0` depending on your network interface name
- **Never commit the `.env` file with real credentials to version control**

#### Monitoring Stack Environment File (`monitoring.env`)

Create `monitoring.env` in the project root (this file is NOT committed to git):

```bash
# Monitoring stack credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=YourGrafanaPassword123
```

### 4.4. Configure Inventory and Variables

Edit `ansible/inventory/hosts` to match your node IPs and hostnames:

```ini
# Example inventory configuration
[bastion]
bastion1 ansible_host=YOUR_PUBLIC_IP_1 ansible_user=shahadat keepalived_state=MASTER keepalived_priority=150
bastion2 ansible_host=YOUR_PUBLIC_IP_2 ansible_user=shahadat keepalived_state=BACKUP keepalived_priority=100

[postgres_cluster]
backend1 ansible_host=172.29.65.52 ansible_user=shahadat postgres_node_id=1 patroni_name=patroni-1 ...
backend2 ansible_host=172.29.65.53 ansible_user=shahadat postgres_node_id=2 patroni_name=patroni-2 ...
backend3 ansible_host=172.29.65.54 ansible_user=shahadat postgres_node_id=3 patroni_name=patroni-3 ...
```

Also update or create `ansible/inventory/host_vars/<hostname>.yml` for each node with host-specific variables.

### 4.5. Prepare SSL Certificates

- Place SSL certificates in `secrets/.lego/certificates/`
- Required certificates:
  - `keycloak.yourdomain.com.pem` and `.key`
  - `grafana1.yourdomain.com.pem` and `.key`
  - `grafana2.yourdomain.com.pem` and `.key`
- Use the provided `secrets/request_cert.sh` script to generate certificates using Lego with Dynu DNS provider
- Or bring your own certificates from Let's Encrypt, commercial CA, or self-signed (for testing)

### 4.6. Build and Deploy Backend Cluster

#### Step 1: Initial Backend Setup

This deploys etcd, Patroni PostgreSQL cluster, Keycloak, and configures the database VIP with Keepalived:

```bash
# Source the backend environment variables
source docker/backend/.env

# Deploy backend infrastructure
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-setup.yml
```

**What this playbook does:**

- Installs Docker, docker-compose, and Keepalived on all backend nodes
- Builds the Patroni Docker image
- Creates and templates configuration files (patroni.yml, .env)
- Deploys etcd cluster for distributed coordination
- Starts Patroni PostgreSQL cluster with automatic failover
- Deploys Keycloak containers (3 nodes with JDBC_PING clustering)
- Configures Keepalived to manage the PostgreSQL VIP (172.29.65.100)
- Deploys the Patroni leader detection script for VIP failover

#### Step 2: Configure Patroni-aware VIP Failover

You need to reconfigure the database VIP to strictly follow the Patroni leader:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-keepalived-patroni.yml
```

**What this playbook does:**

- Ensures Keepalived is configured with Patroni leader tracking
- Deploys/updates the `check_patroni_leader.sh` health check script
- VIP will automatically migrate to whichever node holds the Patroni leader role
- Provides failover for database connections

#### Step 3: Patch PostgreSQL Access Control

Configure `pg_hba.conf` to allow Keycloak and replication connections:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/patch_pg_hba.yml
```

#### Step 4: Post-Deployment Keycloak Setup

Create the Keycloak database and perform health checks:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-post.yml
```

### 4.7. Deploy Bastion Proxy Layer

Deploy Nginx reverse proxy with SSL termination and public VIP failover:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/bastion.yml -u <remote_user> --become
```

**What this playbook does:**

- Installs Keepalived for public VIP management (193.136.194.100)
- Deploys nginx health check script for Keepalived
- Configures Keepalived with nginx tracking (VIP follows healthy nginx)
- Copies SSL certificates for Keycloak and Grafana domains
- Starts Dockerized nginx with SSL termination
- Configures nginx to proxy requests to backend Keycloak cluster
- Sets up virtual hosts for grafana1 and grafana2

### 4.8. Access Keycloak

After successful deployment:

- **URL:** `https://keycloak.yourdomain.com/admin/`
- **Admin User:** `admin`
- **Admin Password:** The value you set in `KC_BOOTSTRAP_ADMIN_PASSWORD` environment variable

**Note:** The bastion nginx sets the correct X-Forwarded-\* headers and forces HTTPS for Keycloak. The Keycloak containers are configured with:

- `KC_HOSTNAME=keycloak.yourdomain.com`
- `KC_HOSTNAME_URL=https://keycloak.yourdomain.com`
- `KC_PROXY=edge` (trusts proxy headers)

### 4.9. Deploy Monitoring Stack

#### Step 1: Deploy Exporters on Backend Nodes

Deploy Prometheus exporters and Promtail on backend nodes:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/monitoring-backend.yml
```

**What this playbook does:**

- Deploys postgres-exporter (port 9187) - PostgreSQL metrics
- Deploys cAdvisor (port 9323) - Container resource metrics
- Deploys node-exporter (automatically via monitoring stack)
- Copies Promtail configuration for backend log collection
- Starts Promtail with Docker socket access for container logs
- Configures Promtail to send logs to Loki on bastion nodes

**Exposed Metrics:**

- Patroni: `:8008/metrics` (automatic, built-in)
- Keycloak: `:9000/metrics` (KC_METRICS_ENABLED=true)
- etcd: `:2379/metrics` (automatic, built-in)
- PostgreSQL: `:9187/metrics` (via postgres-exporter)
- Containers: `:9323/metrics` (via cAdvisor)

#### Step 2: Deploy Monitoring Stack on Bastions

Deploy Prometheus, Grafana, Loki, and Promtail on bastion nodes:

```bash
# Ensure monitoring.env file exists
cat monitoring.env

# Deploy monitoring stack
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/monitoring-bastion.yml
```

**What this playbook does:**

- Copies `monitoring.env` to `/opt/monitoring/.env` on bastions
- Deploys Prometheus (port 9090) with scrape configs for all targets
- Deploys Grafana (port 3000) with provisioned data sources
- Deploys Loki (port 3100) for log aggregation
- Deploys Promtail on bastions for local log collection
- Starts node-exporter, cAdvisor, keepalived-exporter, nginx-exporter on bastions
- Configures all services with `docker compose --env-file .env`

#### Step 3: Secure Monitoring Endpoints (Optional)

Add HTTP Basic Authentication to Prometheus and Loki:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/secure-monitoring.yml
```

**What this playbook does:**

- Creates htpasswd file with credentials from environment variables
- Configures nginx to require authentication for Prometheus and Loki
- Protects `/metrics` endpoints behind authentication
- Maintains public access to Grafana (Grafana has its own auth)

### 4.10. Access Monitoring Services

After successful monitoring deployment:

#### Grafana Dashboards

- **Bastion1:** `https://grafana1.yourdomain.com`
- **Bastion2:** `https://grafana2.yourdomain.com`
- **Credentials:**
  - Username: `admin`
  - Password: Value from `GRAFANA_ADMIN_PASSWORD` in `monitoring.env`

#### Prometheus (if authentication enabled)

- **URL:** `http://<bastion-ip>:9090`
- **Credentials:**
  - Username: Value from `PROMETHEUS_AUTH_USER`
  - Password: Value from `PROMETHEUS_AUTH_PASSWORD`

#### Loki API (if authentication enabled)

- **URL:** `http://<bastion-ip>:3100`
- Uses same credentials as Prometheus

**Note:** Loki does not have a web UI. If you access `http://<bastion-ip>:3100` directly in a browser, you will get a "404 page not found" error. This is **normal behavior**. Loki is an API-only service accessed through:

- **Grafana's Explore tab** for querying logs with LogQL
- **Grafana dashboards** with log panels
- **Direct API calls** (e.g., `/loki/api/v1/query_range`)

**Grafana Features:**

- Pre-configured data sources (Prometheus, Loki)
- Access to all backend and bastion metrics
- Log exploration with LogQL queries via Explore tab
- Container and host resource monitoring
- Keycloak application metrics and logs
- **Pre-built HA Dashboard:** Import `monitoring/grafana-dashboard-ha.json` for comprehensive HA monitoring
  - Go to Grafana → Dashboards → New → Import
  - Upload `grafana-dashboard-ha.json` from the `monitoring/` directory
  - Select Prometheus and Loki data sources when prompted

---

## 5. Troubleshooting & Tips

### Common Issues

#### Keycloak Containers in "Created" State

- **Symptom:** Containers show "Created" but never start
- **Solution:** Rerun the post-deployment playbook:

  ```bash
  ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-post.yml --become
  ```

#### Database Connection Errors

- **Symptom:** Keycloak cannot connect to PostgreSQL
- **Solution:**
  - Check Patroni cluster status: `docker exec patroni-backend1 patronictl list`
  - Verify VIP is on the current leader node
  - Check `pg_hba.conf` allows Keycloak connections
  - Rerun patch playbook if needed: `ansible-playbook patch_pg_hba.yml --become`

#### VIP Not Following Patroni Leader

- **Symptom:** Database VIP stays on wrong node after failover
- **Solution:**
  - Run the keepalived-patroni playbook:
    ```bash
    ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-keepalived-patroni.yml --become
    ```
  - Check Patroni leader: `curl http://127.0.0.1:8008/cluster | jq`
  - Verify Keepalived configuration: `cat /etc/keepalived/keepalived.conf`
  - Check health script: `/etc/keepalived/check_patroni_leader.sh`

#### Promtail Not Collecting Logs

- **Symptom:** No logs appearing in Grafana/Loki
- **Solution:**
  - Check Promtail is running: `docker ps | grep promtail`
  - Verify Docker socket mount: `docker inspect promtail | grep "/var/run/docker.sock"`
  - Check Promtail logs: `docker logs promtail --tail 50`
  - Verify Loki connectivity: `curl http://<bastion-ip>:3100/ready`
  - Check Promtail config: `/opt/monitoring/promtail-config.yml`

#### Monitoring Authentication Not Working

- **Symptom:** 401/403 errors on Prometheus/Loki endpoints
- **Solution:**
  - Verify htpasswd file exists: `cat /etc/nginx/.prometheus_htpasswd`
  - Recreate credentials:
    ```bash
    htpasswd -bc /etc/nginx/.prometheus_htpasswd prometheus_admin YourPassword
    ```
  - Restart nginx: `cd /opt/iam-bastion && docker compose restart nginx`

### Useful Debugging Commands

#### Check Container Status

```bash
# All containers on all nodes
ansible all -i ansible/inventory/hosts -m shell -a "docker ps -a"

# Specific service on backend nodes
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker ps | grep -E '(patroni|keycloak|etcd)'"

# Monitoring stack on bastions
ansible bastion -i ansible/inventory/hosts -m shell -a "docker ps | grep -E '(prometheus|grafana|loki|promtail)'"
```

#### View Container Logs

```bash
# Backend services
ansible backend1 -i ansible/inventory/hosts -m shell -a "docker logs patroni-backend1 --tail 50"
ansible backend1 -i ansible/inventory/hosts -m shell -a "docker logs keycloak-backend1 --tail 50"
ansible backend1 -i ansible/inventory/hosts -m shell -a "docker logs etcd-backend1 --tail 50"

# Monitoring services
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker logs prometheus --tail 50"
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker logs grafana --tail 50"
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker logs loki --tail 50"
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker logs promtail --tail 50"
```

#### Check VIP Status

```bash
# Check which node has the database VIP
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "ip addr show enX0 | grep 172.29.65.100"

# Check which bastion has the public VIP
ansible bastion -i ansible/inventory/hosts -m shell -a "ip addr show enX0 | grep 193.136.194.100"

# Check Keepalived status
ansible all -i ansible/inventory/hosts -m shell -a "systemctl status keepalived"
```

#### Check Patroni Cluster

```bash
# View Patroni cluster status
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker exec patroni-backend1 patronictl list"

# Check Patroni health endpoint
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "curl -s http://localhost:8008/health | jq"

# View Patroni configuration
ansible backend1 -i ansible/inventory/hosts -m shell -a "docker exec patroni-backend1 patronictl show-config"
```

#### Check Keycloak Clustering

```bash
# Check Keycloak metrics (includes cache metrics for clustering)
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "curl -s http://localhost:9000/metrics | grep -E '(cache|cluster)'"

# Check Keycloak health
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "curl -s http://localhost:8080/health/ready"

# View Keycloak logs for JDBC_PING messages
ansible postgres_cluster -i ansible/inventory/hosts -m shell -a "docker logs keycloak-backend1 2>&1 | grep -i 'JDBC_PING'"
```

#### Test Prometheus Scraping

```bash
# Check Prometheus targets status
curl -s http://<bastion-ip>:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Query specific metrics
curl -s http://<bastion-ip>:9090/api/v1/query?query=up | jq
curl -s http://<bastion-ip>:9090/api/v1/query?query=patroni_patroni_info | jq
```

#### Test Loki Log Ingestion

```bash
# Check Loki ready status
curl -s http://<bastion-ip>:3100/ready

# Query logs from Loki
curl -s http://<bastion-ip>:3100/loki/api/v1/query?query='{job="docker"}' | jq

# Check Loki metrics
curl -s http://<bastion-ip>:3100/metrics | grep loki_ingester
```

### Performance Tips

- **Database Performance:** Monitor Patroni metrics and adjust PostgreSQL configuration in `patroni.yml.j2` template
- **Keycloak Performance:** Increase JVM heap size in docker-compose if needed (-Xmx, -Xms options)
- **Log Retention:** Configure Loki retention policies in `loki-config.yml` to manage disk usage
- **Prometheus Retention:** Adjust `--storage.tsdb.retention.time` in Prometheus docker-compose.yml

### Health Check Endpoints

- **Keycloak:** `http://<node-ip>:8080/health/ready` and `:9000/q/health`
- **Patroni:** `http://<node-ip>:8008/health`
- **etcd:** `http://<node-ip>:2379/health`
- **Prometheus:** `http://<bastion-ip>:9090/-/healthy`
- **Grafana:** `http://<bastion-ip>:3000/api/health`
- **Loki:** `http://<bastion-ip>:3100/ready`

### Best Practices

- Always use `--become` flag with Ansible playbooks that require sudo
- Test playbooks with `--limit` flag on one node before running on all
- Use `--check` mode to dry-run playbooks: `ansible-playbook ... --check`
- All playbooks are idempotent and can be safely re-run
- Keep backups of your `.env` files and SSL certificates
- Regularly update Docker images: `docker compose pull` then `docker compose up -d`

---

## 6. Security & Best Practices

### SSH and Access Control

- **SSH Keys:** Only allow your public key for Ansible automation. Remove after deployment if not needed for ongoing management.
- **Firewall Rules:** Restrict access to only required ports:
  - Backend nodes: Allow only bastion IPs to access PostgreSQL (5432), Keycloak (8080), and metrics ports
  - Bastion nodes: Allow public HTTPS (443), restrict Prometheus/Grafana to authorized IPs
  - Inter-node: Allow backend-to-backend communication for Patroni, etcd, and Keycloak clustering

### Secrets Management

- **Never commit secrets:** The `.env` and `monitoring.env` files should never be committed to version control
- **Use Ansible Vault:** Encrypt sensitive variables in `secrets/vault.yaml`
- **Rotate Credentials:** Regularly rotate database passwords, Keycloak admin password, and monitoring credentials
- **Strong Passwords:** Use complex, unique passwords for all services (minimum 16 characters recommended)

### SSL/TLS Certificates

- **Production:** Use valid certificates from Let's Encrypt or a commercial CA
- **Testing:** Self-signed certificates are acceptable for development/testing
- **Certificate Renewal:** Set up automatic renewal for Let's Encrypt certificates using `certbot` or Lego
- **Private Keys:** Protect private keys with `chmod 600` and restrict access

### Monitoring Security

- **Enable Authentication:** Always run `secure-monitoring.yml` playbook for production
- **Network Segmentation:** Keep monitoring endpoints on internal network, expose only Grafana publicly
- **Grafana Security:**
  - Enable HTTPS for Grafana access
  - Use strong admin password
  - Configure user authentication (LDAP, OAuth, etc. for production)
  - Enable audit logging

### Database Security

- **pg_hba.conf:** Restrict PostgreSQL access to specific IPs/subnets only
- **Passwords:** Use strong passwords for `postgres`, `keycloak`, and `replicator` users
- **Encryption:** Enable SSL/TLS for PostgreSQL connections in production
- **Backups:** Implement regular automated backups with encryption

### Container Security

- **Base Images:** Use official images from trusted registries
- **Updates:** Regularly update base images and rebuild custom images
- **Scanning:** Scan images for vulnerabilities using tools like Trivy or Clair
- **Non-Root:** Run containers as non-root users where possible
- **Resource Limits:** Set CPU and memory limits in docker-compose files

### Network Security

- **Private Subnets:** Keep backend nodes in private subnet, only bastions public
- **VPN/Jump Host:** Access backend nodes only through bastion or VPN
- **Intrusion Detection:** Consider deploying IDS/IPS for production
- **DDoS Protection:** Use CloudFlare or similar for public-facing services

---

## 7. Useful Commands Reference

### Ansible Playbook Execution

```bash
# Run playbook with verbose output
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/<playbook-name>.yml -v

# Run with extra verbosity (useful for debugging)
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/<playbook-name>.yml -vvv

# Run playbook limiting to specific hosts
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/<playbook-name>.yml --limit backend1

# Check what would change without applying (dry run)
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/<playbook-name>.yml --check

# List all tasks in a playbook
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/<playbook-name>.yml --list-tasks

# Execute command on all backend nodes
ansible postgres_cluster -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "docker ps -a"

# Execute command on specific host
ansible backend1 -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "docker logs patroni-backend --tail 50"
```

### Docker Management

```bash
# View all containers
docker ps -a

# View container logs (follow mode)
docker logs -f <container-name>

# View last 100 lines of logs
docker logs --tail 100 <container-name>

# Execute command in running container
docker exec -it <container-name> bash

# View container resource usage
docker stats

# Restart a service
docker restart <container-name>

# View container networks
docker network ls

# Inspect container details
docker inspect <container-name>
```

### Patroni Cluster Management

```bash
# Check cluster status
docker exec patroni-backend patronictl list

# Show detailed cluster information
docker exec patroni-backend patronictl list -e

# View Patroni configuration
docker exec patroni-backend patronictl show-config

# Manually failover to specific node
docker exec patroni-backend patronictl failover --candidate backend2 --force

# Reinitialize a replica
docker exec patroni-backend patronictl reinit postgres_cluster backend2

# Restart Patroni on a node
docker exec patroni-backend patronictl restart postgres_cluster backend1

# Query Patroni API
curl http://172.29.65.52:8008/cluster
curl http://172.29.65.52:8008/leader
curl http://172.29.65.52:8008/health
```

### Keepalived VIP Management

```bash
# Check keepalived status
systemctl status keepalived

# View keepalived logs
journalctl -u keepalived -f

# Check which node has the VIP
ip addr show | grep 172.29.65.100  # DB VIP
ip addr show | grep 193.136.194.100  # Public VIP

# View keepalived configuration
cat /etc/keepalived/keepalived.conf

# Test Patroni leader check script
bash /usr/local/bin/check_patroni_leader.sh; echo $?  # 0=leader, 1=not leader

# Restart keepalived
systemctl restart keepalived

# Check keepalived metrics (if exporter deployed)
curl http://localhost:9165/metrics
```

### PostgreSQL Database Operations

```bash
# Connect to PostgreSQL via Patroni
docker exec -it patroni-backend psql -U postgres

# Connect to Keycloak database
docker exec -it patroni-backend psql -U keycloak -d keycloak_db

# Check replication status (run on leader)
docker exec patroni-backend psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check replication lag (run on replica)
docker exec patroni-backend psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# List all databases
docker exec patroni-backend psql -U postgres -c "\l"

# Create manual backup
docker exec patroni-backend pg_dump -U keycloak keycloak_db > keycloak_backup_$(date +%Y%m%d).sql
```

### Keycloak Management

```bash
# Check Keycloak logs
docker logs -f keycloak-backend

# Access Keycloak admin console
# https://193.136.194.100/auth/admin/ or https://<DOMAIN_NAME>/auth/admin/

# Check Keycloak health
curl http://172.29.65.52:9000/health

# View Keycloak metrics
curl http://172.29.65.52:9000/metrics

# Check Keycloak clustering (cache members)
docker exec keycloak-backend bash -c "curl -s http://localhost:9000/metrics | grep jgroups_view_members"

# Execute Keycloak CLI
docker exec -it keycloak-backend /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master --user admin
```

### Monitoring Stack

```bash
# Access monitoring UIs
# Prometheus: http://193.136.194.100:9090
# Grafana: https://193.136.194.100/grafana
# Loki: http://193.136.194.100:3100 (API only)

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Query Prometheus metrics
curl 'http://localhost:9090/api/v1/query?query=up'

# Check Promtail status
docker logs promtail-backend

# View Loki logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container_name="keycloak-backend"}' | jq

# Restart monitoring stack on bastion
ansible bastion -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "cd /opt/monitoring && docker-compose restart"
```

### System Health Checks

```bash
# Check all service health endpoints
curl http://172.29.65.52:8008/health  # Patroni
curl http://172.29.65.52:9000/health  # Keycloak
curl http://172.29.65.52:9090/-/healthy  # Prometheus
curl http://172.29.65.52:3000/api/health  # Grafana

# Check metrics endpoints
curl http://localhost:9187/metrics  # postgres-exporter
curl http://localhost:9100/metrics  # node-exporter
curl http://localhost:9323/metrics  # cAdvisor
curl http://localhost:9165/metrics  # keepalived-exporter
curl http://localhost:9113/metrics  # nginx-exporter

# System resource usage
df -h  # Disk usage
free -h  # Memory usage
top  # CPU usage
netstat -tuln  # Listening ports
```

### Backup and Recovery

```bash
# Backup etcd data
docker exec etcd-backend etcdctl snapshot save /tmp/etcd-snapshot.db
docker cp etcd-backend:/tmp/etcd-snapshot.db ./etcd-backup-$(date +%Y%m%d).db

# Backup Keycloak database
docker exec patroni-backend pg_dump -U keycloak keycloak_db | \
  gzip > keycloak_db_backup_$(date +%Y%m%d).sql.gz

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export > grafana_backup_$(date +%Y%m%d).json

# Restore PostgreSQL database
gunzip -c keycloak_db_backup_20250101.sql.gz | \
  docker exec -i patroni-backend psql -U keycloak keycloak_db
```

### Log Collection for Troubleshooting

```bash
# Collect logs from all backend nodes
for host in backend1 backend2 backend3; do
  ssh $host "docker logs patroni-backend" > ${host}_patroni.log 2>&1
  ssh $host "docker logs keycloak-backend" > ${host}_keycloak.log 2>&1
  ssh $host "journalctl -u keepalived" > ${host}_keepalived.log
done

# Archive logs
tar -czf logs_$(date +%Y%m%d_%H%M%S).tar.gz *.log
```

---

## Note: Change all the secrets, like passwords, usernames later and different from the env files

## 8. Contact & Support

For questions, issues, or contributions related to this High Availability Keycloak setup:

- **GitHub Repository:** Open an issue for bug reports, feature requests, or technical questions
- **Documentation:** Refer to `DEPLOYMENT-GUIDE.md` for additional troubleshooting and maintenance procedures
- **Community Support:** Check the official documentation for Patroni, Keycloak, and Keepalived

### Additional Resources

- **Patroni Documentation:** https://patroni.readthedocs.io/
- **Keycloak Documentation:** https://www.keycloak.org/documentation
- **Keepalived Documentation:** https://www.keepalived.org/doc/
- **Prometheus/Grafana Guides:** https://prometheus.io/docs/ and https://grafana.com/docs/

### Contributing

Contributions are welcome! Please ensure:

- Test all changes in a non-production environment
- Update relevant documentation (README.md, DEPLOYMENT-GUIDE.md)
- Follow existing code style and playbook structure
- Include clear commit messages explaining changes

---

**Project maintained by:** [Your Name/Organization]  
**License:** [Your License]  
**Last Updated:** January 2025
````
