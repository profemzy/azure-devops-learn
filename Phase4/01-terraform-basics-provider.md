# Phase 4: Terraform Basics & Provider Configuration

This guide covers Terraform fundamentals, AzureRM provider setup, and Managed Identity authentication for production deployments.

---

## Table of Contents

1. [Why Infrastructure as Code](#why-infrastructure-as-code)
2. [Terraform Installation](#terraform-installation)
3. [Provider Configuration](#provider-configuration)
4. [Authentication with Managed Identity](#authentication-with-managed-identity)
5. [Lab 4.1: First Terraform Configuration](#lab-41-first-terraform-configuration)
6. [Lab 4.2: Azure AD Integration](#lab-42-azure-ad-integration)
7. [Professional Deliverables](#professional-deliverables)
8. [Interview Reinforcement](#interview-reinforcement)

---

## Why Infrastructure as Code

### Problems IaC Solves

| Problem | Manual Approach | IaC Approach |
|---------|-----------------|--------------|
| **Reproducibility** | Hard to recreate exact same environment | Code always produces same result |
| **Version Control** | No audit trail of changes | Full history in Git |
| **Documentation** | Outdated wiki, no single source of truth | Code is documentation |
| **Collaboration** | Manual handoffs, errors | PR reviews, code comments |
| **Disaster Recovery** | Hours to rebuild | Minutes with `terraform apply` |
| **Compliance** | Manual attestation | Automated policy checks |

### Terraform vs Other Tools

| Tool | Strengths | Best For |
|------|-----------|----------|
| **Terraform** | Multi-cloud, declarative, large ecosystem | Cloud-agnostic teams |
| **ARM/Bicep** | Native Azure, tight integration | Azure-only teams |
| **Pulumi** | General-purpose languages (Python, TypeScript) | Developer-first teams |
| **Ansible** | Procedural, configuration management | Mutable infrastructure |

---

## Terraform Installation

### Verify Installation

```bash
# Check Terraform version
terraform version

# Expected output: Terraform v1.x.x

# Check Azure CLI
az version

# Expected output: azure-cli x.x.x
```

### Installation (if needed)

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Windows (winget):**
```powershell
winget install HashiCorp.Terraform
```

**Linux:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

---

## Provider Configuration

### Understanding Providers

Providers are plugins that enable interaction with cloud services. The AzureRM provider manages Azure resources.

### Provider Version History

| Version | Release | Key Changes |
|---------|---------|-------------|
| v4.x | 2024+ | Current, requires Terraform 1.0+ |
| v3.x | 2022-2024 | Major refactor, deprecated features removed |
| v2.x | 2020-2022 | Legacy, deprecated fields |

### Provider Block Structure

```hcl
# provider.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"  # Latest stable
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {
    # Provider features configuration
  }

  # Authentication handled via environment or Managed Identity
  # No explicit credentials needed when using MI
}

provider "azuread" {
  # Uses same authentication as azurerm provider
}
```

### Provider Features

```hcl
provider "azurerm" {
  features {
    key_vault {
      # Recover deleted key vaults
      soft_delete_enabled = true
      purge_protection_enabled = true
    }

    resource_group {
      # Prevent deletion if resources exist
      prevent_deletion_if_contains_resources = true
    }

    virtual_machine {
      # Graceful shutdown before deletion
      graceful_shutdown = true
    }

    container_registry {
      # Purge deleted registries
      purge_soft_delete_on_destroy = true
    }
  }
}
```

### Version Constraints Explained

| Constraint | Meaning |
|------------|---------|
| `">= 1.0.0"` | Must be 1.0.0 or higher |
| `"~> 4.0"` | Must be 4.0.x (4.1, 4.2, etc.) |
| `">= 1.0.0, < 2.0.0"` | Any version in 1.x range |
| `">= 4.0"` | Any version 4.0 or higher (not recommended) |

---

## Authentication with Managed Identity

### Why Managed Identity?

| Authentication Method | Pros | Cons |
|----------------------|------|------|
| **Managed Identity** | No secrets, automatic rotation, works on Azure | Must run on Azure resource |
| **Service Principal** | Works anywhere, flexible | Secrets to manage, rotation needed |
| **Azure CLI** | Easy local development | Interactive, not for automation |

### Setting Up Authentication

**Option 1: System-assigned Managed Identity on Azure VM**

```bash
# Create VM with system-assigned MI
az vm create \
  --resource-group "rg-devops-terraform" \
  --name "terraform-vm" \
  --image "Ubuntu2204" \
  --size "Standard_B2s" \
  --admin-username "azureuser" \
  --ssh-key-values "@~/.ssh/id_rsa.pub" \
  --assign-identity

# Grant contributor access to subscription or resource group
VM_PRINCIPAL_ID=$(az vm show \
  --resource-group "rg-devops-terraform" \
  --name "terraform-vm" \
  --query "identity.principalId" -o tsv)

az role assignment create \
  --assignee "$VM_PRINCIPAL_ID" \
  --role "Contributor" \
  --scope "/subscriptions/SUBSCRIPTION-ID/resourceGroups/rg-devops-terraform"
```

**Option 2: User-assigned Managed Identity (Recommended)**

```bash
# Create user-assigned managed identity
az identity create \
  --resource-group "rg-devops-terraform" \
  --name "terraform-identity" \
  --location "eastus"

IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group "rg-devops-terraform" \
  --name "terraform-identity" \
  --query "clientId" -o tsv)

IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group "rg-devops-terraform" \
  --name "terraform-identity" \
  --query "principalId" -o tsv)

# Assign role to the identity
az role assignment create \
  --assignee "$IDENTITY_PRINCIPAL_ID" \
  --role "Contributor" \
  --scope "/subscriptions/SUBSCRIPTION-ID/resourceGroups/rg-devops-terraform"

echo "Client ID for MI: $IDENTITY_CLIENT_ID"
```

**Option 3: Azure CLI (Development Only)**

```bash
# Interactive login
az login

# Or service principal
az login --service-principal \
  --username "APP-ID" \
  --password "SECRET" \
  --tenant "TENANT-ID"
```

### Environment Variables for Authentication

```bash
# Set for Managed Identity (on Azure VM)
export AZURE_USE_MSI=true
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# For Azure CLI (development)
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Verify authentication
az account show --query "{SubscriptionId:id, TenantId:tenantId}"
```

---

## Lab 4.1: First Terraform Configuration

### Step 1: Create Project Structure

```bash
# Create project directory
mkdir -p ~/terraform-learning
cd ~/terraform-learning

# Create project structure
mkdir -p environments/dev environments/prod modules

# Initialize git
git init
cat > .gitignore << 'EOF'
*.tfstate
*.tfstate.*
*.tfvars
*.tfplan
.terraform/
EOF
```

### Step 2: Create Provider Configuration

```hcl
# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}
```

### Step 3: Create Variables File

```hcl
# terraform.tfvars
subscription_id = "your-subscription-id"

# Location for resources
location = "eastus"

# Environment prefix
environment = "dev"

# Tags
tags = {
  Project     = "DevOps-Learning"
  Environment = "dev"
  ManagedBy   = "Terraform"
}
```

### Step 4: Create First Resource

```hcl
# resources.tf
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.environment}-terraform-eastus"
  location = var.location
  tags     = var.tags
}

# Log Analytics Workspace (from Phase 3)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-terraform"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}
```

### Step 5: Initialize and Apply

```bash
# Initialize Terraform (download providers)
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Create execution plan
terraform plan -out=tfplan

# Review plan (always review before applying!)
terraform show tfplan

# Apply configuration
terraform apply tfplan
```

**Expected Output:**
```
Apply complete! Resources: 2 created.
```

### Step 6: Inspect State

```bash
# Show state
terraform state list

# Show specific resource
terraform state show azurerm_resource_group.main

# View state file (JSON)
cat terraform.tfstate
```

### Step 7: Make Changes

```hcl
# Update tags
variable "tags" {
  type = map(string)
  default = {
    Project     = "DevOps-Learning"
    Environment = "dev"
    ManagedBy   = "Terraform"
    UpdatedBy   = "terraform"  # Added
  }
}

# Plan the change
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

### Step 8: Destroy Resources

```bash
# Destroy everything
terraform destroy

# Or with auto-approve (careful!)
terraform destroy -auto-approve
```

---

## Lab 4.2: Azure AD Integration

### Create Azure AD Groups

```hcl
# azuread.tf
# Create Azure AD group for DevOps team
resource "azuread_group" "devops" {
  display_name     = "DevOps-Team"
  description      = "Azure DevOps Engineers"
  mail_enabled     = false
  security_enabled = true
}

# Create group for Kubernetes admins
resource "azuread_group" "aks_admins" {
  display_name     = "AKS-Admins"
  description      = "Azure Kubernetes Service Administrators"
  mail_enabled     = false
  security_enabled = true
}

# Add members to group
resource "azuread_group_member" "add_member" {
  group_object_id  = azuread_group.devops.object_id
  member_object_id = "user-object-id-to-add"
}
```

### Create Service Principal

```hcl
# service-principal.tf
# Create app registration
resource "azuread_application" "example" {
  display_name = "terraform-app-${var.environment}"
}

# Create service principal
resource "azuread_service_principal" "example" {
  application_id = azuread_application.example.application_id
}

# Create client secret (stored in Key Vault recommended)
resource "azuread_service_principal_password" "example" {
  service_principal_id = azuread_service_principal.example.object_id
  rotates_on           = timeadd(timestamp(), "8760h")  # 1 year
}
```

### Use Azure AD Provider with Managed Identity

```hcl
# azuread-auth.tf
# Configure azuread provider to use MI
provider "azuread" {
  # Uses same environment as azurerm
  # No additional config needed when using MI
}
```

---

## Terraform Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform init` | Initialize providers and modules |
| `terraform fmt` | Format code style |
| `terraform validate` | Validate syntax |
| `terraform plan` | Create execution plan |
| `terraform apply` | Apply changes |
| `terraform destroy` | Destroy all resources |
| `terraform state list` | List resources in state |
| `terraform state show` | Show resource details |
| `terraform refresh` | Sync state with real infrastructure |
| `terraform output` | Print output values |
| `terraform import` | Import existing resources |
| `terraform taint` | Mark resource for recreation |
| `terraform untaint` | Remove taint mark |
| `terraform workspace` | Manage workspaces |

---

## Professional Deliverables

Complete Phase 4 by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Provider Config | `provider.tf` with AzureRM v4.x | `environments/dev/` |
| Remote Backend | Blob Storage backend configuration | `backend.tf` |
| Resource Group | Created via Terraform | Azure |
| Azure AD Groups | DevOps team groups | Azure AD |
| Variables | `terraform.tfvars` | `environments/dev/` |
| Outputs | Resource outputs for other modules | `outputs.tf` |
| Documentation | Architecture runbook | `docs/` |

---

## Interview Reinforcement

### Q: Why use Managed Identity over service principals for Terraform?

> "Managed Identity eliminates credential management entirely. No client secrets to store, rotate, or accidentally expose. Authentication is automatic via Azure's infrastructure. It's the recommended approach for any Terraform running on Azure - whether on VMs, App Services, or Azure DevOps pipelines with OIDC."

### Q: How does Terraform handle provider versioning?

> "Terraform uses semantic versioning. The version constraint in `required_providers` controls which versions are acceptable. The `~> 4.0` constraint means 'any 4.x version but not 5.0'. During `terraform init`, it downloads the latest matching version and pins it. This ensures consistency across team members."

### Q: What happens if you don't specify provider version?

> "Without version constraints, Terraform will use the latest available version of each provider when you run `init`. This can cause issues when team members have different versions with potentially different behavior. Always specify version constraints for production configurations."

### Q: How do you manage Terraform state securely?

> "Never commit `terraform.tfstate` to version control. Use Azure Blob Storage as a remote backend with state locking via blob leases. Enable encryption at rest and access control. Consider using Terraform Cloud or Enterprise for team collaboration with audit trails."

### Q: What's the difference between `terraform plan` and `terraform apply`?

> "`terraform plan` creates an execution plan showing what changes will be made without making them. It's safe to share and review. `terraform apply` executes the plan and makes actual changes to infrastructure. Always review the plan output before applying."

---

## Quick Reference

```bash
# Initialize new project
terraform init

# Format all files
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan with variables
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply with auto-approve (dangerous!)
terraform apply -auto-approve

# Destroy all
terraform destroy
```

---

## Next Steps

After completing Lab 4.1 and 4.2:
- [x] Install and verify Terraform
- [x] Configure AzureRM provider v4.x
- [x] Set up Managed Identity authentication
- [x] Create first resources (RG, Log Analytics)
- [x] Integrate with Azure AD

Proceed to **Lab 4.3: Remote State Backend** →