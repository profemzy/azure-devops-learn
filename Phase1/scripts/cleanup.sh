#!/bin/bash
# Phase 1 Cleanup Script
# WARNING: This will delete ALL resources in the devops-learn-rg resource group

set -euo pipefail

RESOURCE_GROUP="devops-learn-rg"
VM_NAME="devops-learn-vm"

echo "=== Phase 1 Cleanup Script ==="
echo ""
echo "WARNING: This will permanently delete:"
echo "  - Resource Group: $RESOURCE_GROUP"
echo "  - All resources including: $VM_NAME"
echo ""

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Deleting resource group..."
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo "[SUCCESS] Deletion initiated in background."
echo ""
echo "To verify deletion is complete, run:"
echo "  az group show --name $RESOURCE_GROUP"
echo ""
echo "Note: It may take a few minutes for all resources to be fully deleted."
