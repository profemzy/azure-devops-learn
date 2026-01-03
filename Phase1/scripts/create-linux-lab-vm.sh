#!/bin/bash
# Phase 1: Create Single Linux Lab VM
# Usage: ./create-linux-lab-vm.sh [location]

set -euo pipefail

LOCATION="${1:-eastus}"
RESOURCE_GROUP="devops-learn-rg"
VM_NAME="devops-learn-vm"
ADMIN_USER="azureuser"
SSH_KEY_PATH="$HOME/.ssh/azure-vm-key"

echo "=== Linux Lab VM Setup ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "VM Name: $VM_NAME"
echo "Location: $LOCATION"
echo ""

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed."
    exit 1
fi

if ! az account show &>/dev/null; then
    echo "Error: Not logged into Azure. Run 'az login' first."
    exit 1
fi

# Check for SSH key pair
if [ ! -f "${SSH_KEY_PATH}" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    echo "Error: SSH key pair not found at: ${SSH_KEY_PATH}"
    echo ""
    echo "Please generate an SSH key pair first:"
    echo ""
    echo "  ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key"
    echo ""
    echo "Or use your existing key by updating SSH_KEY_PATH in this script."
    exit 1
fi

echo "Using existing SSH key: ${SSH_KEY_PATH}"

SSH_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Create resource group
echo "Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output none

# Create VM
echo "Creating VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --ssh-key-values "$SSH_KEY" \
  --public-ip-sku Standard \
  --tags "purpose=linux-lab" "environment=dev" \
  --output none

# Open SSH port
echo "Opening SSH port..."
az vm open-port \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --port 22 \
  --output none

# Get VM details
PUBLIC_IP=$(az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --show-details \
  --query "publicIps" \
  --output tsv)

echo ""
echo "=== Setup Complete ==="
echo ""
echo "VM Details:"
echo "  Name: $VM_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Public IP: $PUBLIC_IP"
echo "  Admin User: $ADMIN_USER"
echo ""
echo "Connect to your VM:"
echo "  ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP}"
echo ""
echo "Next steps:"
echo "  1. SSH into your VM to practice Linux commands"
echo "  2. Upload scripts using scp:"
echo "     scp -i ${SSH_KEY_PATH} scripts/*.sh ${ADMIN_USER}@${PUBLIC_IP}:~/"
echo "  3. Run the SSH hardening script:"
echo "     ssh -i ${SSH_KEY_PATH} ${ADMIN_USER}@${PUBLIC_IP} 'chmod +x ~/01-ssh-hardening.sh && sudo ~/01-ssh-hardening.sh'"