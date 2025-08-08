# SSH Key Distribution Scripts

This directory contains scripts to help you copy SSH public keys to all backend nodes through the bastion hosts. This is useful when you have multiple machines (Linux, macOS, Windows) and need to access the backend infrastructure.

## Available Scripts

### 1. deploy-ssh-keys.sh (Linux/macOS/Git Bash)
Bash script for Unix-like systems and Windows Git Bash.

### 2. deploy-ssh-keys.ps1 (Windows PowerShell)
PowerShell script for Windows environments.

## Quick Start

### Linux/macOS/Git Bash:
```bash
# Make script executable (if not already)
chmod +x scripts/deploy-ssh-keys.sh

# Auto-detect SSH key and deploy to all backends
./scripts/deploy-ssh-keys.sh

# Test connectivity only
./scripts/deploy-ssh-keys.sh --test

# Use specific SSH key
./scripts/deploy-ssh-keys.sh --key-file ~/.ssh/id_ed25519.pub

# Verbose output
./scripts/deploy-ssh-keys.sh --verbose
```

### Windows PowerShell:
```powershell
# Auto-detect SSH key and deploy to all backends
.\scripts\deploy-ssh-keys.ps1

# Test connectivity only
.\scripts\deploy-ssh-keys.ps1 -TestOnly

# Use specific SSH key
.\scripts\deploy-ssh-keys.ps1 -KeyFile "C:\Users\YourName\.ssh\id_ed25519.pub"

# Verbose output
.\scripts\deploy-ssh-keys.ps1 -Verbose
```

## Prerequisites

### All Platforms:
- SSH client installed and accessible via command line
- SSH key pair generated (if not, create one with: `ssh-keygen -t ed25519`)
- Access to at least one bastion host with your current SSH key
- Ansible inventory file properly configured

### Windows Specific:
- OpenSSH Client feature enabled (Settings > Apps > Optional Features > OpenSSH Client)
- PowerShell 5.1+ or PowerShell Core 7+

## How It Works

1. **Auto-detection**: Script automatically finds your SSH public key in common locations
2. **Inventory Parsing**: Reads the Ansible inventory to discover bastion and backend hosts
3. **Connection Testing**: Tests SSH connectivity through each bastion
4. **Key Distribution**: Copies your public key to `~/.ssh/authorized_keys` on each backend
5. **Deduplication**: Ensures no duplicate keys in authorized_keys files

## Connection Flow

```
Your Machine → Bastion Host → Backend Node
              (SSH Jump)    (ProxyCommand)
```

The script uses SSH ProxyCommand to tunnel through bastion hosts:
```bash
ssh -A -J username@bastion_ip username@backend_ip
```

## Common Use Cases

### First-time Setup
When setting up access from a new machine:
```bash
# Test connectivity first
./scripts/deploy-ssh-keys.sh --test

# Deploy keys if test passes
./scripts/deploy-ssh-keys.sh
```

### Multiple Machines
Each machine can run the script to add its SSH key:
```bash
# From Ubuntu machine
./scripts/deploy-ssh-keys.sh --key-file ~/.ssh/id_rsa.pub

# From Windows machine (PowerShell)
.\scripts\deploy-ssh-keys.ps1 -KeyFile "$env:USERPROFILE\.ssh\id_rsa.pub"
```

### Troubleshooting
```bash
# Test specific bastion
./scripts/deploy-ssh-keys.sh --bastion bastion1 --test

# Verbose mode for debugging
./scripts/deploy-ssh-keys.sh --verbose

# Test with specific user
./scripts/deploy-ssh-keys.sh --user myusername --test
```

## Script Options

### Bash Script (deploy-ssh-keys.sh)
```
-k, --key-file PATH     Path to SSH public key file
-u, --user USERNAME     Username for backend nodes (default: shahadat)
-b, --bastion HOST      Specific bastion host to use
-t, --test             Test connectivity only
-v, --verbose          Verbose output
-h, --help             Show help message
```

### PowerShell Script (deploy-ssh-keys.ps1)
```
-KeyFile PATH          Path to SSH public key file
-Username NAME         Username for backend nodes (default: shahadat)
-Bastion HOST          Specific bastion host to use
-TestOnly              Test connectivity only
-Verbose               Verbose output
-Help                  Show help message
```

## Security Notes

- Scripts use SSH agent forwarding (`-A`) for seamless authentication
- Host key checking is disabled for automated operation
- Keys are appended to authorized_keys and deduplicated
- No private keys are transmitted; only public keys are copied

## Troubleshooting

### Common Issues:

1. **SSH Key Not Found**
   - Ensure SSH key pair exists: `ls -la ~/.ssh/`
   - Generate if missing: `ssh-keygen -t ed25519`

2. **Connection Timeout**
   - Check bastion host accessibility
   - Verify network connectivity
   - Try specific bastion: `--bastion bastion1`

3. **Permission Denied**
   - Ensure you have access to bastion hosts
   - Check if your key is added to bastion's authorized_keys

4. **Windows SSH Issues**
   - Enable OpenSSH Client in Windows Features
   - Use PowerShell (not Command Prompt)
   - Check PATH includes SSH: `where ssh`

### Getting Help:
```bash
# Show detailed usage
./scripts/deploy-ssh-keys.sh --help

# PowerShell help
Get-Help .\scripts\deploy-ssh-keys.ps1 -Detailed
```

## Example Output

```
[INFO] SSH Key Distribution Script for IAM HA Stack
[INFO] ==============================================
[INFO] Auto-detecting SSH public key...
[INFO] Found SSH public key: /home/user/.ssh/id_ed25519.pub
[SUCCESS] Using SSH key: /home/user/.ssh/id_ed25519.pub
[INFO] Found 2 bastion(s) and 3 backend(s)
[INFO] Processing backend: backend1 (172.29.65.52)
[INFO]   Trying through bastion: bastion1 (193.136.194.103)
[SUCCESS]     SSH connectivity test passed
[SUCCESS]     SSH key copied successfully
[INFO] Processing backend: backend2 (172.29.65.53)
...
[SUCCESS] All operations completed successfully!

[INFO] You can now SSH directly to backend nodes:
  ssh -A -J shahadat@bastion1 shahadat@172.29.65.52
  ssh -A -J shahadat@bastion1 shahadat@172.29.65.53
  ssh -A -J shahadat@bastion1 shahadat@172.29.65.54
```
