#!/bin/bash
# Phase 1: Create Single Linux Lab VM
# Usage: ./create-linux-lab-vm.sh [location]
#
# Environment Variables:
#   AZURE_VM_SIZE        - VM size (default: Standard_B1s)
#   AZURE_VM_IMAGE       - VM image (default: Ubuntu2404)
#   AZURE_ADMIN_USER     - Admin username (default: azureuser)
#   AZURE_SSH_KEY_PATH   - SSH key path (default: ~/.ssh/azure-vm-key)
#   AZURE_DO_NOT_PROMPT  - Skip confirmations (default: false)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/az-common.sh"

# Configuration
LOCATION="${1:-eastus}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-devops-learn-rg}"
VM_NAME="${AZURE_VM_NAME:-devops-learn-vm}"
ADMIN_USER="${AZURE_ADMIN_USER:-azureuser}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_B1s}"
VM_IMAGE="${AZURE_VM_IMAGE:-Ubuntu2404}"
SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-$HOME/.ssh/azure-vm-key}"

display_header "Linux Lab VM Setup"

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
    echo "   AZURE_SSH_KEY_PATH=~/.ssh/id_ed25519 ./create-linux-lab-vm.sh"
    echo ""
    echo "3. Let the script create one automatically:"
    echo "   ./create-linux-lab-vm.sh"
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

# Check if VM already exists
if vm_exists "$RESOURCE_GROUP" "$VM_NAME"; then
    log_warning "VM '$VM_NAME' already exists in resource group '$RESOURCE_GROUP'"
    echo ""
    if ! confirm_action "Do you want to continue and update the existing VM?"; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    log_info "Proceeding with existing VM..."
fi

# Create resource group if it doesn't exist
if ! resource_group_exists "$RESOURCE_GROUP"; then
    log_info "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    log_success "Resource group created"
else
    log_info "Resource group already exists: $RESOURCE_GROUP"
fi

# Create VM
log_info "Creating VM: $VM_NAME"
log_info "  Image: $VM_IMAGE"
log_info "  Size: $VM_SIZE"
log_info "  User: $ADMIN_USER"

if az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "$SSH_KEY" \
    --public-ip-sku Standard \
    --tags "purpose=linux-lab" "environment=dev" "created-by=az-script" \
    --output none 2>/dev/null; then
    log_success "VM created successfully"
else
    if vm_exists "$RESOURCE_GROUP" "$VM_NAME"; then
        log_warning "VM may already exist or is being updated"
    else
        log_error "Failed to create VM"
        exit 1
    fi
fi

# Open SSH port
log_info "Opening SSH port (22)..."
az vm open-port \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --port 22 \
    --priority 100 \
    --output none 2>/dev/null || log_warning "Failed to open SSH port (may already be open)"

# Get VM details
log_info "Retrieving VM details..."
PUBLIC_IP=$(get_vm_public_ip "$RESOURCE_GROUP" "$VM_NAME")

if [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to retrieve public IP"
    exit 1
fi

# Display success message
display_header "Setup Complete"
display_resource_summary "$RESOURCE_GROUP" "$LOCATION"

echo "Connection Details:"
echo "  Public IP: $PUBLIC_IP"
echo "  SSH Command:"
echo "    ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
echo ""

echo "Quick Start Commands:"
echo ""
echo "1. Connect to your VM:"
echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
echo ""
echo "2. Upload scripts to VM:"
echo "   scp -i ${SSH_KEY_PATH} ${SCRIPT_DIR}/*.sh ${ADMIN_USER}@${PUBLIC_IP}:~/"
echo ""
echo "3. Run SSH hardening (from your local machine):"
echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'bash ~/01-ssh-hardening.sh'"
echo ""
echo "4. Clean up resources when done:"
echo "   ./cleanup-linux-lab-vm.sh"
echo ""

log_success "VM is ready for use!"