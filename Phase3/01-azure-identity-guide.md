# Phase 3: Azure Identity & Access Management Guide

This guide covers Azure identity architecture, RBAC implementation, Managed Identities, and Privileged Identity Management for production environments.

---

## Table of Contents

1. [Azure Identity Architecture](#azure-identity-architecture)
2. [Lab 3.1: Azure Landing Zone Setup](#lab-31-azure-landing-zone-setup)
3. [Lab 3.2: RBAC Implementation](#lab-32-rbac-implementation)
4. [Lab 3.3: Managed Identities](#lab-33-managed-identities)
5. [Lab 3.4: Privileged Identity Management (PIM)](#lab-34-privileged-identity-management-pim)
6. [Professional Deliverables](#professional-deliverables)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Azure Identity Architecture

### Understanding Microsoft Entra ID

Microsoft Entra ID (formerly Azure AD) is the foundation of identity in Azure:

```bash
# Azure CLI login
az login

# Get current tenant information
az account tenant list --output table

# Show current user details
az ad signed-in-user show --output table
```

### Identity Hierarchy

```
Management Group (Root)
├── Management Group (Corp)
│   ├── Subscription (Production)
│   │   └── Resource Groups
│   └── Subscription (Non-Production)
│       └── Resource Groups
└── Management Group (Sandbox)
    └── Subscription (Individual)
```

### RBAC vs Azure AD Roles

| Scope | Use Case | Example Roles |
|-------|----------|---------------|
| **RBAC** | Azure resource access | Contributor, Reader, User Access Administrator |
| **Azure AD Roles** | Directory management | Global Administrator, User Administrator |

---

## Lab 3.1: Azure Landing Zone Setup

### Prerequisites

```bash
# Install latest Azure CLI
az version

# Verify login and subscriptions
az account show --output json | jq '{name, id, state}'
```

### Step 1: Create Management Group Structure

```bash
# Get the tenant root group ID
TENANT_ID=$(az account tenant list --query "[0].tenantId" -o tsv)

# Create management groups using Azure PowerShell or REST API
# (CLI has limited MGMT group support)

# Using REST API with access token
ACCESS_TOKEN=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)

# Create Corp management group
curl -X PUT "https://management.azure.com/providers/Microsoft.Management/managementGroups/corp?api-version=2021-04-01" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "corp", "properties": {"displayName": "Corp"}}'

# Create Production management group
curl -X PUT "https://management.azure.com/providers/Microsoft.Management/managementGroups/prod?api-version=2021-04-01" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "prod", "properties": {"displayName": "Production"}}'

# Create Sandbox management group
curl -X PUT "https://management.azure.com/providers/Microsoft.Management/managementGroups/sandbox?api-version=2021-04-01" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "sandbox", "properties": {"displayName": "Sandbox"}}'
```

### Step 2: Create Subscriptions

```bash
# Create a new subscription (requires EA or MCA)
az account subscription create \
  --name "DevOps-Learning-Production" \
  --offer-type "MS-AZR-0017P" \
  --parent-directory-object-id "$(az account management-group show --name corp --query id -o tsv)"

# List subscriptions
az account subscription list --output table
```

### Step 3: Create Resource Groups

```bash
# Set subscription context
az account set --subscription "DevOps-Learning-Production"

# Create resource groups with naming convention
# Format: rg-{environment}-{project}-{location}

# Networking resource group
az group create \
  --name "rg-devops-prod-networking-eastus" \
  --location "eastus" \
  --tags "Environment=Production" "Project=DevOps" "CostCenter=IT"

# Compute resource group
az group create \
  --name "rg-devops-prod-compute-eastus" \
  --location "eastus" \
  --tags "Environment=Production" "Project=DevOps" "CostCenter=IT"

# Security resource group
az group create \
  --name "rg-devops-prod-security-eastus" \
  --location "eastus" \
  --tags "Environment=Production" "Project=DevOps" "CostCenter=IT"

# Monitoring resource group
az group create \
  --name "rg-devops-prod-monitoring-eastus" \
  --location "eastus" \
  --tags "Environment=Production" "Project=DevOps" "CostCenter=IT"

# List resource groups
az group list --output table --query "[].{Name:name, Location:location, Tags:tags}"
```

### Step 4: Implement Naming Conventions

```bash
# Script to generate standardized resource names
generate_resource_name() {
    local prefix=$1      # rg (resource group)
    local env=$2         # prod, dev, stg
    local project=$3     # devops, app1
    local component=$4   # networking, compute, db
    local region=$5      # eastus, westus

    echo "${prefix}-${env}-${project}-${component}-${region}"
}

# Examples
echo "Resource Group: $(generate_resource_name "rg" "prod" "devops" "networking" "eastus")"
echo "VNet: $(generate_resource_name "vnet" "prod" "devops" "main" "eastus")"
echo "NSG: $(generate_resource_name "nsg" "prod" "devops" "web" "eastus")"
```

---

## Lab 3.2: RBAC Implementation

### Understanding RBAC

```bash
# View built-in roles
az role definition list --output table --query "[?type=='BuiltInRole']"

# Search for specific roles
az role definition list --query "[?contains(roleName,'Contributor')]" --output table

# Get role details
az role definition show --role-name "Virtual Machine Contributor" --output json | jq
```

### Step 1: Create Custom Role for DevOps

```json
{
  "Name": "DevOps Engineer",
  "Description": "Can manage compute and networking resources but not delete resource groups",
  "Actions": [
    "Microsoft.Compute/*/read",
    "Microsoft.Compute/virtualMachines/*",
    "Microsoft.Compute/disks/*",
    "Microsoft.Network/*/read",
    "Microsoft.Network/networkInterfaces/*",
    "Microsoft.Network/virtualNetworks/subnets/*",
    "Microsoft.Storage/*/read",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Authorization/*/read"
  ],
  "NotActions": [
    "Microsoft.Compute/virtualMachines/delete",
    "Microsoft.Network/networkSecurityGroups/delete",
    "Microsoft.Network/virtualNetworks/delete"
  ],
  "AssignableScopes": [
    "/subscriptions/YOUR-SUBSCRIPTION-ID"
  ]
}
```

```bash
# Create custom role from JSON file
az role definition create --role-definition azure-devops-role.json

# Verify role creation
az role definition list --output table --query "[?roleName=='DevOps Engineer']"
```

### Step 2: Assign Roles to Users/Groups

```bash
# Get object IDs
USER_ID=$(az ad user show --id "user@example.com" --query id -o tsv)
GROUP_ID=$(az ad group show --group "DevOps-Team" --query id -o tsv)

# Assign role to user at subscription scope
az role assignment create \
  --assignee "$USER_ID" \
  --role "DevOps Engineer" \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"

# Assign role to group
az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Reader" \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"

# List all assignments
az role assignment list --output table --assignee "$USER_ID"
```

### Step 3: Implement Least Privilege

```bash
# WRONG: Too permissive
az role assignment create --assignee "$USER_ID" --role "Contributor" --scope "/subscriptions/xxx"

# RIGHT: Specific permissions
az role assignment create \
  --assignee "$USER_ID" \
  --role "Virtual Machine Contributor" \
  --scope "/subscriptions/xxx/resourceGroups/rg-devops-prod-compute"

# Even better: Use a custom role with specific actions
```

### Step 4: Review and Audit Permissions

```bash
# List all role assignments in subscription
az role assignment list --output table --include-inherited

# List assignments for specific user
az role assignment list --assignee "$USER_ID" --output table

# Check who has access to a resource
az role assignment list \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID/resourceGroups/rg-devops-prod-compute" \
  --output table

# Export all assignments to CSV
az role assignment list --include-inherited \
  --query "[].{Principal:name, Role:roleDefinitionName, Scope:scope}" \
  --output csv > role-assignments.csv
```

### Step 5: Create Azure Policy for RBAC Compliance

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Authorization/roleAssignments"
        },
        {
          "field": "Microsoft.Authorization/roleAssignments.principalType",
          "equals": "User"
        }
      ]
    },
    "then": {
      "effect": "audit"
    }
  },
  "parameters": {}
}
```

```bash
# Create policy definition
az policy definition create \
  --name "audit-rbac-assignments" \
  --description "Audit RBAC assignments for compliance" \
  --mode "All" \
  --policy "policies/audit-rbac-assignments.json"

# Assign policy
az policy assignment create \
  --name "audit-rbac" \
  --policy "audit-rbac-assignments" \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
```

---

## Lab 3.3: Managed Identities

### Types of Managed Identities

| Type | Use Case | Lifecycle |
|------|----------|-----------|
| **System-assigned** | Single resource, simple scenarios | Deleted with resource |
| **User-assigned** | Multiple resources, shared identity | Independent lifecycle |

### Step 1: Enable System-Assigned Managed Identity

```bash
# Create VM with system-assigned managed identity
az vm create \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --image "Ubuntu2204" \
  --size "Standard_B2s" \
  --admin-username "azureuser" \
  --ssh-key-values "@~/.ssh/id_rsa.pub" \
  --assign-identity

# Enable on existing VM
az vm identity assign \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001"

# Get the identity principal ID
VM_ID=$(az vm show \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --query "identity.principalId" -o tsv)

echo "VM Principal ID: $VM_ID"
```

### Step 2: Create User-Assigned Managed Identity

```bash
# Create user-assigned managed identity
az identity create \
  --resource-group "rg-devops-prod-security-eastus" \
  --name "devops-app-identity" \
  --location "eastus" \
  --tags "Environment=Production" "Project=DevOps"

# Get identity resource ID
IDENTITY_ID=$(az identity show \
  --resource-group "rg-devops-prod-security-eastus" \
  --name "devops-app-identity" \
  --query "id" -o tsv)

# Assign to VM
az vm identity assign \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --identities "$IDENTITY_ID"

# Assign to App Service
az webapp identity assign \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-webapp-001" \
  --identities "$IDENTITY_ID"
```

### Step 3: Grant Access to Key Vault

```bash
# Get Key Vault ID
KEY_VAULT_ID=$(az keyvault show \
  --name "kv-devops-prod-secrets" \
  --query "id" -o tsv)

# Grant Key Vault Secrets Officer role to VM's managed identity
az role assignment create \
  --assignee "$VM_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KEY_VAULT_ID"

# Alternative: Grant at resource group level
az role assignment create \
  --assignee "$VM_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/YOUR-SUBSCRIPTION-ID/resourceGroups/rg-devops-prod-security"
```

### Step 4: Use Managed Identity in Applications

**C# (.NET) Example:**
```csharp
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var credential = new DefaultAzureCredential();
var client = new SecretClient(new Uri("https://kv-devops-prod-secrets.vault.azure.net/"), credential);

KeyVaultSecret secret = await client.GetSecretAsync("database-connection-string");
string connectionString = secret.Value;
```

**Python Example:**
```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url="https://kv-devops-prod-secrets.vault.azure.net/",
    credential=credential
)

secret = client.get_secret("database-connection-string")
print(secret.value)
```

**Bash Example (Azure CLI):**
```bash
# Get access token using managed identity
ACCESS_TOKEN=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?resource=https://vault.azure.net&api-version=2018-02-01' -H 'Metadata: true' | jq -r '.access_token')

# Access Key Vault
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://kv-devops-prod-secrets.vault.azure.net/secrets/database-connection-string?api-version=7.4"
```

### Step 5: Verify Managed Identity Configuration

```bash
# List all managed identities in subscription
az identity list --output table

# Check VM identity
az vm identity show \
  --resource-group "rg-devops-prod-compute-eastus" \
  --name "devops-vm-001" \
  --output json | jq

# List role assignments for a service principal
az ad sp show --id "$VM_ID" --query "appRoles"
```

---

## Lab 3.4: Privileged Identity Management (PIM)

### Step 1: Access PIM in Azure Portal

1. Go to **Microsoft Entra admin center** (https://entra.microsoft.com)
2. Navigate to **Identity Governance** → **Privileged Identity Management**
3. Select **Azure resources** (or Azure AD roles)

### Step 2: Activate Eligible Assignments

```bash
# Using PowerShell for PIM operations
# Install required module
Install-Module -Name AzureADPreview -AllowClobber

# Connect to Azure AD
Connect-AzureAD

# Get eligible role assignments
Get-AzureADMSPrivilegedRoleAssignment -ProviderId "azureResources" -ResourceId "YOUR-SUBSCRIPTION-ID"
```

### Step 3: Configure PIM Policies

**Portal Configuration Steps:**

1. Select a role (e.g., "User Access Administrator")
2. Go to **Settings**
3. Configure:
   - **Assignment type**: Eligible (not active)
   - **Maximum duration**: 8 hours
   - **Require justification**: Yes
   - **Require approval**: Yes (for sensitive roles)
   - **Activation maximum duration**: 4 hours

### Step 4: Create PIM Assignment via ARM Template

```json
{
  "$schema": "http://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.Authorization/roleEligibilityScheduleRequests",
      "apiVersion": "2022-04-01",
      "name": "eligible-assignment-001",
      "properties": {
        "principalId": "USER-OBJECT-ID",
        "roleDefinitionId": "/subscriptions/SUB-ID/providers/Microsoft.Authorization/roleDefinitions/PACKER-PATH",
        "requestType": "AdminAssign",
        "scheduleInfo": {
          "startDateTime": "2025-01-01T00:00:00Z",
          "expiration": {
            "type": "AfterDuration",
            "duration": "P1Y"
          }
        },
        "justification": "Temporary access for project work"
      }
    }
  ]
}
```

### Step 5: Audit PIM Activity

```bash
# Get PIM audit logs (PowerShell)
Get-AzureADMSPrivilegedRoleAssignment `
  -ProviderId "aadRoles" `
  -Filter "ResourceId eq 'TENANT-ID'" `
  | Select-Object PrincipalId, RoleDefinitionId, AssignmentState

# In portal: Identity Governance → Privileged Identity Management → Audit
```

---

## Professional Deliverables

Complete Phase 3 Identity section by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Management Groups | Hierarchical structure (Corp/Prod/Sandbox) | Azure Portal |
| Resource Groups | 4+ groups with naming convention | Azure |
| Custom Role | DevOps-specific role with least privilege | Azure RBAC |
| Role Assignments | Documented assignments with justification | `docs/rbac-assignments.md` |
| Managed Identity | User-assigned identity for application | Azure |
| PIM Configuration | Eligible assignments for sensitive roles | Azure AD PIM |
| Identity Architecture Doc | Diagram and explanation | `docs/identity-architecture.md` |

---

## Interview Reinforcement

### Q: What's the difference between system-assigned and user-assigned managed identities?

> "System-assigned MI is bound to a single Azure resource and deleted when that resource is deleted. User-assigned MI is a standalone resource that can be assigned to multiple resources and has an independent lifecycle. Microsoft now recommends user-assigned MIs for cross-resource scenarios because they're more flexible and reusable."

### Q: Why prefer Managed Identity over service principal secrets?

> "Managed Identities eliminate credential management entirely - no secrets to store, rotate, or worry about leaking. Azure handles automatic credential rotation. Applications authenticate using their Azure identity without any secrets in code or configuration. This significantly reduces the attack surface for credential theft."

### Q: How do you implement least privilege in Azure?

> "I start with minimum permissions (Reader) and only grant additional access when needed. I create custom roles with specific actions rather than using built-in broad roles. I use Azure Policy to enforce constraints. I regularly audit assignments and remove unused access. For sensitive operations, I use PIM for just-in-time elevation."

### Q: What's the principle of deny assignment in Azure RBAC?

> "Deny assignments explicitly prevent actions even if a role assignment would allow them. They're evaluated before role assignments and can block inheritance. They're useful for preventing access to sensitive resources even for users with broad contributor roles. Microsoft uses deny assignments internally to protect critical resources."

### Q: How do you audit and monitor identity activity?

> "I use Azure AD sign-in logs for authentication events, Azure Monitor for aggregation, and Microsoft Sentinel for security analytics. I configure alerts for unusual sign-in patterns, privilege escalations, and bulk permission changes. I review PIM activation history regularly and maintain an access review cycle."

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `az ad signed-in-user show` | Get current user info |
| `az role assignment create` | Grant access |
| `az role assignment list` | List all assignments |
| `az role definition list` | List available roles |
| `az identity create` | Create user-assigned identity |
| `az vm identity assign` | Add MI to VM |
| `az keyvault set-policy` | Grant Key Vault access |

---

## Next Steps

After completing Phase 3 Identity:
- [x] Understand Azure identity architecture
- [x] Implement management groups and resource groups
- [x] Configure RBAC with least privilege
- [x] Use Managed Identities for authentication
- [x] Set up PIM for sensitive roles

Proceed to **Azure Network Security** →