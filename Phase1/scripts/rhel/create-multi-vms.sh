#!/bin/bash
# Phase 1: Create Multi-VM Infrastructure for Ansible Testing (RHEL-compatible)
# Usage: ./create-multi-vms.sh [location]
#
# Environment Variables:
#   AZURE_LOCATION         - Azure region (default: eastus)
#   AZURE_VM_SIZE          - VM size (default: Standard_B2s)
#   AZURE_VM_SIZE_BASTION  - Bastion VM size (default: Standard_B4ms)
#   AZURE_ADMIN_USER       - Admin username (default: azureuser)
#   AZURE_SSH_KEY_PATH     - SSH key path (default: ~/.ssh/azure-vm-key)
#   AZURE_VM_IMAGE         - VM image (default: almalinux:almalinux-x86_64:9-gen2:latest)
#   AZURE_DO_NOT_PROMPT    - Skip confirmations (default: false)
#
# Notes:
# - Uses AlmaLinux (RHEL-compatible) by default.
# - Installs LazyVim on bastion (optional via AZURE_INSTALL_LAZYVIM=true/false).

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/../common/az-common.sh"

# Configuration
LOCATION="${1:-${AZURE_LOCATION:-eastus}}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-devops-learn}"
VNET_NAME="${AZURE_VNET_NAME:-vnet-devops-learn}"
ADMIN_USER="${AZURE_ADMIN_USER:-azureuser}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_B2s}"
VM_SIZE_BASTION="${AZURE_VM_SIZE_BASTION:-Standard_B4ms}"
VM_IMAGE="${AZURE_VM_IMAGE:-almalinux:almalinux-x86_64:9-gen2:latest}"
SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-$HOME/.ssh/azure-vm-key}"

# Subnet definitions
declare -A SUBNET_PREFIXES=(
    ["subnet-bastion"]="10.0.0.0/24"
    ["subnet-web"]="10.0.1.0/24"
    ["subnet-app"]="10.0.2.0/24"
    ["subnet-db"]="10.0.3.0/24"
)

display_header "Multi-VM Setup for Ansible (RHEL-compatible)"

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
    exit 1
fi

if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    log_error "SSH key not found at: $SSH_KEY_PATH"
    exit 1
fi

log_success "Using SSH key: $SSH_KEY_PATH"
SSH_KEY=$(cat "${SSH_KEY_PATH}.pub")

echo ""
echo "Configuration:"
echo "  Location: $LOCATION"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  VNet: $VNET_NAME (10.0.0.0/16)"
echo "  VM Image: $VM_IMAGE"
echo "  VM Size: $VM_SIZE"
echo "  Bastion Size: $VM_SIZE_BASTION"
echo "  Total VMs: 7"
echo ""

if resource_group_exists "$RESOURCE_GROUP"; then
    log_warning "Resource group '$RESOURCE_GROUP' already exists"
    if ! confirm_action "Do you want to continue and add/update VMs?"; then
        log_info "Operation cancelled by user"
        exit 0
    fi
fi

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

log_info "Creating virtual network..."
if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &>/dev/null; then
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

log_info "Creating subnets..."
for subnet in "${!SUBNET_PREFIXES[@]}"; do
    prefix="${SUBNET_PREFIXES[$subnet]}"
    if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$subnet" &>/dev/null; then
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

create_nsg() {
    local nsg_name=$1

    if az network nsg show --resource-group "$RESOURCE_GROUP" --name "$nsg_name" &>/dev/null; then
        log_info "  NSG $nsg_name already exists"
        return 0
    fi

    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$nsg_name" \
        --location "$LOCATION" \
        --output none
    log_success "  Created NSG: $nsg_name"
}

log_info "Creating Network Security Groups..."
create_nsg "nsg-bastion"
create_nsg "nsg-web"
create_nsg "nsg-app"
create_nsg "nsg-db"

# Allow SSH to bastion from anywhere
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "nsg-bastion" \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output none 2>/dev/null || true

# Internal SSH between tiers
for nsg in nsg-web nsg-app nsg-db; do
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$nsg" \
        --name AllowSSH \
        --priority 100 \
        --source-address-prefixes 10.0.0.0/16 \
        --destination-port-ranges 22 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --output none 2>/dev/null || true
done

create_vm() {
    local name=$1
    local subnet=$2
    local nsg=$3
    local tier=$4
    local vm_size=$5

    if vm_exists "$RESOURCE_GROUP" "$name"; then
        log_info "  VM $name already exists, skipping..."
        return 0
    fi

    log_info "  Creating VM: $name ($tier tier) - Size: $vm_size"

    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$name" \
        --image "$VM_IMAGE" \
        --size "$vm_size" \
        --admin-username "$ADMIN_USER" \
        --ssh-key-values "$SSH_KEY" \
        --vnet-name "$VNET_NAME" \
        --subnet "$subnet" \
        --nsg "$nsg" \
        --public-ip-sku Standard \
        --tags "tier=$tier" "environment=dev" "created-by=az-script" "os-family=rhel" \
        --output none 2>/dev/null
}

log_info "Creating virtual machines..."
echo ""

log_info "Bastion tier (1 VM):"
create_vm "bastion" "subnet-bastion" "nsg-bastion" "bastion" "$VM_SIZE_BASTION"

echo ""
log_info "Web tier (3 VMs):"
for i in 1 2 3; do
    create_vm "web$i" "subnet-web" "nsg-web" "web" "$VM_SIZE"
done

echo ""
log_info "App tier (2 VMs):"
for i in 1 2; do
    create_vm "app$i" "subnet-app" "nsg-app" "app" "$VM_SIZE"
done

echo ""
log_info "Database tier (1 VM):"
create_vm "db1" "subnet-db" "nsg-db" "db" "$VM_SIZE"

echo ""
log_info "Waiting for VMs to finish provisioning..."
sleep 15

INSTALL_LAZYVIM="${AZURE_INSTALL_LAZYVIM:-true}"
if [ "$INSTALL_LAZYVIM" = "true" ]; then
    echo ""
    log_info "Installing LazyVim on bastion host..."
    echo ""

    BASTION_IP=$(az vm show --resource-group "$RESOURCE_GROUP" --name "bastion" --show-details --query "publicIps" -o tsv 2>/dev/null)

    if [ -n "$BASTION_IP" ]; then
        LAZYPATH="${SCRIPT_DIR}/install-lazyvim.sh"
        if [ -f "$LAZYPATH" ]; then
            if run_script_on_vm "$SSH_KEY_PATH" "$ADMIN_USER" "$BASTION_IP" "$LAZYPATH" 900; then
                log_success "LazyVim installed on bastion"
            else
                log_warning "LazyVim installation on bastion failed (VM may still be booting)"
            fi
        else
            log_warning "LazyVim installer script not found at: $LAZYPATH"
        fi
    else
        log_warning "Failed to retrieve bastion IP - skipping LazyVim installation"
    fi
fi

echo ""
display_header "Setup Complete"

log_info "Retrieving VM information..."
echo ""

echo "VM Public IP Addresses:"
az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP" \
    --output table \
    --query "[].{Name:virtualMachine.name,PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress,PrivateIP:virtualMachine.network.privateIpAddresses[0]}" \
    2>/dev/null || echo "Failed to retrieve IP addresses"

echo ""
echo "Quick Start:"
echo ""
echo "1. Get bastion IP:"
echo "   BASTION_IP=\$(az vm show -g $RESOURCE_GROUP -n bastion -d --query publicIps -o tsv)"
echo ""
echo "2. SSH to bastion (LazyVim pre-installed if enabled):"
echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@\$BASTION_IP"
echo ""
echo "3. Clean up when done:"
echo "   ./scripts/common/cleanup-phase1.sh"
echo ""

log_success "RHEL-compatible multi-VM environment is ready for Ansible testing!"

