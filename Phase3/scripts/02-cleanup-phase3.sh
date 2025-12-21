#!/bin/bash
# Phase 3: Azure Resource Cleanup Script
# WARNING: This will permanently delete resources created in Phase 3

set -euo pipefail

echo "=== Phase 3: Azure Resource Cleanup ==="
echo ""
echo "WARNING: This script will delete resources created in Phase 3."
echo "This action is IRREVERSIBLE."
echo ""

# Check for confirmation
if [ "${AZURE_DO_NOT_PROMPT_CLEANUP:-}" != "true" ]; then
    read -p "Are you sure you want to continue? (type 'DELETE' to confirm): " CONFIRM
    if [ "$CONFIRM" != "DELETE" ]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo ""
echo "Starting cleanup..."

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "Error: Not logged in to Azure. Run 'az login' first."
    exit 1
fi

echo "Using subscription: $SUBSCRIPTION_ID"
echo ""

# Function to safely delete resource
delete_resource() {
    local type=$1
    local name=$2
    local rg=$3

    echo "Deleting $type: $name..."
    if az $type show --name "$name" --resource-group "$rg" > /dev/null 2>&1; then
        az $type delete --name "$name" --resource-group "$rg" --yes --no-wait 2>/dev/null || true
        echo "  [QUEUED] $name"
    else
        echo "  [SKIP] $name (not found)"
    fi
}

# Resource Groups to clean up
RESOURCE_GROUPS=(
    "rg-devops-prod-networking-eastus"
    "rg-devops-prod-compute-eastus"
    "rg-devops-prod-security-eastus"
    "rg-devops-prod-monitoring-eastus"
)

echo "--- Deleting Resource Groups ---"
for rg in "${RESOURCE_GROUPS[@]}"; do
    if az group show --name "$rg" > /dev/null 2>&1; then
        echo "Deleting Resource Group: $rg"
        az group delete --name "$rg" --yes --no-wait
        echo "  [QUEUED] $rg"
    else
        echo "[SKIP] Resource Group: $rg (not found)"
    fi
done

echo ""
echo "--- Cleaning up Management Groups (Manual) ---"
echo "Note: Management groups require manual deletion due to hierarchy dependencies."
echo "Delete via Azure Portal: Home > Management groups"
echo "  - corp"
echo "  - prod"
echo "  - sandbox"

echo ""
echo "--- Cleanup Complete ---"
echo ""
echo "Note: Some resources may still be terminating in the background."
echo "Check Azure Portal for status."
echo ""
echo "Resources NOT deleted (shared resources):"
echo "  - Other resource groups"
echo "  - Key Vaults in other subscriptions"
echo "  - Management groups"
echo ""
echo "To verify cleanup:"
echo "  az group list --query \"[?contains(name, 'rg-devops')]\" --output table"

# Wait for deletion (optional)
if [ "${WAIT_FOR_CLEANUP:-}" = "true" ]; then
    echo ""
    echo "Waiting for resource group deletions to complete..."
    for rg in "${RESOURCE_GROUPS[@]}"; do
        while az group show --name "$rg" > /dev/null 2>&1; do
            echo "  Waiting for $rg..."
            sleep 10
        done
        echo "  $rg deleted"
    done
    echo "All resource groups deleted."
fi