# SSH Key Distribution Script for IAM HA Stack (PowerShell Version)
# This script copies SSH public keys to all backend nodes through bastion hosts
# Designed for Windows PowerShell environments

param(
    [string]$KeyFile = "",
    [string]$Username = "shahadat",
    [string]$Bastion = "",
    [switch]$TestOnly = $false,
    [switch]$Verbose = $false,
    [switch]$Help = $false
)

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Show usage
function Show-Usage {
    @"
SSH Key Distribution Script for IAM HA Stack (PowerShell)

USAGE:
    .\deploy-ssh-keys.ps1 [OPTIONS]

PARAMETERS:
    -KeyFile PATH       Path to SSH public key file (default: auto-detect)
    -Username NAME      Username for backend nodes (default: shahadat)
    -Bastion HOST       Bastion host to use (default: all bastions)
    -TestOnly          Test SSH connectivity only (don't copy keys)
    -Verbose           Verbose output
    -Help              Show this help message

EXAMPLES:
    # Auto-detect SSH key and copy to all backends
    .\deploy-ssh-keys.ps1

    # Use specific SSH key file
    .\deploy-ssh-keys.ps1 -KeyFile "C:\Users\YourName\.ssh\id_rsa.pub"

    # Copy to backends through specific bastion
    .\deploy-ssh-keys.ps1 -Bastion "bastion1"

    # Test connectivity only
    .\deploy-ssh-keys.ps1 -TestOnly

REQUIREMENTS:
    - OpenSSH client installed (available in Windows 10/11 by default)
    - SSH key pair generated
    - Access to bastion hosts

NOTES:
    - Ensure OpenSSH is enabled: Settings > Apps > Optional Features > OpenSSH Client
    - Generate SSH key: ssh-keygen -t ed25519 -C "your_email@example.com"
    - Script requires ansible inventory file in ansible/inventory/hosts
"@
}

# Detect SSH public key
function Find-SSHKey {
    $DefaultKeys = @(
        "$env:USERPROFILE\.ssh\id_rsa.pub",
        "$env:USERPROFILE\.ssh\id_ed25519.pub",
        "$env:USERPROFILE\.ssh\id_ecdsa.pub"
    )
    
    Write-Info "Auto-detecting SSH public key..."
    
    foreach ($Key in $DefaultKeys) {
        if (Test-Path $Key) {
            Write-Info "Found SSH public key: $Key"
            return $Key
        }
    }
    
    Write-Error "No SSH public key found in default locations:"
    foreach ($Key in $DefaultKeys) {
        Write-Host "  - $Key"
    }
    Write-Info "Please generate an SSH key pair or specify one with -KeyFile parameter"
    Write-Info "To generate: ssh-keygen -t ed25519 -C 'your_email@example.com'"
    exit 1
}

# Parse inventory file
function Get-InventoryHosts {
    param([string]$Section)
    
    $InventoryFile = Join-Path $PSScriptRoot "..\ansible\inventory\hosts"
    
    if (-not (Test-Path $InventoryFile)) {
        Write-Error "Inventory file not found: $InventoryFile"
        exit 1
    }
    
    $Content = Get-Content $InventoryFile
    $InSection = $false
    $Hosts = @()
    
    foreach ($Line in $Content) {
        $Line = $Line.Trim()
        
        if ($Line -match "^\[$Section\]") {
            $InSection = $true
            continue
        }
        
        if ($Line -match "^\[" -and $Line -notmatch "^\[$Section\]") {
            $InSection = $false
            continue
        }
        
        if ($InSection -and $Line -and -not $Line.StartsWith("#")) {
            $HostName = ($Line -split '\s+')[0]
            if ($HostName) {
                $Hosts += $HostName
            }
        }
    }
    
    return $Hosts
}

# Get host IP from inventory
function Get-HostIP {
    param([string]$HostName)
    
    $InventoryFile = Join-Path $PSScriptRoot "..\ansible\inventory\hosts"
    $Content = Get-Content $InventoryFile
    
    foreach ($Line in $Content) {
        if ($Line -match "^$HostName\s+.*ansible_host=([^\s]+)") {
            return $Matches[1]
        }
    }
    
    return $null
}

# Test SSH connectivity
function Test-SSHConnection {
    param(
        [string]$TargetHost,
        [string]$Username,
        [string]$ProxyCommand = ""
    )
    
    Write-Info "Testing SSH connectivity to $Username@$TargetHost..."
    
    $SSHArgs = @(
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=nul",
        "-o", "BatchMode=yes"
    )
    
    if ($ProxyCommand) {
        $SSHArgs += @("-o", "ProxyCommand=$ProxyCommand")
    }
    
    $SSHArgs += @("$Username@$TargetHost", "echo 'SSH connection successful'")
    
    try {
        $Result = & ssh @SSHArgs 2>$null
        return $Result -eq "SSH connection successful"
    }
    catch {
        return $false
    }
}

# Copy SSH key to target
function Copy-SSHKey {
    param(
        [string]$KeyFile,
        [string]$TargetHost,
        [string]$Username,
        [string]$ProxyCommand = ""
    )
    
    Write-Info "Copying SSH key to $Username@$TargetHost..."
    
    $KeyContent = Get-Content $KeyFile -Raw
    $KeyContent = $KeyContent.Trim()
    
    $SSHCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$KeyContent' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
    
    $SSHArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=nul"
    )
    
    if ($ProxyCommand) {
        $SSHArgs += @("-o", "ProxyCommand=$ProxyCommand")
    }
    
    $SSHArgs += @("$Username@$TargetHost", $SSHCommand)
    
    try {
        & ssh @SSHArgs
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Main script
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    if ($Verbose) {
        $VerbosePreference = "Continue"
    }
    
    Write-Info "SSH Key Distribution Script for IAM HA Stack (PowerShell)"
    Write-Info "=========================================================="
    
    # Validate or detect SSH key
    if (-not $KeyFile) {
        $KeyFile = Find-SSHKey
    }
    elseif (-not (Test-Path $KeyFile)) {
        Write-Error "SSH key file not found: $KeyFile"
        exit 1
    }
    
    Write-Success "Using SSH key: $KeyFile"
    
    # Get bastion hosts
    $Bastions = Get-InventoryHosts "bastion"
    if ($Bastions.Count -eq 0) {
        Write-Error "No bastion hosts found in inventory"
        exit 1
    }
    
    # Filter bastions if specified
    if ($Bastion) {
        $Bastions = $Bastions | Where-Object { $_ -eq $Bastion }
        if ($Bastions.Count -eq 0) {
            Write-Error "Bastion host not found: $Bastion"
            exit 1
        }
    }
    
    # Get backend hosts
    $Backends = Get-InventoryHosts "postgres_cluster"
    if ($Backends.Count -eq 0) {
        Write-Error "No backend hosts found in inventory"
        exit 1
    }
    
    Write-Info "Found $($Bastions.Count) bastion(s) and $($Backends.Count) backend(s)"
    
    $SuccessCount = 0
    $TotalCount = 0
    
    foreach ($Backend in $Backends) {
        $BackendIP = Get-HostIP $Backend
        
        if (-not $BackendIP) {
            Write-Warning "Could not find IP address for backend: $Backend"
            continue
        }
        
        Write-Info "Processing backend: $Backend ($BackendIP)"
        
        $BackendSuccess = $false
        
        foreach ($BastionHost in $Bastions) {
            $BastionIP = Get-HostIP $BastionHost
            
            if (-not $BastionIP) {
                Write-Warning "Could not find IP address for bastion: $BastionHost"
                continue
            }
            
            Write-Info "  Trying through bastion: $BastionHost ($BastionIP)"
            
            $ProxyCmd = "ssh -A -W ${BackendIP}:22 -q $Username@$BastionIP -o StrictHostKeyChecking=no -o UserKnownHostsFile=nul"
            $TotalCount++
            
            if (Test-SSHConnection $BackendIP $Username $ProxyCmd) {
                Write-Success "    SSH connectivity test passed"
                
                if (-not $TestOnly) {
                    if (Copy-SSHKey $KeyFile $BackendIP $Username $ProxyCmd) {
                        Write-Success "    SSH key copied successfully"
                        $SuccessCount++
                        $BackendSuccess = $true
                        break
                    }
                    else {
                        Write-Error "    Failed to copy SSH key"
                    }
                }
                else {
                    Write-Info "    Test mode: skipping key copy"
                    $SuccessCount++
                    $BackendSuccess = $true
                    break
                }
            }
            else {
                Write-Warning "    SSH connectivity test failed"
            }
        }
        
        if (-not $BackendSuccess) {
            Write-Error "  Failed to access backend $Backend through any bastion"
        }
    }
    
    # Summary
    Write-Host ""
    Write-Info "Summary"
    Write-Info "======="
    
    if ($TestOnly) {
        Write-Info "SSH connectivity test completed"
        Write-Info "Successful connections: $SuccessCount/$TotalCount"
    }
    else {
        Write-Info "SSH key distribution completed"
        Write-Info "Successful deployments: $SuccessCount/$TotalCount"
    }
    
    if ($SuccessCount -eq $TotalCount -and $TotalCount -gt 0) {
        Write-Success "All operations completed successfully!"
        
        if (-not $TestOnly) {
            Write-Host ""
            Write-Info "You can now SSH directly to backend nodes:"
            foreach ($Backend in $Backends) {
                $BackendIP = Get-HostIP $Backend
                if ($BackendIP) {
                    Write-Host "  ssh -A -J $Username@$($Bastions[0]) $Username@$BackendIP"
                }
            }
        }
    }
    else {
        Write-Warning "Some operations failed. Check the output above for details."
        exit 1
    }
}

# Run main function
Main
