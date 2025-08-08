# Keycloak HA Stack - Single Backend Setup

## Overview
Working Keycloak deployment with:
- **Backend1**: PostgreSQL + Keycloak 
- **Bastion**: Nginx proxy for external access
- **Domain**: https://skeycloak.loseyourip.com

## Quick Deploy

### 1. Deploy Backend1
```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/backend.yml --limit=backend1 --become
```

### 2. Deploy Bastion  
```bash
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/bastion.yml --limit=bastion1 --become
```

### 3. Access
- **URL**: https://skeycloak.loseyourip.com/admin/
- **Admin**: admin / SecureKeycloakAdmin2024

## Files
- `backend1.env` - Backend environment variables
- `docker/backend/` - Backend full stack (PostgreSQL + Keycloak)
- `docker/bastion/` - Nginx proxy to backend1 only
