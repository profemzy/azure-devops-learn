#!/bin/bash
# Phase 3: Key Vault Access Script
# Demonstrates secure secret retrieval using Managed Identity

set -euo pipefail

# Configuration
KEY_VAULT_NAME="${1:-kv-devops-prod-secrets}"
SECRET_NAME="${2:-database-connection-string}"

echo "=== Key Vault Access Demo ==="
echo ""
echo "Key Vault: $KEY_VAULT_NAME"
echo "Secret: $SECRET_NAME"
echo ""

# Method 1: Using Azure CLI with user login (development only)
method_user_login() {
    echo "--- Method 1: User Login (Development) ---"

    # Check if logged in
    if ! az account show > /dev/null 2>&1; then
        echo "Not logged in. Run: az login"
        return 1
    fi

    # Get secret value
    SECRET_VALUE=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$SECRET_NAME" \
        --query "secret.value" \
        -o tsv 2>/dev/null) || true

    if [ -n "$SECRET_VALUE" ]; then
        echo "[SUCCESS] Secret retrieved successfully"
        echo "Value (first 50 chars): ${SECRET_VALUE:0:50}..."
    else
        echo "[FAIL] Could not retrieve secret"
    fi
}

# Method 2: Using Managed Identity (production)
method_managed_identity() {
    echo ""
    echo "--- Method 2: Managed Identity (Production) ---"

    # Check if running on Azure VM
    IMDS_ENDPOINT="http://169.254.169.254/metadata/identity/oauth2/token"
    if ! curl -s -H "Metadata: true" "$IMDS_ENDPOINT?resource=https://vault.azure.net" > /dev/null 2>&1; then
        echo "Not running on Azure VM with Managed Identity"
        echo "This method requires:"
        echo "  1. VM with system or user-assigned managed identity"
        echo "  2. Role assignment: Key Vault Secrets User"
        echo ""
        echo "Example role assignment:"
        echo "  az role assignment create \\"
        echo "    --assignee <vm-principal-id> \\"
        echo "    --role 'Key Vault Secrets User' \\"
        echo "    --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
        return 1
    fi

    # Get access token
    echo "Getting access token from IMDS..."
    TOKEN=$(curl -s -H "Metadata: true" \
        "$IMDS_ENDPOINT?resource=https://vault.azure.net&api-version=2018-02-01" \
        | jq -r '.access_token') || true

    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        echo "[SUCCESS] Got access token"

        # Get secret
        echo "Retrieving secret..."
        SECRET_VALUE=$(curl -s -H "Authorization: Bearer $TOKEN" \
            "https://$KEY_VAULT_NAME.vault.azure.net/secrets/$SECRET_NAME?api-version=7.4" \
            | jq -r '.value') || true

        if [ -n "$SECRET_VALUE" ] && [ "$SECRET_VALUE" != "null" ]; then
            echo "[SUCCESS] Secret retrieved via Managed Identity"
            echo "Value (first 50 chars): ${SECRET_VALUE:0:50}..."
        else
            echo "[FAIL] Could not retrieve secret"
        fi
    else
        echo "[FAIL] Could not get access token"
    fi
}

# Method 3: Using Azure CLI with service principal
method_service_principal() {
    echo ""
    echo "--- Method 3: Service Principal (CI/CD) ---"

    if [ -z "${AZURE_CLIENT_ID:-}" ] || [ -z "${AZURE_CLIENT_SECRET:-}" ]; then
        echo "Service principal credentials not configured"
        echo "Required environment variables:"
        echo "  AZURE_CLIENT_ID"
        echo "  AZURE_CLIENT_SECRET"
        echo "  AZURE_TENANT_ID"
        return 1
    fi

    # Get token
    echo "Authenticating with service principal..."
    TOKEN=$(curl -s -X POST \
        "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$AZURE_CLIENT_ID" \
        -d "scope=https://vault.azure.net/.default" \
        -d "client_secret=$AZURE_CLIENT_SECRET" \
        -d "grant_type=client_credentials" \
        | jq -r '.access_token') || true

    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        echo "[SUCCESS] Authenticated"

        # Get secret
        SECRET_VALUE=$(curl -s -H "Authorization: Bearer $TOKEN" \
            "https://$KEY_VAULT_NAME.vault.azure.net/secrets/$SECRET_NAME?api-version=7.4" \
            | jq -r '.value') || true

        echo "[SUCCESS] Secret retrieved"
    else
        echo "[FAIL] Authentication failed"
    fi
}

# Main execution
case "${1:-all}" in
    user)
        method_user_login
        ;;
    mi|managed-identity)
        method_managed_identity
        ;;
    sp|service-principal)
        method_service_principal
        ;;
    all)
        method_user_login
        method_managed_identity
        method_service_principal
        ;;
    help|--help)
        echo "Usage: $0 [method] [keyvault-name] [secret-name]"
        echo ""
        echo "Methods:"
        echo "  user              - Using user login (development)"
        echo "  mi, managed-identity - Using VM managed identity"
        echo "  sp, service-principal - Using service principal"
        echo "  all               - Run all methods"
        echo ""
        echo "Examples:"
        echo "  $0                                        # Run all methods"
        echo "  $0 user my-kv my-secret                   # User login method"
        echo "  $0 mi                                     # Managed identity method"
        ;;
    *)
        echo "Unknown method: $1"
        echo "Use: $0 help"
        exit 1
        ;;
esac

echo ""
echo "=== Demo Complete ==="