#!/bin/bash
# Phase 1: Comprehensive Cleanup Script
# Removes all resources created during Phase 1 learning
# Handles both single VM and multi-VM setups

set -euo pipefail

echo "=== Phase 1: Resource Cleanup ==="
echo ""

# Configuration
RESOURCE_GROUPS=(
    "devops-learn-rg"        # Single VM setup
    "rg-devops-learn"        # Multi-VM setup
    "rg-terraform-state"     # Terraform state backend
)

VM_NAMES=("devops-learn-vm")
MULTI_VM_NAMES=("bastion" "web1" "web2" "web3" "app1" "app2" "db1")

show_status() {
    echo "[$1] $2"
}

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

echo "This script will clean up Phase 1 resources:"
echo ""
echo "Resource groups that may be deleted:"
for rg in "${RESOURCE_GROUPS[@]}"; do
    if az group show --name "$rg" &>/dev/null; then
        echo "  [X] $rg (exists)"
    else
        echo "  [ ] $rg (not found)"
    fi
done
echo ""

# Count VMs to be deleted
TOTAL_VMS=0
for vm in "${VM_NAMES[@]}" "${MULTI_VM_NAMES[@]}"; do
    TOTAL_VMS=$((TOTAL_VMS + 1))
done

# Confirmation
if [ "${AZURE_DO_NOT_PROMPT_CLEANUP:-}" != "true" ]; then
    echo "Summary:"
    echo "  Resource groups: ${#RESOURCE_GROUPS[@]}"
    echo "  VMs to check: $TOTAL_VMS"
    echo ""
    read -p "Proceed with cleanup? (yes/no): " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo ""
echo "=== Cleaning Up Resources ==="
echo ""

# Function to delete a resource group
delete_resource_group() {
    local rg=$1

    if ! az group show --name "$rg" &>/dev/null; then
        show_status "SKIP" "$rg (does not exist)"
        return 0
    fi

    show_status "DELETE" "$rg (initiating deletion)"

    # Delete the resource group (removes all resources within it)
    az group delete \
        --name "$rg" \
        --yes \
        --no-wait \
        2>/dev/null || true

    show_status "OK" "$rg deletion initiated"
}

# Function to wait for resource group deletion
wait_for_deletion() {
    local rg=$1
    local max_attempts=30
    local attempt=1

    echo "Waiting for $rg to be deleted..."
    while [ $attempt -le $max_attempts ]; do
        if ! az group show --name "$rg" &>/dev/null; then
            show_status "DONE" "$rg has been deleted"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts - still deleting..."
        sleep 10
        attempt=$((attempt + 1))
    done

    show_status "WARN" "$rg may still be deleting (timeout)"
}

# Delete all known resource groups
for rg in "${RESOURCE_GROUPS[@]}"; do
    delete_resource_group "$rg"
done

echo ""
echo "=== Verifying Cleanup ==="
echo ""

# Verify resource groups are gone
CLEANUP_STATUS=0
for rg in "${RESOURCE_GROUPS[@]}"; do
    if az group show --name "$rg" &>/dev/null; then
        show_status "REMAIN" "$rg"
        CLEANUP_STATUS=1
    else
        show_status "CLEAN" "$rg"
    fi
done

echo ""
echo "=== Cleanup Summary ==="
echo ""

if [ $CLEANUP_STATUS -eq 0 ]; then
    echo "[SUCCESS] All Phase 1 resources have been cleaned up!"
else
    echo "[WARNING] Some resource groups still exist."
    echo "          They may still be deleting. Check Azure portal."
fi

echo ""
echo "To verify all resources are gone, run:"
echo "  az group list --query '[].name' --output table"
echo ""
echo "Note: Some resources may take a few minutes to fully disappear."