#!/bin/bash
# Phase 3: Azure Identity & Security Validation Script
# Validates completion of all Phase 3 labs

set -euo pipefail

echo "=== Phase 3: Azure Fundamentals & Security Validation ==="
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
        echo "[SKIP] $name (requires Azure CLI login)"
        ((SKIP++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

# Check if logged in to Azure
check_azure_login() {
    if ! az account show > /dev/null 2>&1; then
        echo "[INFO] Please run 'az login' first"
        return 2
    fi
    return 0
}

# Check 1: Azure CLI login
echo "--- Prerequisites ---"
check_azure_login
if [ $? -eq 2 ]; then
    echo "Exiting validation. Please log in to Azure first."
    exit 2
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
echo "Using subscription: $SUBSCRIPTION_ID"

# Check 2: Resource Groups exist
echo ""
echo "--- Lab 3.1: Landing Zone Setup ---"

RG_COUNT=$(az group list --query "length([?contains(name, 'rg-devops')])" -o tsv 2>/dev/null || echo "0")
if [ "$RG_COUNT" -ge 4 ]; then
    check "Resource Groups created (found: $RG_COUNT)" 0
else
    check "Resource Groups created (found: $RG_COUNT)" 1
fi

# Check 3: Virtual Network
echo ""
echo "--- Lab 3.5: VNet Design ---"
VNET_EXISTS=$(az network vnet list --query "[?contains(name, 'vnet-devops')]" -o tsv 2>/dev/null | wc -l)
if [ "$VNET_EXISTS" -gt 0 ]; then
    check "Virtual Network created" 0
    VNET_NAME=$(az network vnet list --query "[?contains(name, 'vnet-devops')][0].name" -o tsv)
    echo "  VNet: $VNET_NAME"
else
    check "Virtual Network created" 1
fi

# Check 4: Subnets
if [ -n "${VNET_NAME:-}" ]; then
    SUBNET_COUNT=$(az network vnet subnet list --vnet-name "$VNET_NAME" -g "rg-devops-prod-networking-eastus" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    if [ "$SUBNET_COUNT" -ge 2 ]; then
        check "Subnets created (found: $SUBNET_COUNT)" 0
    else
        check "Subnets created (found: $SUBNET_COUNT)" 1
    fi
fi

# Check 5: NSGs
echo ""
echo "--- Lab 3.6: Network Security Groups ---"
NSG_COUNT=$(az network nsg list --query "[?contains(name, 'nsg-devops')]" -o tsv 2>/dev/null | wc -l)
if [ "$NSG_COUNT" -ge 2 ]; then
    check "NSGs created (found: $NSG_COUNT)" 0
else
    check "NSGs created (found: $NSG_COUNT)" 1
fi

# Check 6: Key Vault
echo ""
echo "--- Lab 3.9: Key Vault ---"
KV_EXISTS=$(az keyvault list --query "[?contains(name, 'kv-devops')]" -o tsv 2>/dev/null | wc -l)
if [ "$KV_EXISTS" -gt 0 ]; then
    check "Key Vault created" 0
    KV_NAME=$(az keyvault list --query "[?contains(name, 'kv-devops')][0].name" -o tsv)
    echo "  Key Vault: $KV_NAME"

    # Check soft-delete
    SOFT_DELETE=$(az keyvault show --name "$KV_NAME" --query "properties.enableSoftDelete" -o tsv 2>/dev/null || echo "false")
    if [ "$SOFT_DELETE" = "true" ]; then
        check "Key Vault soft-delete enabled" 0
    else
        check "Key Vault soft-delete enabled" 1
    fi
else
    check "Key Vault created" 1
    check "Key Vault soft-delete enabled" 1
fi

# Check 7: Secrets in Key Vault
if [ -n "${KV_NAME:-}" ]; then
    SECRET_COUNT=$(az keyvault secret list --vault-name "$KV_NAME" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    if [ "$SECRET_COUNT" -ge 3 ]; then
        check "Secrets stored (found: $SECRET_COUNT)" 0
    else
        check "Secrets stored (found: $SECRET_COUNT)" 1
    fi
fi

# Check 8: Log Analytics Workspace
echo ""
echo "--- Lab 3.13: Log Analytics ---"
LAW_EXISTS=$(az monitor log-analytics workspace list --query "[?contains(name, 'law')]" -o tsv 2>/dev/null | wc -l)
if [ "$LAW_EXISTS" -gt 0 ]; then
    check "Log Analytics workspace created" 0
    LAW_NAME=$(az monitor log-analytics workspace list --query "[?contains(name, 'law')][0].name" -o tsv)
    echo "  Workspace: $LAW_NAME"
else
    check "Log Analytics workspace created" 1
fi

# Check 9: Managed Identity
echo ""
echo "--- Lab 3.3: Managed Identities ---"
IDENTITY_COUNT=$(az identity list --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$IDENTITY_COUNT" -ge 1 ]; then
    check "Managed Identity created (found: $IDENTITY_COUNT)" 0
else
    check "Managed Identity created" 1
fi

# Check 10: Private Endpoints
echo ""
echo "--- Lab 3.7: Private Endpoints ---"
PE_COUNT=$(az network private-endpoint list --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$PE_COUNT" -ge 1 ]; then
    check "Private Endpoints created (found: $PE_COUNT)" 0
else
    echo "[INFO] No Private Endpoints found - optional for basic setup"
    ((SKIP++))
fi

# Check 11: Private DNS Zones
echo ""
PDNS_COUNT=$(az network private-dns zone list --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$PDNS_COUNT" -ge 1 ]; then
    check "Private DNS Zones created (found: $PDNS_COUNT)" 0
else
    echo "[INFO] No Private DNS Zones found - optional for PE setup"
    ((SKIP++))
fi

# Check 12: RBAC Role Assignments
echo ""
echo "--- Lab 3.2: RBAC ---"
ROLE_COUNT=$(az role assignment list --assignee "$(az ad signed-in-user show --query id -o tsv)" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$ROLE_COUNT" -ge 1 ]; then
    check "Role assignments exist" 0
else
    check "Role assignments exist" 1
fi

# Check 13: Alert Rules
echo ""
echo "--- Lab 3.15: Alert Rules ---"
ALERT_COUNT=$(az monitor metrics alert list --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$ALERT_COUNT" -ge 1 ]; then
    check "Alert rules created (found: $ALERT_COUNT)" 0
else
    echo "[INFO] No alert rules found - optional for basic validation"
    ((SKIP++))
fi

# Check 14: Documentation
echo ""
echo "--- Documentation ---"
if [ -f "../docs/identity-architecture.md" ]; then
    check "Identity architecture documentation" 0
else
    check "Identity architecture documentation" 1
fi

if [ -f "../docs/network-architecture.png" ] || [ -f "../docs/network-architecture.md" ]; then
    check "Network architecture documentation" 0
else
    check "Network architecture documentation" 1
fi

if [ -f "../docs/keyvault-rbac.md" ]; then
    check "Key Vault RBAC documentation" 0
else
    check "Key Vault RBAC documentation" 1
fi

if [ -f "../docs/monitoring-runbook.md" ]; then
    check "Monitoring runbook" 0
else
    check "Monitoring runbook" 1
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "[SUCCESS] All Phase 3 validation checks passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Review interview topics in each guide"
    echo "  2. Complete any failed items"
    echo "  3. Proceed to Phase 4: Terraform"
    exit 0
else
    echo "[INCOMPLETE] Some checks failed. Review the labs and try again."
    echo ""
    echo "Tips:"
    echo "  - Ensure you're logged in: az account show"
    echo "  - Check resource names match expected pattern: rg-devops-*, vnet-devops-*, etc."
    echo "  - Review each guide's lab steps"
    exit 1
fi