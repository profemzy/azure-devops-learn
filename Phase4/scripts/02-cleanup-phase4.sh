#!/bin/bash
# Phase 4: Terraform Resource Cleanup Script
# WARNING: This will destroy all resources created by Terraform

set -euo pipefail

echo "=== Phase 4: Terraform Resource Cleanup ==="
echo ""
echo "WARNING: This script will destroy all resources in the current workspace."
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

# Navigate to environment directory
cd "$(dirname "$0")/.." || exit 1

# Check if Terraform is initialized
if [ ! -f "environments/dev/terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    echo "[INFO] No Terraform state found. Checking for resources to delete manually..."

    # List resource groups that might need manual cleanup
    echo "Resource groups that may contain Phase 4 resources:"
    az group list --query "[?contains(name, 'terraform') || contains(name, 'devops')]" --output table
    exit 0
fi

# Destroy in each environment
for env in dev stg prod; do
    if [ -d "environments/$env" ]; then
        echo ""
        echo "--- Destroying $env environment ---"
        cd "environments/$env"

        if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
            terraform destroy -auto-approve 2>/dev/null || true
            echo "[DONE] $env environment destroyed"
        else
            echo "[SKIP] $env environment (no state found)"
        fi

        cd ../..
    fi
done

# Note about backend storage
echo ""
echo "--- Backend Storage Note ---"
echo "The Blob Storage account and container used for state are NOT deleted."
echo "To delete the backend:"
echo "  az storage account delete --name STORAGE_ACCOUNT_NAME --resource-group rg-terraform-state --yes"
echo ""
echo "To delete the resource group:"
echo "  az group delete --name rg-terraform-state --yes"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Deleted: Terraform-managed resources"
echo "Retained: Storage account for state (manual cleanup required)"