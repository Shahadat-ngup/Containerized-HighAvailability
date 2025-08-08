#!/bin/bash

# Environment Setup Script
# This script helps you create .env files from templates after cloning the repository

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to create .env file from template
create_env_from_template() {
    local template_file="$1"
    local env_file="$2"
    
    if [[ ! -f "$template_file" ]]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    if [[ -f "$env_file" ]]; then
        print_warning "File already exists: $env_file"
        read -p "Do you want to overwrite it? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping $env_file"
            return 0
        fi
    fi
    
    cp "$template_file" "$env_file"
    print_success "Created $env_file from template"
    print_warning "IMPORTANT: Edit $env_file and replace placeholder values with your actual credentials!"
    return 0
}

print_info "Environment Setup Script for IAM HA Stack"
print_info "=========================================="
print_warning "This script creates .env files from templates."
print_warning "You MUST edit these files with your actual credentials before deployment!"
echo

# Create main environment files
print_info "Creating environment files from templates..."

# Backend environment
create_env_from_template "backend1.env.template" "backend1.env"

# Docker backend environment  
create_env_from_template "docker/backend/.env.template" "docker/backend/.env"

# Secrets environment
create_env_from_template "secrets/.env.template" "secrets/.env"

echo
print_info "Environment files created. Next steps:"
echo "1. Edit backend1.env with your database and admin passwords"
echo "2. Edit docker/backend/.env with your database and admin passwords"
echo "3. Edit secrets/.env with your DYNU API key and email"
echo "4. Generate SSL certificates using the request_cert.sh script"
echo "5. Run ansible playbooks to deploy the infrastructure"

echo
print_warning "Security reminders:"
echo "- Never commit .env files to git"
echo "- Use strong, unique passwords"
echo "- Keep your API keys secure"
echo "- The .gitignore file is configured to ignore these files"

echo
print_info "For more information, see the project README and documentation."
