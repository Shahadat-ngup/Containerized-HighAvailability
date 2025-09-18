# Containerized High Availability Keycloak Stack - Deployment Guide

This guide provides step-by-step instructions to replicate, deploy, and operate the full high-availability Keycloak stack using this repository.

---

## 1. Prerequisites & Environment

- **Host OS:** Windows 10/11
- **Linux Subsystem:** WSL2 (Ubuntu 22.04 recommended)
- **Docker:** Docker Desktop for Windows (with WSL2 integration enabled)
- **Ansible:** Installed in WSL Ubuntu (`sudo apt install ansible`)
- **Other tools:** `curl`, `docker-compose`, `keepalived`, `postgresql-client`
- **SSH Key Requirement:**
  - Your **Windows user's public SSH key** (e.g., `C:\Users\<YourUser>\.ssh\id_ed25519.pub`) **must be present in the `~/.ssh/authorized_keys` file of all remote backend and bastion machines**. This is required for Ansible to connect and automate deployment.
  - Test SSH connectivity from WSL2 to each remote node before proceeding.

---

## 2. Architecture Overview

- **Backend Nodes (backend1, backend2, backend3):**
  - Patroni (HA PostgreSQL)
  - etcd (cluster coordination)
  - Keycloak (identity server, HA, clustered)
- **Bastion Nodes (bastion1, bastion2):**
  - Nginx (reverse proxy for Keycloak)
  - VIP bastions
- **VIP DB:** All Keycloak nodes use a PostgreSQL VIP for HA DB access.
- **Secrets:** SSL certificates and vault for secure access.

---

## 3. Directory Structure

```
Containerized-HighAvailability-master/
├── ansible/
│   ├── inventory/
│   │   ├── hosts
│   │   ├── group_vars/
│   │   └── host_vars/
│   ├── playbooks/
│   │   ├── backend-setup.yml
│   │   ├── backend-post.yml
│   │   ├── patch_pg_hba.yml
│   │   └── bastion.yml
│   └── templates/
├── docker/
│   ├── backend/
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── .env
│   └── bastion/
│       ├── docker-compose.yml
│       └── nginx.conf
├── secrets/
│   ├── .lego/certificates/
│   │   ├── keycloak.ipb.pt.pem
│   │   ├── keycloak.ipb.pt.key
│   │   ├── grafana1.ccom.ipb.pt.pem
│   │   ├── grafana1.ccom.ipb.pt.key
│   │   ├── grafana2.ccom.ipb.pt.pem
│   │   └── grafana2.ccom.ipb.pt.key
│   ├── vault.yaml
│   └── request_cert.sh
├── patroni/
│   ├── docker/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── patroni.env
│   └── docker-compose.yml
├── backend1.env
├── ansible.cfg
└── README.md
```

---

## 4. Step-by-Step Deployment

### 4.1. Prepare Remote Machines

- **Backend nodes:** 3 Linux VMs (private subnet recommended)
- **Bastion nodes:** 2 Linux VMs (public subnet recommended)
- **Ensure your Windows SSH public key is in `~/.ssh/authorized_keys` on all remote nodes.**
- **Test SSH:**
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

### 4.3. Configure Inventory and Variables

- Edit `ansible/inventory/hosts` to match your node IPs and hostnames.
- Edit or create `ansible/inventory/host_vars/<hostname>.yml` for each node with correct variables (see examples in repo).

### 4.4. Prepare Secrets

- Place SSL certificates in `secrets/.lego/certificates/`.
- There is also a guideline to genere certs using Lego Dynu.

### 4.5. Build and Deploy Backend Cluster

#### a. Initial Setup

```bash
source docker/backend/.env
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-setup.yml -u <remote_user> --become
```

#### b. Patch Patroni for DB Access

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/patch_pg_hba.yml -u <remote_user> --become
```

#### c. Post-Deployment (Keycloak, Health, DB Creation)

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-post.yml -u <remote_user> --become
```

### 4.6. Deploy Bastions (Nginx Proxy)

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/bastion.yml -u <remote_user> --become
```

### 4.7. Access Keycloak

- URL: https://keycloak.ipb.pt/admin/
- Admin User: admin
- Admin Password: (see your backend `.env` or deployment output)

Note: The bastion nginx sets the correct X-Forwarded-\* headers and forces HTTPS for Keycloak. The Keycloak container is configured with:

- KC_HOSTNAME=keycloak.ipb.pt
- KC_HOSTNAME_URL=https://keycloak.ipb.pt
- KC_HOSTNAME_ADMIN_URL=https://keycloak.ipb.pt

### 4.8. Deploy Monitoring Stack (Prometheus, Loki, Promtail, Grafana)

1. Create `monitoring.env` (NOT committed this file):

```
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=seeYourMonitoring.env
```

2. Deploy monitoring services on bastions (Prometheus, Loki, Promtail, Grafana):

```
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/monitoring-bastion.yml --become
```

This copies `monitoring.env` to `/opt/monitoring/.env` on each bastion and starts the stack with `docker compose --env-file .env`.

3. Configure Grafana to use Loki as a data source:

```
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-loki.yml --become
```

4. Access Grafana over HTTPS via bastions:

- Bastion1: https://grafana1.ccom.ipb.pt
- Bastion2: https://grafana2.ccom.ipb.pt

Grafana listens on 127.0.0.1:3000; nginx on each bastion proxies 443 vhosts to local Grafana with the correct certificates.

Optional:

- Reset Grafana admin (no data wipe):
  - `ansible-playbook -i ansible/inventory/hosts ansible/playbooks/grafana-admin-reset.yml --limit bastion2 --become`
- Hard reset Grafana on bastion2 (delete data volume):
  - `ansible-playbook -i ansible/inventory/hosts ansible/playbooks/grafana-wipe-bastion2.yml --become`

---

## 5. Troubleshooting & Tips

- Use `docker ps -a` and `docker logs <container>` to check container status on any node.
- If Keycloak containers are stuck in "Created" state, rerun the post-deployment playbook.
- Health check endpoint for Keycloak is `/q/health`.
- All playbooks are idempotent and can be safely re-run.
- For production, use dedicated Linux VMs or cloud instances.

---

## 6. Security & Best Practices

- **SSH Keys:** Only allow your public key for Ansible automation. Remove after deployment if not needed.
- **Secrets:** Never commit real secrets or private keys to version control.
- **SSL:** Use valid certificates for production. Self-signed is fine for testing.
- **Firewall:** Restrict access to only required ports (e.g., 443 for Keycloak, 22 for SSH).

---

## 7. Useful Debugging Commands

```bash
# List all containers on a backend node
ansible postgres_cluster -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "docker ps -a"

# Check logs for a specific container
ansible backend1 -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "docker logs patroni-backend1 --tail 50"

# Restart Prometheus after config change
ansible bastion -i ansible/inventory/hosts -u <remote_user> --become -m shell -a "cd /opt/monitoring && docker restart prometheus"
```

---
## Note: Change all the secrets, like passwords, usernames later and different from the env files
## 8. Contact & Support

For questions, issues, or contributions, please open an issue on the GitHub repository or contact the maintainer.
