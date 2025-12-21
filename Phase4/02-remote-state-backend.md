# Phase 4: Remote State Backend Configuration

This guide covers configuring Azure Blob Storage as a Terraform remote backend with state locking for team collaboration.

---

## Table of Contents

1. [Why Remote State Matters](#why-remote-state-matters)
2. [Azure Blob Storage Backend](#azure-blob-storage-backend)
3. [Lab 4.3: Create Backend Infrastructure](#lab-43-create-backend-infrastructure)
4. [Lab 4.4: Configure Remote Backend](#lab-44-configure-remote-backend)
5. [Lab 4.5: State Locking](#lab-45-state-locking)
6. [State Management Best Practices](#state-management-best-practices)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Why Remote State Matters

### Local State Problems

| Problem | Impact |
|---------|--------|
| **Not Shareable** | Team members can't collaborate |
| **No Locking** | Concurrent runs corrupt state |
| **Single Point of Failure** | Lost laptop = lost infrastructure |
| **No Audit Trail** | Can't see who made changes |
| **Drift** | Local state may differ from reality |

### Remote State Benefits

| Benefit | Description |
|---------|-------------|
| **Collaboration** | All team members access same state |
| **State Locking** | Prevents concurrent modifications |
| **Security** | Encrypted at rest, RBAC controlled |
| **Durability** | Survives local machine failures |
| **Audit** | Track changes via storage logs |

---

## Azure Blob Storage Backend

### Backend Configuration

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "terraform-state"
    key                  = "dev/terraform.tfstate"
    use_oidc             = true  # Use Managed Identity
  }
}
```

### Backend Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `resource_group_name` | Yes | Resource group containing storage account |
| `storage_account_name` | Yes | Storage account name (must be unique) |
| `container_name` | Yes | Blob container for state files |
| `key` | Yes | Path within container for state file |
| `use_oidc` | No | Use OIDC/Managed Identity (recommended) |
| `subscription_id` | No | Subscription ID (defaults to provider) |
| `tenant_id` | No | Tenant ID (defaults to provider) |

---

## Lab 4.3: Create Backend Infrastructure

### Step 1: Create Backend with Bootstrap Script

First, we need to create the storage account using Azure CLI (since Terraform backend doesn't exist yet):

```bash
# Variables
RESOURCE_GROUP="rg-terraform-state"
LOCATION="eastus"
STORAGE_ACCOUNT_NAME="stterraformstate$(date +%s | tail -c 5)"  # Ensure uniqueness
CONTAINER_NAME="terraform-state"

# Create resource group for state
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags "Purpose=TerraformState"

# Create storage account (TLS v1.2 minimum, HTTPS required)
az storage account create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --sku "Standard_LRS" \
  --min-tls-version "TLS1_2" \
  --allow-blob-public-access false \
  --tags "Purpose=TerraformState"

# Enable blob versioning for state recovery
az storage account blob-service-properties update \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --enable-versioning true

# Create container
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode "login"

echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
```

### Step 2: Configure Access Control

```bash
# Get current user ID
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant Storage Blob Data Contributor to self (for managing state)
az role assignment create \
  --assignee "$USER_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/SUBSCRIPTION-ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"

# For CI/CD, assign to service connection identity
# az role assignment create \
#   --assignee "service-principal-id" \
#   --role "Storage Blob Data Contributor" \
#   --scope "/subscriptions/SUBSCRIPTION-ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"
```

### Step 3: Enable State Locking (Blob Lease)

State locking is automatic with Azure Blob Storage backend - the blob lease mechanism prevents concurrent modifications.

```bash
# View blob properties
az storage blob show \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name "dev/terraform.tfstate" \
  --query "properties"
```

---

## Lab 4.4: Configure Remote Backend

### Step 1: Create Backend Configuration

```hcl
# environments/dev/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"  # Update with your name
    container_name       = "terraform-state"
    key                  = "dev/terraform.tfstate"
    use_oidc             = true
  }
}
```

### Step 2: Create Provider with OIDC

```hcl
# environments/dev/main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
  use_oidc = true  # Use Managed Identity/OIDC
}
```

### Step 3: Initialize Backend

```bash
cd environments/dev

# Re-initialize with backend
terraform init -reconfigure

# Expected output:
# Initializing the backend...
# Successfully configured the backend "azurerm"! Terraform will now
# use these settings to store state in Azure Blob Storage.
#
# State path: dev/terraform.tfstate
```

### Step 4: Migrate Existing State (If Needed)

If you have local state to migrate:

```bash
# Copy local state to backend
terraform init -migrate-state

# Or manually
terraform state pull > terraform.tfstate.backup
terraform state push terraform.tfstate.backup
```

### Step 5: Verify Remote State

```bash
# List resources in remote state
terraform state list

# Pull state locally (temporarily)
terraform state pull > /tmp/remote-state.json
cat /tmp/remote-state.json | jq '.resources | length'
```

---

## Lab 4.5: State Locking

### Understanding State Locking

State locking prevents concurrent Terraform operations that could corrupt state.

```bash
# Try to apply while another run is in progress
terraform apply

# If locked, you'll see:
# Error: Error acquiring the state lock
#
# Lock Info:
#   ID:        abc123-def456
#   Operation: OperationTypePlan
#   Who:       user@machine
#   When:      2025-01-15 10:30:00Z
#   Path:      dev/terraform.tfstate
#
# Terraform will wait for the lock to be released automatically.
```

### Force Unlock (Emergency Only)

```bash
# Force release the lock (use with caution!)
terraform force-unlock LOCK_ID

# This should only be used when:
# - The previous run crashed and didn't release the lock
# - You're certain no other Terraform process is running
```

### Locking with Azure Blob Lease

The backend uses Azure Blob leases for locking:

```bash
# View lock status
az storage blob show \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name "dev/terraform.tfstate" \
  --query "properties.lease"

# Lease state: Available (unlocked) or Leased (locked)
```

---

## State Management Best Practices

### 1. Environment Separation

```hcl
# Use different keys for different environments
# backend.tf for dev
key = "dev/terraform.tfstate"

# backend.tf for prod
key = "prod/terraform.tfstate"
```

### 2. State File Security

```bash
# Enable these on the storage account:
# 1. HTTPS only
# 2. Enable blob versioning
# 3. Enable soft delete (7-90 days)
# 4. Enable firewall (limit to specific VNets)
# 5. Use private endpoints
```

### 3. Access Control

```hcl
# Principle of least privilege:
# - Developers: Storage Blob Data Contributor
# - CI/CD: Storage Blob Data Contributor
# - Read-only: Storage Blob Data Reader
```

### 4. State File Isolation

```
terraform-state/
├── dev/
│   └── terraform.tfstate
├── stg/
│   └── terraform.tfstate
└── prod/
    └── terraform.tfstate
```

### 5. Backend Configuration with Workspaces

```hcl
# Use workspace names in key
key = "${terraform.workspace}/terraform.tfstate"
```

---

## Terraform Cloud/Enterprise Alternative

For teams not using Azure Blob Storage:

```hcl
# backend.tf (Terraform Cloud)
terraform {
  cloud {
    organization = "my-organization"
    workspaces {
      name = "devops-learn-dev"
    }
  }
}
```

**Benefits:**
- Managed state storage
- Remote execution
- Policy as code
- Audit logs

---

## Professional Deliverables

Complete this section by creating:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Storage Account | Blob Storage for state | Azure |
| Container | terraform-state container | Azure |
| Backend Config | `backend.tf` | `environments/dev/` |
| RBAC Roles | Documented access | `docs/rbac.md` |
| State Diagram | Architecture documentation | `docs/state-architecture.png` |

---

## Interview Reinforcement

### Q: Why is remote state with locking critical for teams?

> "Remote state enables collaboration - all team members work from the same state file. State locking prevents race conditions where two people run Terraform simultaneously, which would corrupt the state file. Without locking, you could have one run overwrite another's changes, leading to infrastructure drift or resource deletion."

### Q: How does Azure Blob Storage provide state locking?

> "Azure Blob Storage supports blob leases - a mechanism for exclusive write access. When Terraform starts an operation, it acquires a lease on the state blob. Other Terraform processes attempting to modify state see the lease and wait. When the operation completes, the lease is released. If Terraform crashes, the lease eventually expires, allowing other operations to proceed."

### Q: What's the difference between local and remote state backends?

> "Local state is a file on disk - simple but not shareable and no locking. Remote backends store state in a shared location (Azure Blob, S3, etc.) with API-based access. Remote backends provide state locking, encryption, access control, and durability. For any team or production environment, remote state is mandatory."

### Q: How do you recover from a corrupted state file?

> "First, use `terraform state list` to inspect what's in state. If corrupted, check if you have a backup (blob versioning is enabled!). If not, use `terraform import` to rebuild state for existing resources. For critical situations, Azure blob versioning allows restoring a previous version. Prevention is key: enable versioning and use remote backend."

### Q: Can multiple Terraform configurations share state?

> "Not directly - each configuration should have its own state. For shared resources, use data sources to read state outputs or use Terraform modules to share configurations. Avoid tight coupling between state files, which creates fragile deployments. Consider using remote state data sources for cross-configuration references."

---

## Quick Reference

```bash
# Initialize with backend
terraform init -reconfigure

# Migrate local to remote
terraform init -migrate-state

# Check state location
terraform state pull | jq '.backend.config'

# Force unlock (emergency)
terraform force-unlock LOCK_ID

# List workspaces
terraform workspace list

# Select workspace
terraform workspace select dev
```

---

## Next Steps

After completing this section:
- [x] Create Blob Storage backend
- [x] Configure remote backend
- [x] Initialize with OIDC authentication
- [x] Understand state locking
- [x] Apply best practices

Proceed to **Lab 4.6: Azure Resources with Terraform** →