#!/bin/bash

# SSH Key Distribution Script for IAM HA Stack
# This script copies SSH public keys to all backend nodes through bastion hosts
# Supports both Linux/macOS and Windows (Git Bash/WSL) environments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/ansible/inventory/hosts"

# Default SSH key locations
DEFAULT_SSH_KEYS=(
    "$HOME/.ssh/id_rsa.pub"
    "$HOME/.ssh/id_ed25519.pub"
    "$HOME/.ssh/id_ecdsa.pub"
)

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Copy SSH public keys to all backend nodes through bastion hosts.

OPTIONS:
    -k, --key-file PATH     Path to SSH public key file (default: auto-detect)
    -u, --user USERNAME     Username for backend nodes (default: shahadat)
    -b, --bastion HOST      Bastion host to use (default: all bastions)
    -t, --test             Test SSH connectivity only (don't copy keys)
    -v, --verbose          Verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Auto-detect SSH key and copy to all backends
    $0

    # Use specific SSH key file
    $0 -k ~/.ssh/my_key.pub

    # Copy to backends through specific bastion
    $0 -b bastion1

    # Test connectivity only
    $0 -t

    # Verbose mode with specific key
    $0 -v -k ~/.ssh/id_ed25519.pub

NOTES:
    - For Windows users: Use Git Bash, WSL, or PowerShell with SSH support
    - Script automatically detects common SSH key locations
    - Requires ansible inventory file at: ${INVENTORY_FILE}
EOF
}

# Function to detect SSH public key
detect_ssh_key() {
    local key_file=""
    
    print_info "Auto-detecting SSH public key..."
    
    for key in "${DEFAULT_SSH_KEYS[@]}"; do
        if [[ -f "$key" ]]; then
            key_file="$key"
            print_info "Found SSH public key: $key_file"
            break
        fi
    done
    
    if [[ -z "$key_file" ]]; then
        print_error "No SSH public key found in default locations:"
        for key in "${DEFAULT_SSH_KEYS[@]}"; do
            echo "  - $key"
        done
        print_info "Please generate an SSH key pair or specify one with -k option"
        print_info "To generate: ssh-keygen -t ed25519 -C 'your_email@example.com'"
        exit 1
    fi
    
    echo "$key_file"
}

# Function to parse inventory and get hosts
parse_inventory() {
    local section="$1"
    
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    # Extract hosts from specific section
    awk "
        /^\[$section\]/ { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && /^[^#]/ && NF > 0 {
            # Extract hostname (first field)
            gsub(/[ \t]+.*/, \"\", \$1)
            if (\$1 != \"\") print \$1
        }
    " "$INVENTORY_FILE"
}

# Function to get host details from inventory
get_host_details() {
    local hostname="$1"
    
    # Extract ansible_host and ansible_user for the hostname
    grep "^$hostname " "$INVENTORY_FILE" | head -1 | \
    sed -n 's/.*ansible_host=\([^ ]*\).*/\1/p'
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    local target_host="$1"
    local username="$2"
    local proxy_command="$3"
    
    print_info "Testing SSH connectivity to $username@$target_host..."
    
    if [[ -n "$proxy_command" ]]; then
        ssh -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ProxyCommand="$proxy_command" \
            -o BatchMode=yes \
            "$username@$target_host" \
            "echo 'SSH connection successful'" 2>/dev/null
    else
        ssh -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o BatchMode=yes \
            "$username@$target_host" \
            "echo 'SSH connection successful'" 2>/dev/null
    fi
}

# Function to copy SSH key to target host
copy_ssh_key() {
    local key_file="$1"
    local target_host="$2"
    local username="$3"
    local proxy_command="$4"
    
    print_info "Copying SSH key to $username@$target_host..."
    
    # Read the public key content
    local key_content
    key_content=$(cat "$key_file")
    
    # SSH command to add the key
    local ssh_cmd="mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$key_content' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
    
    if [[ -n "$proxy_command" ]]; then
        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ProxyCommand="$proxy_command" \
            "$username@$target_host" \
            "$ssh_cmd"
    else
        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$username@$target_host" \
            "$ssh_cmd"
    fi
}

# Main function
main() {
    local key_file=""
    local username="shahadat"
    local bastion_filter=""
    local test_only=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--key-file)
                key_file="$2"
                shift 2
                ;;
            -u|--user)
                username="$2"
                shift 2
                ;;
            -b|--bastion)
                bastion_filter="$2"
                shift 2
                ;;
            -t|--test)
                test_only=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Enable verbose mode if requested
    if [[ "$verbose" == true ]]; then
        set -x
    fi
    
    print_info "SSH Key Distribution Script for IAM HA Stack"
    print_info "=============================================="
    
    # Detect or validate SSH key file
    if [[ -z "$key_file" ]]; then
        key_file=$(detect_ssh_key)
    elif [[ ! -f "$key_file" ]]; then
        print_error "SSH key file not found: $key_file"
        exit 1
    fi
    
    print_success "Using SSH key: $key_file"
    
    # Show key fingerprint
    if command -v ssh-keygen >/dev/null 2>&1; then
        local fingerprint
        fingerprint=$(ssh-keygen -lf "$key_file" 2>/dev/null || echo "Unable to generate fingerprint")
        print_info "Key fingerprint: $fingerprint"
    fi
    
    # Get bastion hosts
    local bastions
    readarray -t bastions < <(parse_inventory "bastion")
    
    if [[ ${#bastions[@]} -eq 0 ]]; then
        print_error "No bastion hosts found in inventory"
        exit 1
    fi
    
    # Filter bastions if specified
    if [[ -n "$bastion_filter" ]]; then
        local filtered_bastions=()
        for bastion in "${bastions[@]}"; do
            if [[ "$bastion" == "$bastion_filter" ]]; then
                filtered_bastions+=("$bastion")
                break
            fi
        done
        bastions=("${filtered_bastions[@]}")
        
        if [[ ${#bastions[@]} -eq 0 ]]; then
            print_error "Bastion host not found: $bastion_filter"
            exit 1
        fi
    fi
    
    # Get backend hosts
    local backends
    readarray -t backends < <(parse_inventory "postgres_cluster")
    
    if [[ ${#backends[@]} -eq 0 ]]; then
        print_error "No backend hosts found in inventory"
        exit 1
    fi
    
    print_info "Found ${#bastions[@]} bastion(s) and ${#backends[@]} backend(s)"
    
    # Process each backend through available bastions
    local success_count=0
    local total_count=0
    
    for backend in "${backends[@]}"; do
        local backend_ip
        backend_ip=$(get_host_details "$backend")
        
        if [[ -z "$backend_ip" ]]; then
            print_warning "Could not find IP address for backend: $backend"
            continue
        fi
        
        print_info "Processing backend: $backend ($backend_ip)"
        
        # Try each bastion until one works
        local backend_success=false
        
        for bastion in "${bastions[@]}"; do
            local bastion_ip
            bastion_ip=$(get_host_details "$bastion")
            
            if [[ -z "$bastion_ip" ]]; then
                print_warning "Could not find IP address for bastion: $bastion"
                continue
            fi
            
            print_info "  Trying through bastion: $bastion ($bastion_ip)"
            
            # Create proxy command
            local proxy_cmd="ssh -A -W $backend_ip:22 -q $username@$bastion_ip -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            
            total_count=$((total_count + 1))
            
            # Test connectivity first
            if test_ssh_connectivity "$backend_ip" "$username" "$proxy_cmd"; then
                print_success "    SSH connectivity test passed"
                
                if [[ "$test_only" == false ]]; then
                    # Copy SSH key
                    if copy_ssh_key "$key_file" "$backend_ip" "$username" "$proxy_cmd"; then
                        print_success "    SSH key copied successfully"
                        success_count=$((success_count + 1))
                        backend_success=true
                        break
                    else
                        print_error "    Failed to copy SSH key"
                    fi
                else
                    print_info "    Test mode: skipping key copy"
                    success_count=$((success_count + 1))
                    backend_success=true
                    break
                fi
            else
                print_warning "    SSH connectivity test failed"
            fi
        done
        
        if [[ "$backend_success" == false ]]; then
            print_error "  Failed to access backend $backend through any bastion"
        fi
    done
    
    # Summary
    echo
    print_info "Summary"
    print_info "======="
    
    if [[ "$test_only" == true ]]; then
        print_info "SSH connectivity test completed"
        print_info "Successful connections: $success_count/$total_count"
    else
        print_info "SSH key distribution completed"
        print_info "Successful deployments: $success_count/$total_count"
    fi
    
    if [[ $success_count -eq $total_count ]] && [[ $total_count -gt 0 ]]; then
        print_success "All operations completed successfully!"
        
        if [[ "$test_only" == false ]]; then
            echo
            print_info "You can now SSH directly to backend nodes:"
            for backend in "${backends[@]}"; do
                local backend_ip
                backend_ip=$(get_host_details "$backend")
                if [[ -n "$backend_ip" ]]; then
                    echo "  ssh -A -J $username@${bastions[0]} $username@$backend_ip"
                fi
            done
        fi
    else
        print_warning "Some operations failed. Check the output above for details."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
