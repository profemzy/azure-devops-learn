#!/bin/bash
# Phase 1: Create Multi-VM Infrastructure for Ansible Testing
# Usage: ./create-multi-vms.sh [location]

set -euo pipefail

LOCATION="${1:-eastus}"
RESOURCE_GROUP="rg-devops-learn"
VNET_NAME="vnet-devops-learn"
ADMIN_USER="azureuser"
SSH_KEY_PATH="$HOME/.ssh/azure-vm-key"

echo "=== Multi-VM Setup for Ansible ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""

# Check prerequisites
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Creating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

SSH_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Create resource group
echo "Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output none

# Create VNET
echo "Creating virtual network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefixes 10.0.0.0/16 \
  --location $LOCATION \
  --output none

# Create subnets
for subnet in subnet-bastion subnet-web subnet-app subnet-db; do
    case $subnet in
        subnet-bastion) PREFIX="10.0.0.0/24" ;;
        subnet-web) PREFIX="10.0.1.0/24" ;;
        subnet-app) PREFIX="10.0.2.0/24" ;;
        subnet-db) PREFIX="10.0.3.0/24" ;;
    esac

    az network vnet subnet create \
      --resource-group $RESOURCE_GROUP \
      --vnet-name $VNET_NAME \
      --name $subnet \
      --address-prefixes $PREFIX \
      --output none
done

# Create NSGs and rules
create_nsg() {
    local nsg_name=$1
    local rules=$2

    az network nsg create \
      --resource-group $RESOURCE_GROUP \
      --name $nsg_name \
      --location $LOCATION \
      --output none

    eval "$rules"
}

# Bastion NSG (SSH from anywhere)
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
    --output none
"

# Web NSG (SSH from VNet, HTTP/HTTPS from anywhere)
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
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTP \
    --priority 110 \
    --source-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTPS \
    --priority 111 \
    --source-address-prefixes '*' \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# App NSG
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
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-app \
    --name AllowApp \
    --priority 110 \
    --source-address-prefixes 10.0.1.0/24 \
    --destination-port-ranges 3000 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# DB NSG
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
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-db \
    --name AllowPostgreSQL \
    --priority 110 \
    --source-address-prefixes 10.0.2.0/24 \
    --destination-port-ranges 5432 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# Function to create VM
create_vm() {
    local name=$1
    local subnet=$2
    local nsg=$3
    local tier=$4

    echo "Creating $name VM..."
    az vm create \
      --resource-group $RESOURCE_GROUP \
      --name $name \
      --image Ubuntu2204 \
      --size Standard_B2s \
      --admin-username $ADMIN_USER \
      --ssh-key-values "$SSH_KEY" \
      --vnet-name $VNET_NAME \
      --subnet $subnet \
      --nsg $nsg \
      --public-ip-sku Standard \
      --tags "tier=$tier" "environment=dev" \
      --output none
}

# Create Bastion
create_vm "bastion" "subnet-bastion" "nsg-bastion" "bastion"

# Create Web tier (3 VMs)
for i in 1 2 3; do
    create_vm "web$i" "subnet-web" "nsg-web" "web"
done

# Create App tier (2 VMs)
for i in 1 2; do
    create_vm "app$i" "subnet-app" "nsg-app" "app"
done

# Create DB tier (1 VM)
create_vm "db1" "subnet-db" "nsg-db" "db"

# Get public IPs
echo ""
echo "=== VM Public IP Addresses ==="
az vm list-ip-addresses \
  --resource-group $RESOURCE_GROUP \
  --output table \
  --query "[].{Name:virtualMachine.name,PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress,PrivateIP:virtualMachine.network.privateIpAddresses[0]}"

echo ""
echo "=== Setup Complete ==="
echo "7 VMs created successfully!"
echo ""
echo "Next steps:"
echo "  1. SSH to bastion: ssh -i ~/.ssh/azure-vm-key azureuser@<bastion-ip>"
echo "  2. Copy SSH key to all VMs from bastion"
echo "  3. Configure Ansible inventory"
echo "  4. Run ansible-playbook"