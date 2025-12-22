#!/bin/bash
# Phase 1: Multi-VM Cleanup Script
# Removes all resources created by create-multi-vms.sh

set -euo pipefail

RESOURCE_GROUP="rg-devops-learn"
VNET_NAME="vnet-devops-learn"
VM_NAMES=("bastion" "web1" "web2" "web3" "app1" "app2" "db1")
NSG_NAMES=("nsg-bastion" "nsg-web" "nsg-app" "nsg-db")

echo "=== Phase 1: Multi-VM Cleanup ==="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed."
    exit 1
fi

# Check if logged in
if ! az account show &>/dev/null; then
    echo "Error: Not logged into Azure. Run 'az login' first."
    exit 1
fi

# Confirmation
if [ "${AZURE_DO_NOT_PROMPT_CLEANUP:-}" != "true" ]; then
    echo "This will delete:"
    echo "  Resource Group: $RESOURCE_GROUP (contains 7 VMs, VNet, 4 NSGs)"
    echo ""
    read -p "Proceed with cleanup? (yes/no): " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo ""
echo "=== Cleaning Up Multi-VM Resources ==="
echo ""

# Delete VMs
for vm in "${VM_NAMES[@]}"; do
    echo "[DELETE] Deleting VM: $vm..."
    az vm delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm" \
        --yes \
        --no-wait \
        2>/dev/null || echo "  [SKIP] $vm (not found)"
done

# Delete NSGs
for nsg in "${NSG_NAMES[@]}"; do
    echo "[DELETE] Deleting NSG: $nsg..."
    az network nsg delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$nsg" \
        --no-wait \
        2>/dev/null || echo "  [SKIP] $nsg (not found)"
done

# Delete VNet (this will also delete subnets)
echo "[DELETE] Deleting VNet: $VNET_NAME..."
az network vnet delete \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --no-wait \
    2>/dev/null || echo "  [SKIP] $VNET_NAME (not found)"

# Delete resource group (removes everything else)
echo "[DELETE] Deleting Resource Group: $RESOURCE_GROUP..."
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    az group delete \
        --name "$RESOURCE_GROUP" \
        --yes \
        --no-wait
    echo "[OK] Resource group deletion initiated"
else
    echo "[SKIP] $RESOURCE_GROUP (not found)"
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Resources are being deleted in the background."
echo "To verify, run: az group list --query '[].name' --output table"
