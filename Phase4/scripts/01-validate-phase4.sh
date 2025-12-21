#!/bin/bash
# Phase 4: Terraform Validation Script
# Validates Phase 4 Terraform configuration

set -euo pipefail

echo "=== Phase 4: Terraform Validation ==="
echo ""

PASS=0
FAIL=0
SKIP=0

check() {
    local name="$1"
    local result="$2"

    if [ "$result" -eq 0 ]; then
        echo "[PASS] $name"
        ((PASS++))
    elif [ "$result" -eq 2 ]; then
        echo "[SKIP] $name"
        ((SKIP++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

# Check prerequisites
echo "--- Prerequisites ---"
if ! command -v terraform &> /dev/null; then
    echo "[FAIL] Terraform not installed"
    exit 1
fi
check "Terraform installed" 0

TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version')
echo "  Version: $TERRAFORM_VERSION"

if ! command -v az &> /dev/null; then
    echo "[FAIL] Azure CLI not installed"
    exit 1
fi
check "Azure CLI installed" 0

# Check Azure login
if ! az account show > /dev/null 2>&1; then
    echo "[INFO] Please run 'az login' or 'az account set --subscription'"
    exit 2
fi
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
check "Azure authenticated" 0
echo "  Subscription: $SUBSCRIPTION_ID"

# Navigate to environment directory
cd environments/dev 2>/dev/null || cd "$(dirname "$0")/.." || true

# Check directory structure
echo ""
echo "--- Directory Structure ---"

if [ -f "main.tf" ]; then
    check "main.tf exists" 0
else
    check "main.tf exists" 1
fi

if [ -f "backend.tf" ]; then
    check "backend.tf exists" 0

    # Verify backend configuration
    if grep -q "azurerm" backend.tf; then
        check "AzureRM backend configured" 0
    fi
else
    check "backend.tf exists" 1
fi

if [ -f "variables.tf" ]; then
    check "variables.tf exists" 0
fi

if [ -f "outputs.tf" ]; then
    check "outputs.tf exists" 0
fi

if [ -f "terraform.tfvars" ]; then
    check "terraform.tfvars exists" 0
fi

# Check for modules
echo ""
echo "--- Module Structure ---"
if [ -d "../../modules" ]; then
    check "Modules directory exists" 0
    MODULE_COUNT=$(find ../../modules -maxdepth 1 -mindepth 1 -type d | wc -l)
    echo "  Modules found: $MODULE_COUNT"
else
    check "Modules directory exists" 1
fi

# Terraform validation
echo ""
echo "--- Terraform Validation ---"

# Check terraform configuration syntax
if terraform fmt -check -recursive . 2>/dev/null; then
    check "Terraform formatting valid" 0
else
    echo "[WARN] Some files need formatting (run: terraform fmt -recursive)"
fi

# Validate configuration
if terraform validate 2>/dev/null; then
    check "Terraform configuration valid" 0
else
    check "Terraform configuration valid" 1
fi

# Check provider configuration
echo ""
echo "--- Provider Configuration ---"

if grep -q "azurerm" main.tf; then
    check "AzureRM provider configured" 0
fi

if grep -q "~> 4.0" main.tf; then
    check "Provider version ~> 4.0" 0
else
    echo "[INFO] Provider version may differ from recommended"
fi

# Check for OIDC/MI authentication
if grep -q "use_oidc" main.tf || grep -q "managed_service_identity" main.tf; then
    check "Managed Identity/OIDC configured" 0
else
    echo "[INFO] Consider using Managed Identity for authentication"
fi

# Check for remote backend
echo ""
echo "--- Remote Backend ---"

if grep -q 'backend "azurerm"' backend.tf; then
    check "AzureRM backend configured" 0
fi

if grep -q "storage_account_name" backend.tf; then
    check "Storage account configured" 0
fi

if grep -q "container_name" backend.tf; then
    check "Container configured" 0
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "[SUCCESS] Phase 4 validation passed!"
    echo ""
    echo "Next steps:"
    echo "  1. terraform init"
    echo "  2. terraform plan"
    echo "  3. terraform apply"
    exit 0
else
    echo "[INCOMPLETE] Some checks failed. Review the issues above."
    exit 1
fi