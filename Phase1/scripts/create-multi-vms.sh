#!/bin/bash
# Phase 1: Create Multi-VM Infrastructure for Ansible Testing
# Usage: ./create-multi-vms.sh [location]
#
# Environment Variables:
#   AZURE_LOCATION        - Azure region (default: eastus)
#   AZURE_VM_SIZE         - VM size (default: Standard_B2s)
#   AZURE_ADMIN_USER      - Admin username (default: azureuser)
#   AZURE_SSH_KEY_PATH    - SSH key path (default: ~/.ssh/azure-vm-key)
#   AZURE_DO_NOT_PROMPT   - Skip confirmations (default: false)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/az-common.sh"

# Configuration
LOCATION="${1:-${AZURE_LOCATION:-eastus}}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-devops-learn}"
VNET_NAME="${AZURE_VNET_NAME:-vnet-devops-learn}"
ADMIN_USER="${AZURE_ADMIN_USER:-azureuser}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_B2s}"
VM_IMAGE="${AZURE_VM_IMAGE:-Ubuntu2404}"
SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-$HOME/.ssh/azure-vm-key}"

# VM definitions
declare -A SUBNET_PREFIXES=(
    ["subnet-bastion"]="10.0.0.0/24"
    ["subnet-web"]="10.0.1.0/24"
    ["subnet-app"]="10.0.2.0/24"
    ["subnet-db"]="10.0.3.0/24"
)

declare -A NSG_SUBNETS=(
    ["nsg-bastion"]="subnet-bastion"
    ["nsg-web"]="subnet-web"
    ["nsg-app"]="subnet-app"
    ["nsg-db"]="subnet-db"
)

declare -A VM_CONFIGS=(
    ["bastion"]="subnet-bastion:nsg-bastion:bastion"
    ["web1"]="subnet-web:nsg-web:web"
    ["web2"]="subnet-web:nsg-web:web"
    ["web3"]="subnet-web:nsg-web:web"
    ["app1"]="subnet-app:nsg-app:app"
    ["app2"]="subnet-app:nsg-app:app"
    ["db1"]="subnet-db:nsg-db:db"
)

display_header "Multi-VM Setup for Ansible"

# Validate location
if ! validate_location "$LOCATION"; then
    exit 1
fi

# Check prerequisites
if ! check_prerequisites; then
    exit 1
fi

# Find or create SSH key
log_info "Checking for SSH keys..."
if ! SSH_KEY_PATH=$(find_or_create_ssh_key "$SSH_KEY_PATH"); then
    log_error "Failed to set up SSH key"
    echo ""
    echo "SSH key is required for VM access. You can:"
    echo ""
    echo "1. Generate a new SSH key:"
    echo "   ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key"
    echo ""
    echo "2. Use an existing key:"
    echo "   AZURE_SSH_KEY_PATH=~/.ssh/id_ed25519 ./create-multi-vms.sh"
    echo ""
    echo "3. Let the script create one automatically:"
    echo "   ./create-multi-vms.sh"
    echo ""
    exit 1
fi

# Check what we got
if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    log_error "SSH key not found at: $SSH_KEY_PATH"
    echo ""
    echo "Please ensure the SSH key exists or let the script create one."
    exit 1
fi

log_success "Using SSH key: $SSH_KEY_PATH"
SSH_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Display configuration
echo ""
echo "Configuration:"
echo "  Location: $LOCATION"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  VNet: $VNET_NAME (10.0.0.0/16)"
echo "  VM Size: $VM_SIZE"
echo "  VM Image: $VM_IMAGE"
echo "  Total VMs: ${#VM_CONFIGS[@]}"
echo ""

# Check if resource group already exists
if resource_group_exists "$RESOURCE_GROUP"; then
    log_warning "Resource group '$RESOURCE_GROUP' already exists"
    if ! confirm_action "Do you want to continue and add/update VMs?"; then
        log_info "Operation cancelled by user"
        exit 0
    fi
fi

# Create resource group
if ! resource_group_exists "$RESOURCE_GROUP"; then
    log_info "Creating resource group..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    log_success "Resource group created"
else
    log_info "Using existing resource group"
fi

# Create VNet
log_info "Creating virtual network..."
if az network vnet show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        &>/dev/null; then
    log_info "VNet already exists"
else
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --address-prefixes 10.0.0.0/16 \
        --location "$LOCATION" \
        --output none
    log_success "VNet created"
fi

# Create subnets
log_info "Creating subnets..."
for subnet in "${!SUBNET_PREFIXES[@]}"; do
    prefix="${SUBNET_PREFIXES[$subnet]}"

    if az network vnet subnet show \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet" \
            &>/dev/null; then
        log_info "  Subnet $subnet already exists"
    else
        az network vnet subnet create \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet" \
            --address-prefixes "$prefix" \
            --output none
        log_success "  Created subnet: $subnet ($prefix)"
    fi
done

# Function to create NSG
create_nsg() {
    local nsg_name=$1
    local rules=$2

    if az network nsg show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$nsg_name" \
            &>/dev/null; then
        log_info "  NSG $nsg_name already exists"
        return 0
    fi

    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$nsg_name" \
        --location "$LOCATION" \
        --output none

    log_info "  Creating NSG: $nsg_name"
    eval "$rules" 2>/dev/null || true
    log_success "  Created NSG: $nsg_name"
}

# Create NSGs
log_info "Creating Network Security Groups..."
create_nsg "nsg-bastion" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-bastion \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output none 2>/dev/null || true
"

create_nsg "nsg-web" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTP \
    --priority 110 \
    --source-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTPS \
    --priority 111 \
    --source-address-prefixes '*' \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
"

create_nsg "nsg-app" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-app \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-app \
    --name AllowApp \
    --priority 110 \
    --source-address-prefixes 10.0.1.0/24 \
    --destination-port-ranges 3000 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
"

create_nsg "nsg-db" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-db \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-db \
    --name AllowPostgreSQL \
    --priority 110 \
    --source-address-prefixes 10.0.2.0/24 \
    --destination-port-ranges 5432 \
    --access Allow \
    --protocol Tcp \
    --output none 2>/dev/null || true
"

# Function to create VM
create_vm() {
    local name=$1
    local subnet=$2
    local nsg=$3
    local tier=$4

    if vm_exists "$RESOURCE_GROUP" "$name"; then
        log_info "  VM $name already exists, skipping..."
        return 0
    fi

    log_info "  Creating VM: $name ($tier tier)"
    if az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$name" \
        --image "$VM_IMAGE" \
        --size "$VM_SIZE" \
        --admin-username "$ADMIN_USER" \
        --ssh-key-values "$SSH_KEY" \
        --vnet-name "$VNET_NAME" \
        --subnet "$subnet" \
        --nsg "$nsg" \
        --public-ip-sku Standard \
        --tags "tier=$tier" "environment=dev" "created-by=az-script" \
        --output none 2>/dev/null; then
        log_success "  Created VM: $name"
    else
        log_error "  Failed to create VM: $name"
        return 1
    fi
}

# Create VMs
log_info "Creating virtual machines..."
echo ""

log_info "Bastion tier (1 VM):"
create_vm "bastion" "subnet-bastion" "nsg-bastion" "bastion"

echo ""
log_info "Web tier (3 VMs):"
for i in 1 2 3; do
    create_vm "web$i" "subnet-web" "nsg-web" "web"
done

echo ""
log_info "App tier (2 VMs):"
for i in 1 2; do
    create_vm "app$i" "subnet-app" "nsg-app" "app"
done

echo ""
log_info "Database tier (1 VM):"
create_vm "db1" "subnet-db" "nsg-db" "db"

# Display VM information
echo ""
display_header "Setup Complete"

log_info "Retrieving VM information..."
echo ""

echo "VM Public IP Addresses:"
az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP" \
    --output table \
    --query "[].{Name:virtualMachine.name,PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress,PrivateIP:virtualMachine.network.privateIpAddresses[0]}" 2>/dev/null || echo "Failed to retrieve IP addresses"

echo ""
echo "Quick Start:"
echo ""
echo "1. Get bastion IP:"
echo "   BASTION_IP=\$(az vm show -g $RESOURCE_GROUP -n bastion -d --query publicIps -o tsv)"
echo ""
echo "2. SSH to bastion:"
echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@\$BASTION_IP"
echo ""
echo "3. From bastion, distribute SSH keys to all VMs:"
echo "   ssh-copy-id azureuser@10.0.0.4  # web1"
echo "   ssh-copy-id azureuser@10.0.0.5  # web2"
echo "   ssh-copy-id azureuser@10.0.0.6  # web3"
echo "   ssh-copy-id azureuser@10.0.1.4  # app1"
echo "   ssh-copy-id azureuser@10.0.1.5  # app2"
echo "   ssh-copy-id azureuser@10.0.2.4  # db1"
echo ""
echo "4. Create Ansible inventory (~/ansible-inventory.ini):"
cat << 'EOF'
[webservers]
web1 ansible_host=10.0.1.4
web2 ansible_host=10.0.1.5
web3 ansible_host=10.0.1.6

[appservers]
app1 ansible_host=10.0.2.4
app2 ansible_host=10.0.2.5

[dbserver]
db1 ansible_host=10.0.3.4

[bastion]
bastion ansible_host=10.0.0.4
EOF
echo ""
echo "5. Test Ansible connectivity:"
echo "   ansible all -i ~/ansible-inventory.ini -m ping"
echo ""
echo "6. Clean up when done:"
echo "   ./cleanup-multi-vms.sh"
echo ""

log_success "Multi-VM environment is ready for Ansible testing!"