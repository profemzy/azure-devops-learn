#!/bin/bash
# Phase 1: Cleanup Single Linux Lab VM
# Removes resources created by create-linux-lab-vm.sh
# Usage: ./cleanup-linux-lab-vm.sh

set -euo pipefail

RESOURCE_GROUP="devops-learn-rg"
VM_NAME="devops-learn-vm"

echo "=== Linux Lab VM Cleanup ==="
echo ""
echo "This will delete:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  (includes VM and all related resources)"
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

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Resource group '$RESOURCE_GROUP' not found. Nothing to cleanup."
    exit 0
fi

# Confirm deletion
if [ "${AZURE_DO_NOT_PROMPT_CLEANUP:-}" != "true" ]; then
    read -p "Proceed with deletion? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo ""
echo "Deleting resource group: $RESOURCE_GROUP..."

# Delete resource group (removes all resources within it)
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait \
    2>/dev/null || true

echo "Deletion initiated for: $RESOURCE_GROUP"
echo ""
echo "Note: Complete deletion may take a few minutes."
echo "To verify, run: az group show --name $RESOURCE_GROUP"