#!/bin/bash
# Phase 1: Create Single RHEL-compatible Lab VM (AlmaLinux)
# Usage: ./create-linux-lab-vm.sh [location]
#
# Environment Variables:
#   AZURE_VM_SIZE        - VM size (default: Standard_B4ms)
#   AZURE_VM_IMAGE       - VM image (default: almalinux:almalinux-x86_64:9-gen2:latest)
#   AZURE_ADMIN_USER     - Admin username (default: azureuser)
#   AZURE_SSH_KEY_PATH   - SSH key path (default: ~/.ssh/azure-vm-key)
#   AZURE_INSTALL_LAZYVIM - Auto-install LazyVim (default: true)
#   AZURE_DO_NOT_PROMPT  - Skip confirmations (default: false)
#
# Available AlmaLinux Images:
#   almalinux:almalinux-x86_64:9-gen2:latest    (AlmaLinux 9, Gen2, recommended)
#   almalinux:almalinux-x86_64:8-gen2:latest    (AlmaLinux 8, Gen2)
#   almalinux:almalinux-x86_64:10-gen2:latest   (AlmaLinux 10, Gen2, latest)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/../common/az-common.sh"

# Configuration
LOCATION="${1:-eastus}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-devops-learn-rg}"
VM_NAME="${AZURE_VM_NAME:-devops-rhel-vm}"
ADMIN_USER="${AZURE_ADMIN_USER:-azureuser}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_B4ms}"
VM_IMAGE="${AZURE_VM_IMAGE:-almalinux:almalinux-x86_64:10-gen2:latest}"
SSH_KEY_PATH="${AZURE_SSH_KEY_PATH:-$HOME/.ssh/azure-vm-key}"

display_header "RHEL-compatible Lab VM Setup (AlmaLinux)"

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
    echo "   AZURE_SSH_KEY_PATH=~/.ssh/id_ed25519 ./create-rhel-lab-vm.sh"
    echo ""
    echo "3. Let the script create one automatically:"
    echo "   ./create-rhel-lab-vm.sh"
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
log_info "  Image: $VM_IMAGE (AlmaLinux 10 - RHEL-compatible)"
log_info "  Size: $VM_SIZE"
log_info "  User: $ADMIN_USER"

log_info "Creating VM (this may take 2-3 minutes)..."
if az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "$SSH_KEY" \
    --public-ip-sku Standard \
    --tags "purpose=rhel-lab" "environment=dev" "created-by=az-script" "os-family=rhel" \
    --output none 2>&1; then
    log_success "VM created successfully"
else
    CREATE_EXIT_CODE=$?
    if vm_exists "$RESOURCE_GROUP" "$VM_NAME"; then
        log_warning "VM may already exist or is being updated"
    else
        log_error "Failed to create VM (exit code: $CREATE_EXIT_CODE)"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Check if the image is available in your region:"
        echo "   az vm image list --publisher almalinux --offer almalinux-x86_64 --all"
        echo ""
        echo "2. Verify your quota for $VM_SIZE in $LOCATION:"
        echo "   az quota show"
        echo ""
        echo "3. Try with a different region or image"
        echo ""
        echo "4. Check Azure CLI is logged in:"
        echo "   az account show"
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

# Wait for SSH to be ready
if ! wait_for_ssh "$SSH_KEY_PATH" "$ADMIN_USER" "$PUBLIC_IP" 180; then
    log_error "VM is not accessible via SSH. Please check the VM status and try again."
    echo ""
    echo "VM Details:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  VM Name: $VM_NAME"
    echo "  Public IP: $PUBLIC_IP"
    echo ""
    echo "You can check the VM status manually:"
    echo "  az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --show-details"
    echo ""
    echo "Or connect manually once the VM is ready:"
    echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
    exit 1
fi

# Wait for cloud-init to complete
if ! wait_for_cloud_init "$SSH_KEY_PATH" "$ADMIN_USER" "$PUBLIC_IP" 180; then
    log_warning "Cloud-init may still be running, but continuing with installation..."
fi

# Install LazyVim if requested
INSTALL_LAZYVIM="${AZURE_INSTALL_LAZYVIM:-true}"

if [ "$INSTALL_LAZYVIM" = "true" ]; then
    echo ""
    log_info "Installing LazyVim on VM..."
    echo ""

    LAZYPATH="${SCRIPT_DIR}/install-lazyvim.sh"

    if [ -f "$LAZYPATH" ]; then
        if run_script_on_vm "$SSH_KEY_PATH" "$ADMIN_USER" "$PUBLIC_IP" "$LAZYPATH" 600; then
            log_success "LazyVim installation script completed"

            # Verify installation
            if verify_lazyvim_installation "$SSH_KEY_PATH" "$ADMIN_USER" "$PUBLIC_IP"; then
                log_success "LazyVim verified successfully"
            else
                log_warning "LazyVim installation verification failed, but the VM is ready"
                echo ""
                echo "You can verify LazyVim manually:"
                echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
                echo "  nvim --version"
                echo "  nvim +Lazy"
            fi
        else
            log_error "LazyVim installation failed"
            echo ""
            echo "The VM is ready, but LazyVim installation encountered an issue."
            echo ""
            echo "You can install it manually:"
            echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
            echo "  bash <(curl -s https://raw.githubusercontent.com/LazyVim/starter/bootstrap)"
            echo ""
            echo "Or run the installation script directly:"
            echo "  scp -i ${SSH_KEY_PATH} ${LAZYPATH} ${ADMIN_USER}@${PUBLIC_IP}:~/"
            echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'bash ~/install-lazyvim.sh'"
        fi
    else
        log_warning "LazyVim installer script not found at: $LAZYPATH"
        echo ""
        echo "Note: LazyVim installation on RHEL-compatible systems requires install-lazyvim.sh"
        echo ""
        echo "You can install LazyVim manually:"
        echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
        echo "  bash <(curl -s https://raw.githubusercontent.com/LazyVim/starter/bootstrap)"
    fi
fi

# Note: In the non-LazyVim path, users may still want to upload scripts.

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

if [ "$INSTALL_LAZYVIM" = "true" ]; then
    echo "2. Start using LazyVim:"
    echo "   nvim                    # Open LazyVim"
    echo "   nvim +Lazy              # Manage plugins"
    echo "   :help lazyvim           # View documentation"
    echo ""
    echo "3. Upload scripts to VM:"
    echo "   scp -i ${SSH_KEY_PATH} ${SCRIPT_DIR}/../common/*.sh ${SCRIPT_DIR}/*.sh ${ADMIN_USER}@${PUBLIC_IP}:~/"
    echo ""
    echo "4. Run SSH hardening (from your local machine):"
    echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'bash ~/01-ssh-hardening.sh'"
else
    echo "2. Install EPEL repository (for additional packages):"
    echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'sudo dnf install -y epel-release'"
    echo ""
    echo "3. Install development tools:"
    echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'sudo dnf groupinstall -y \"Development Tools\"'"
    echo ""
    echo "4. Upload scripts to VM:"
    echo "   scp -i ${SSH_KEY_PATH} ${SCRIPT_DIR}/../common/*.sh ${SCRIPT_DIR}/*.sh ${ADMIN_USER}@${PUBLIC_IP}:~/"
    echo ""
    echo "5. Run SSH hardening (from your local machine):"
    echo "   ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'bash ~/01-ssh-hardening.sh'"
fi
echo ""

echo "6. Clean up resources when done:"
echo "   ./scripts/common/cleanup-phase1.sh"
echo ""

log_success "RHEL-compatible VM is ready!"
