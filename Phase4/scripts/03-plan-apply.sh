#!/bin/bash
# Phase 4: Safe Terraform Plan and Apply Script
# Creates a plan file and prompts before applying

set -euo pipefail

ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Phase 4: Terraform Plan & Apply ==="
echo ""
echo "Environment: $ENVIRONMENT"
echo "Working directory: $ROOT_DIR/environments/$ENVIRONMENT"
echo ""

cd "$ROOT_DIR/environments/$ENVIRONMENT" || {
    echo "Error: Environment directory not found: $ROOT_DIR/environments/$ENVIRONMENT"
    exit 1
}

# Step 1: Initialize
echo "--- Step 1: Initialize ---"
terraform init

# Step 2: Format
echo ""
echo "--- Step 2: Format ---"
terraform fmt -recursive

# Step 3: Validate
echo ""
echo "--- Step 3: Validate ---"
if terraform validate; then
    echo "[VALID] Configuration is valid"
else
    echo "[ERROR] Configuration validation failed"
    exit 1
fi

# Step 4: Plan
echo ""
echo "--- Step 4: Planning ---"
terraform plan -out=tfplan

# Show plan summary
echo ""
echo "Plan saved to: tfplan"
echo ""
echo "Plan Summary:"
terraform show -no-color tfplan | grep -E "(Plan:|will be created|will be destroyed|will be updated|will be changed)"

# Step 5: Confirm Apply
echo ""
echo "--- Step 5: Apply ---"
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    echo ""
    echo "Applying changes..."
    terraform apply tfplan
    echo ""
    echo "[SUCCESS] Resources created/updated successfully!"
else
    echo ""
    echo "Apply cancelled. Plan file saved as: tfplan"
    echo "To apply later: terraform apply tfplan"
fi

echo ""
echo "Useful commands:"
echo "  terraform state list    # List resources"
echo "  terraform show          # Show current state"
echo "  terraform destroy       # Destroy all resources"