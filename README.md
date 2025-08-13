# Containerized High Availability Keycloak Stack

# Debugging commands:

# ansible postgres_cluster -i ansible/inventory/hosts -u shahadat --become -m shell -a "docker ps -a"

## Architecture Overview

- **Backend Nodes (backend1, backend2, backend3):**
  - Patroni (HA PostgreSQL)
  - etcd (cluster coordination)
  - Keycloak (identity server, HA, clustered)
- **Bastion Nodes (bastion1, bastion2):**
  - Nginx (reverse proxy for Keycloak)
  - VIP bastions
- **VIP DB:** All Keycloak nodes use a PostgreSQL VIP for HA DB access.
- **Secrets:** SSL certificates and vault for secure access.

## Recommended Environment ( Tested Environment)

- **Host OS:** Windows 10/11
- **Linux Subsystem:** WSL2 (Ubuntu 22.04 recommended)
- **Resources per backend node:**
  - CPU: 2+ cores
  - RAM: 8GB+
  - Disk: 30GB+ free
- **Docker:** Docker Desktop for Windows (WSL2 integration enabled)
- **Ansible:** Installed in WSL Ubuntu (`sudo apt install ansible`)
- **Other tools:** `curl`, `docker-compose`, `keepalived`, `postgresql-client`

## Directory Structure

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
│   │   ├── fullchain.pem
│   │   └── _.skeycloak.loseyourip.com.key
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

## How to Replicate

### 1. Prepare Machines

- **Backend nodes:** 3 Linux VMs in private subnets
- **Bastion node:** 2 Linux VM in public subnets

### 2. Clone the Repository

```bash
git clone https://github.com/Shahadat-ngup/Containerized-HighAvailability.git
cd Containerized-HighAvailability-master
```

### 3. Configure Inventory

- Edit `ansible/inventory/hosts` to match your node IPs and hostnames.
- Set up `group_vars` and `host_vars` for each backend node.

### 4. Prepare Secrets

- Place SSL certificates in `secrets/.lego/certificates/`.
- Ensure `vault.yaml` and other secrets are present.

### 5. Build and Deploy Backend Cluster

#### a. Initial Setup

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-setup.yml -u <your_user> --become
```

#### b. Patch Patroni for DB Access

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/patch_pg_hba.yml -u <your_user> --become
```

#### c. Post-Deployment (Keycloak, Health, DB Creation)

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend-post.yml -u <your_user> --become
```

### 6. Deploy Bastions (Nginx Proxy)

```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/bastion.yml -u <your_user> --become
```

### 7. Access Keycloak

- **URL:** https://skeycloak.loseyourip.com/admin/
- **Admin User:** admin
- **Admin Password:** SecureKeycloakAdmin2024

## Troubleshooting

- Use `docker ps -a` and `docker logs <container>` to check container status.
- If Keycloak containers are stuck in "Created" state, rerun the post-deployment playbook.
- Health check endpoint for Keycloak is `/q/health` (not `/health/ready`).

## Notes

- All playbooks are designed to be idempotent and can be re-run safely.
- The project is tested on WSL2 Ubuntu 22.04 with Docker Desktop for Windows.
- For production, use dedicated Linux VMs or cloud instances.
