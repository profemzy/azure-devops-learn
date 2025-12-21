# Phase 3: Azure Key Vault & Secrets Management Guide

This guide covers Azure Key Vault configuration, RBAC-based access, secrets management patterns, and integration with Managed Identities.

---

## Table of Contents

1. [Key Vault Fundamentals](#key-vault-fundamentals)
2. [Lab 3.9: Key Vault Creation & Configuration](#lab-39-key-vault-creation--configuration)
3. [Lab 3.10: RBAC Access Policies](#lab-310-rbac-access-policies)
4. [Lab 3.11: Secrets Management](#lab-311-secrets-management)
5. [Lab 3.12: Key Vault Integration Patterns](#lab-312-key-vault-integration-patterns)
6. [Professional Deliverables](#professional-deliverables)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Key Vault Fundamentals

### Key Vault Capabilities

| Capability | Description |
|------------|-------------|
| **Secrets** | Passwords, connection strings, API keys |
| **Keys** | Encryption keys, signing keys |
| **Certificates** | SSL/TLS certificates with auto-renewal |
| **Managed HSM** | FIPS 140-2 Level 2/3 compliant key management |

### Key Vault Pricing Tiers

| Tier | Features | Use Case |
|------|----------|----------|
| **Standard** | Software-backed keys, secrets, certificates | Development, non-sensitive |
| **Premium** | Hardware Security Module (HSM) protected keys | Production, regulated workloads |

---

## Lab 3.9: Key Vault Creation & Configuration

### Step 1: Create Key Vault

```bash
# Variables
RESOURCE_GROUP="rg-devops-prod-security-eastus"
LOCATION="eastus"
KV_NAME="kv-devops-prod-secrets"

# Create Key Vault (Standard tier)
az keyvault create \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "standard" \
  --tags "Environment=Production" "Project=DevOps"

# Create Key Vault (Premium tier for HSM)
az keyvault create \
  --name "kv-devops-prod-hsm" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "premium" \
  --tags "Environment=Production" "Project=DevOps"

# Verify creation
az keyvault show \
  --name "$KV_NAME" \
  --query "{Name:name, Location:location, SKU:sku.name, URIs:properties.vaultUri}"
```

### Step 2: Configure Key Vault Properties

```bash
# Enable soft-delete (critical for production)
az keyvault update \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-soft-delete true

# Enable purge protection (prevents accidental deletion)
az keyvault update \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-purge-protection true

# Set retention days (7-90 days)
az keyvault update \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --retention-days 30

# Disable public network access (after Private Endpoint setup)
az keyvault update \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --public-network-access "Disabled"

# Verify configuration
az keyvault show \
  --name "$KV_NAME" \
  --query "{SoftDelete:properties.enableSoftDelete, PurgeProtection:properties.enablePurgeProtection, PublicAccess:properties.publicNetworkAccess}"
```

### Step 3: Configure Network Access

```bash
# Allow access from specific VNet (while public access enabled for setup)
az keyvault network-rule add \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --subnet "snet-app" \
  --vnet-name "vnet-devops-prod-eastus"

# Deny default network access (forces Private Endpoint)
az keyvault network-rule add \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --ip-address "0.0.0.0/0" \
  --action "Deny"

# Alternatively, bypass from specific services
az keyvault network-rule add \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --bypass "AzureServices"

# List network rules
az keyvault network-rule list \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

### Step 4: Set Up Diagnostic Settings

```bash
# Create Log Analytics workspace
WORKSPACE_NAME="law-devops-prod-eastus"
az monitor log-analytics workspace create \
  --resource-group "rg-devops-prod-monitoring-eastus" \
  --name "$WORKSPACE_NAME" \
  --location "eastus"

WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --name "$WORKSPACE_NAME" \
  --resource-group "rg-devops-prod-monitoring-eastus" \
  --query "id" -o tsv)

# Create diagnostic setting for Key Vault
az monitor diagnostic-settings create \
  --name "kv-diag-devops-prod" \
  --resource "$KV_NAME" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category": "AuditEvent", "enabled": true}, {"category": "AzurePolicyEvaluationDetails", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]'
```

---

## Lab 3.10: RBAC Access Policies

### Understanding Key Vault Access Models

| Model | Description | Recommendation |
|-------|-------------|----------------|
| **Access Policies** | Legacy model with individual permissions | Migrate to RBAC |
| **RBAC** | Azure role-based access control | Preferred for new deployments |

### Step 1: Check Current Access Model

```bash
# Check if using RBAC model
az keyvault show \
  --name "$KV_NAME" \
  --query "properties.enableRbacAuthorization"
```

### Step 2: Grant Key Vault Roles

```bash
# Get object IDs
VM_ID=$(az vm show \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --query "identity.principalId" -o tsv)

USER_ID=$(az ad user show --id "devops@example.com" --query id -o tsv)

IDENTITY_ID=$(az identity show \
  --resource-group "rg-devops-prod-security-eastus" \
  --name "devops-app-identity" \
  --query "id" -o tsv)

# Key Vault Roles
# - Key Vault Reader: Read metadata
# - Key Vault Secrets Officer: Manage secrets
# - Key Vault Certificates Officer: Manage certs
# - Key Vault Crypto Officer: Manage keys
# - Key Vault Crypto User: Use keys for operations
# - Key Vault Secrets User: Read secrets

# Grant Secrets User role to VM (for reading secrets)
az role assignment create \
  --assignee "$VM_ID" \
  --role "Key Vault Secrets User" \
  --scope "$KV_NAME"

# Grant Secrets Officer role to application identity (for managing secrets)
az role assignment create \
  --assignee "$IDENTITY_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_NAME"

# Grant Reader role to DevOps team member
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Reader" \
  --scope "$KV_NAME"

# List all role assignments for Key Vault
az role assignment list \
  --scope "$KV_NAME" \
  --output table
```

### Step 3: Remove Legacy Access Policies

```bash
# List existing access policies
az keyvault policy show-all \
  --name "$KV_NAME" \
  --output table

# Remove access policy (if converting from access policies to RBAC)
az keyvault delete-policy \
  --name "$KV_NAME" \
  --object-id "OLD-OBJECT-ID"
```

---

## Lab 3.11: Secrets Management

### Step 1: Store Secrets

```bash
# Store a simple secret
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "database-connection-string" \
  --value "Server=mydb.database.windows.net;Database=myapp;User Id=user;Password=secret123"

# Store secret from file
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "api-key" \
  --file "api-key.txt"

# Store secret with expiration
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "temporary-token" \
  --value "abc123" \
  --expires "2025-12-31T23:59:59Z" \
  --not-before "2025-01-01T00:00:00Z"

# Store connection string for later use
CONN_STR="Server=sql-devops-prod.database.windows.net;Database=appdb;User Id=appuser;Password=StrongPass123!"
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "app-db-connection" \
  --value "$CONN_STR"

# List secrets
az keyvault secret list \
  --vault-name "$KV_NAME" \
  --output table

# Show secret metadata
az keyvault secret show \
  --vault-name "$KV_NAME" \
  --name "database-connection-string" \
  --query "{Name:name, Created:attributes.created, Expires:attributes.expires, ContentType:contentType}"
```

### Step 2: Store Certificates

```bash
# Create self-signed certificate
az keyvault certificate create \
  --vault-name "$KV_NAME" \
  --name "devops-selfsigned" \
  --policy "$(cat <<EOF
{
  "x509CertificateProperties": {
    "subject": "CN=devops.example.com",
    "validityInMonths": 12
  },
  "keyProperties": {
    "keyType": "RSA",
    "keySize": 2048,
    "reuseKey": true
  },
  "lifetimeActions": [{
    "action": "EmailContacts",
    "trigger": {"daysBeforeExpiry": 30}
  }]
}
EOF
)"

# Import certificate from PFX file
az keyvault certificate import \
  --vault-name "$KV_NAME" \
  --name "ssl-certificate" \
  --file "certificate.pfx" \
  --password "certificate-password"

# List certificates
az keyvault certificate list \
  --vault-name "$KV_NAME" \
  --output table
```

### Step 3: Store Encryption Keys

```bash
# Create RSA key
az keyvault key create \
  --vault-name "$KV_NAME" \
  --name "encryption-key-rsa" \
  --kty "RSA" \
  --size 2048 \
  --ops "encrypt" "decrypt" "wrapKey" "unwrapKey"

# Create EC key for signing
az keyvault key create \
  --vault-name "$KV_NAME" \
  --name "signing-key-ec" \
  --kty "EC" \
  --curve-name "P-256" \
  --ops "sign" "verify"

# Import key from HSM backup
az keyvault key import \
  --vault-name "$KV_NAME" \
  --name "imported-key" \
  --pem-file "key-backup.pem" \
  --pem-password "file-password"

# List keys
az keyvault key list \
  --vault-name "$KV_NAME" \
  --output table
```

### Step 4: Retrieve Secrets Securely

```bash
# Get secret value (output masked in some cases)
az keyvault secret show \
  --vault-name "$KV_NAME" \
  --name "database-connection-string" \
  --query "secret.properties.attributes"

# Download secret to file (securely)
az keyvault secret download \
  --vault-name "$KV_NAME" \
  --name "database-connection-string" \
  --file "connection-string.txt"

# Get secret as environment variable (one-liner)
export DB_CONN=$(az keyvault secret show \
  --vault-name "$KV_NAME" \
  --name "database-connection-string" \
  --query "secret.value" -o tsl)

echo "Connection string loaded securely"
```

---

## Lab 3.12: Key Vault Integration Patterns

### Pattern 1: VM with Managed Identity

```bash
# Grant VM access to Key Vault
VM_ID=$(az vm show \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --query "identity.principalId" -o tsv)

az role assignment create \
  --assignee "$VM_ID" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-security-eastus/providers/Microsoft.KeyVault/vaults/kv-devops-prod-secrets"

# SSH to VM and retrieve secret
ssh azureuser@vm-ip << 'EOF'
# Using Azure CLI with managed identity
az login --identity
az keyvault secret show \
  --vault-name "kv-devops-prod-secrets" \
  --name "database-connection-string" \
  --query "secret.value"
EOF
```

### Pattern 2: App Service with Key Vault References

```bash
# Get user-assigned identity ID
IDENTITY_ID=$(az identity show \
  --resource-group "rg-devops-prod-security-eastus" \
  --name "devops-app-identity" \
  --query "id" -o tsv)

# Assign identity to App Service
az webapp identity assign \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-webapp-001" \
  --identities "$IDENTITY_ID"

# Grant access
az role assignment create \
  --assignee "$IDENTITY_ID" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-security-eastus/providers/Microsoft.KeyVault/vaults/kv-devops-prod-secrets"

# Configure Key Vault reference in App Settings
az webapp config appsettings set \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-webapp-001" \
  --settings "DatabaseConnection=@Microsoft.KeyVault(SecretUri=https://kv-devops-prod-secrets.vault.azure.net/secrets/database-connection-string/)"
```

### Pattern 3: Terraform with Key Vault

```hcl
# provider.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# main.tf - Use Key Vault for secrets
data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_mssql_database" "example" {
  name      = "example-db"
  server_id = azurerm_mssql_server.example.id
  # Use secret from Key Vault
  extension = {
    external_admin_enabled = false
  }
}

# For connection strings
locals {
  connection_string = "Server=${azurerm_mssql_server.example.fully_qualified_domain_name};Database=${azurerm_mssql_database.example.name};User Id=${var.db_admin_user};Password=${data.azurerm_key_vault_secret.db_password.value};"
}
```

### Pattern 4: GitHub Actions with Key Vault

```yaml
name: Deploy with Key Vault

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure login with OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Get secret from Key Vault
        uses: azure/get-keyvault-secrets@v1
        with:
          keyvault: "kv-devops-prod-secrets"
          secrets: "db-password,api-key"
        id: kv-secrets

      - name: Use secret in deployment
        run: |
          echo "Database password: ${{ secrets.db-password }}"
          echo "API Key: ${{ secrets.api-key }}"

      - name: Azure logout
        uses: azure/logout@v1
        run: |
          az account clear
```

### Pattern 5: Kubernetes with Azure Key Vault (Secrets Store CSI Driver)

```yaml
# Install Secrets Store CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system

# Create Azure Key Vault SecretProviderClass
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-secretprovider
  namespace: default
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    keyvaultName: "kv-devops-prod-secrets"
    cloudName: ""
    objects: |
      array:
        - |
          objectName: database-connection-string
          objectType: secret
    tenantId: "YOUR-TENANT-ID"

# Pod referencing the secret
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: default
spec:
  containers:
    - name: app
      image: myapp:latest
      volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kv-secretprovider"
```

---

## Professional Deliverables

Complete Phase 3 Key Vault section by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Key Vault | Configured with RBAC, soft-delete, purge protection | Azure |
| Secrets | Database, API keys, connection strings | Key Vault |
| Diagnostic Settings | Logs and metrics to Log Analytics | Azure |
| RBAC Roles | Documented role assignments | `docs/keyvault-rbac.md` |
| Integration Script | Automate secret retrieval | `scripts/03-keyvault-access.sh` |
| Architecture Doc | Secrets management design | `docs/secrets-architecture.md` |

---

## Interview Reinforcement

### Q: Why use Key Vault over environment variables or config files?

> "Key Vault provides centralized secret management with encryption at rest, automatic rotation, fine-grained access control via RBAC, audit logging, and soft-delete for recovery. Secrets never appear in code, logs, or environment variables. Managed Identities eliminate credentials entirely. This significantly reduces the attack surface for credential theft."

### Q: What's the difference between Access Policies and RBAC model?

> "Access Policies are the legacy model with individual permissions assigned to security principals. They're grant-based and can become complex with many policies. RBAC uses Azure's role-based model with predefined roles like 'Key Vault Secrets Officer', supports Azure Policy for governance, and is the recommended model for new deployments."

### Q: How do you handle Key Vault in disaster recovery?

> "I enable geo-replication by creating Key Vaults in paired regions. I use the same name in both regions. I configure Private Endpoints in each region. I set up Azure Site Recovery or manual failover procedures. I test recovery regularly. For critical workloads, I maintain secondary Key Vaults with synchronized secrets."

### Q: How do you rotate secrets automatically?

> "I use Key Vault's integration with Azure AD for Managed Identity rotation (automatic). For application secrets, I use Azure Functions with Event Grid to handle rotation events. I configure certificates with auto-renewal. I implement health checks that validate secrets are working before old ones expire."

### Q: What happens if you delete a Key Vault with soft-delete enabled?

> "The Key Vault enters a soft-deleted state and is retained for the configured period (7-90 days). During this time, the vault cannot be accessed but can be recovered. Purge protection prevents permanent deletion even during the retention period. After retention, the vault is permanently deleted."

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `az keyvault create` | Create Key Vault |
| `az keyvault secret set` | Store secret |
| `az keyvault secret show` | View secret metadata |
| `az keyvault secret download` | Download secret |
| `az keyvault key create` | Create encryption key |
| `az keyvault certificate create` | Create certificate |
| `az role assignment create` | Grant RBAC access |

---

## Next Steps

After completing Phase 3 Key Vault:
- [x] Create and configure Key Vault
- [x] Implement RBAC access control
- [x] Store secrets, keys, and certificates
- [x] Integrate with Managed Identities
- [x] Set up monitoring and diagnostics

Proceed to **Azure Monitoring & Observability** →