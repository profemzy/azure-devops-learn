# Phase 4: Key Vault & Monitoring Integration

This guide covers Azure Key Vault integration, Managed Identities, and monitoring with Terraform for production-ready infrastructure.

---

## Table of Contents

1. [Key Vault Integration](#key-vault-integration)
2. [Lab 4.10: Create Key Vault with Terraform](#lab-410-create-key-vault-with-terraform)
3. [Lab 4.11: Store and Retrieve Secrets](#lab-411-store-and-retrieve-secrets)
4. [Lab 4.12: Managed Identities](#lab-412-managed-identities)
5. [Lab 4.13: Monitoring Configuration](#lab-413-monitoring-configuration)
6. [Lab 4.14: Azure Policy as Code](#lab-414-azure-policy-as-code)
7. [Complete Module Example](#complete-module-example)
8. [Interview Reinforcement](#interview-reinforcement)

---

## Key Vault Integration

### Why Key Vault with Terraform

| Aspect | Without Key Vault | With Key Vault |
|--------|-------------------|----------------|
| **Secrets** | Plain text in tfvars | Encrypted in Key Vault |
| **Rotation** | Manual | Automatic via MI |
| **Access Control** | Not centralized | RBAC controlled |
| **Audit** | No visibility | Full audit logs |
| **Recovery** | No soft delete | Soft delete enabled |

### Key Vault Provider

```hcl
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
}

provider "azurerm" {
  features {
    key_vault {
      # Enable soft delete (7 days by default)
      soft_delete_enabled = true
      # Prevent purge without protection
      purge_protection_enabled = true
    }
  }
  use_oidc = true
}
```

---

## Lab 4.10: Create Key Vault with Terraform

### Basic Key Vault

```hcl
# resources/keyvault.tf
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.environment}-${var.project}-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"  # or "premium" for HSM

  # Security settings
  enable_rbac_authorization = true  # Use RBAC, not access policies

  # Network access
  public_network_access_enabled = false  # Force Private Endpoints

  # Soft delete and purge protection
  soft_delete_retention_days  = 30
  purge_protection_enabled    = true

  tags = var.tags
}
```

### Key Vault Access Policy (Legacy - Not Recommended)

```hcl
# Only use if RBAC is not enabled
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Update", "Create", "Import",
    "Delete", "Recover", "Backup", "Restore"
  ]
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover",
    "Backup", "Restore"
  ]
  certificate_permissions = [
    "Get", "List", "Update", "Create", "Import",
    "Delete", "ManageContacts", "ManageIssuers",
    "GetIssuers", "ListIssuers", "SetIssuers"
  ]
}
```

### Key Vault with Private Endpoint

```hcl
# resources/keyvault-pe.tf
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.environment}-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.app.id

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                   = "kv-dns"
    private_dns_zone_ids   = [azurerm_private_dns_zone.keyvault.id]
  }
}
```

---

## Lab 4.11: Store and Retrieve Secrets

### Store Secrets

```hcl
# resources/secrets.tf
# Database connection string
resource "azurerm_key_vault_secret" "db_connection" {
  name         = "db-connection-string"
  value        = "Server=sql-${var.environment}.database.windows.net;Database=appdb;User Id=${var.db_admin_user};Password=${var.db_password};"
  key_vault_id = azurerm_key_vault.main.id

  # Optional: set expiration
  expiration_date = "2025-12-31T23:59:59Z"

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# API Key
resource "azurerm_key_vault_secret" "api_key" {
  name         = "api-key"
  value        = var.api_key
  key_vault_id = azurerm_key_vault.main.id
}

# Certificate from file
resource "azurerm_key_vault_certificate" "app" {
  name         = "ssl-cert"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_actions {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
      validity_months = 12
    }
  }
}
```

### Retrieve Secrets in Terraform

```hcl
# Use data source to read secrets
data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = azurerm_key_vault.main.id
}

# Use the secret in configuration
resource "azurerm_mssql_database" "example" {
  name      = "appdb"
  server_id = azurerm_mssql_server.example.id
  collation = "SQL_Latin1_General_CP1_CI_AS"
}
```

### Sensitive Outputs

```hcl
# outputs.tf
output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

# DON'T output secrets - mark as sensitive
output "db_connection_string" {
  description = "Database connection string"
  value       = azurerm_key_vault_secret.db_connection.value
  sensitive   = true  # Hides from CLI output
}
```

---

## Lab 4.12: Managed Identities

### Create User-Assigned Managed Identity

```hcl
# resources/managed-identity.tf
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.location
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

output "identity_client_id" {
  description = "Managed Identity Client ID"
  value       = azurerm_user_assigned_identity.app.client_id
}

output "identity_principal_id" {
  description = "Managed Identity Principal ID"
  value       = azurerm_user_assigned_identity.app.principal_id
}
```

### Assign RBAC Role to MI

```hcl
# Grant Key Vault access to Managed Identity
resource "azurerm_role_assignment" "kv_secret_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

### Assign MI to Virtual Machine

```hcl
# resources/vm.tf
resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  disable_password_authentication = true
  admin_ssh_key {
    username = "azureuser"
    public_key = var.ssh_public_key
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
```

### Use MI in Application Code

```python
# Python example for Azure
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url=f"https://{azurerm_key_vault.main.name}.vault.azure.net/",
    credential=credential
)

secret = client.get_secret("db-password")
```

---

## Lab 4.13: Monitoring Configuration

### Log Analytics Workspace

```hcl
# resources/monitoring.tf
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

output "workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "workspace_customer_id" {
  description = "Log Analytics Workspace Customer ID"
  value       = azurerm_log_analytics_workspace.main.customer_id
}
```

### Diagnostic Settings

```hcl
# Enable diagnostics for Key Vault
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                           = "kv-diag"
  target_resource_id             = azurerm_key_vault.main.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Enable diagnostics for NSG
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                           = "nsg-diag"
  target_resource_id             = azurerm_network_security_group.app.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
```

### Metric Alerts

```hcl
# resources/alerts.tf
resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "alert-cpu-high-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.app.id]
  description         = "CPU usage is above 80%"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80

    time_aggregation = "PT5M"
  }

  window_size = "PT5M"
  frequency   = "PT1M"

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.environment}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "DevOpsAlerts"

  email_receiver {
    name          = "DevOps Team"
    email_address = var.alert_email
  }

  webhook_receiver {
    name        = "Slack"
    service_uri = var.slack_webhook_url
  }
}
```

---

## Lab 4.14: Azure Policy as Code

### Policy Definition

```hcl
# resources/policies.tf
# Require tags on resources
resource "azurerm_policy_definition" "require_tags" {
  name         = "require-tags-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require tags on resources"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "field": "tags",
    "exists": "false"
  },
  "then": {
    "effect": "deny"
  }
}
POLICY_RULE

  parameters = <<PARAMETERS
{
  "tagName": {
    "type": "String",
    "defaultValue": "Environment"
  }
}
PARAMETERS
}
```

### Policy Assignment

```hcl
# resources/policy-assignments.tf
resource "azurerm_policy_assignment" "require_tags" {
  name                 = "assign-require-tags-${var.environment}"
  policy_definition_id = azurerm_policy_definition.require_tags.id
  scope                = azurerm_resource_group.main.id
  description          = "Requires tags on all resources in this resource group"

  parameters = jsonencode({
    tagName = "Environment"
  })

  identity {
    type = "SystemAssigned"
  }
}

# Initiative: Security baseline
resource "azurerm_policy_set_definition" "security_baseline" {
  name         = "security-baseline-${var.environment}"
  policy_type  = "Custom"
  display_name = "Security Baseline for ${var.environment}"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tags.id
  }

  # Add more policy references...
}
```

---

## Complete Module Example

### Root Module Structure

```
environments/dev/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── backend.tf
└── versions.tf

modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── compute/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── monitoring/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### environments/dev/main.tf

```hcl
# Main configuration for dev environment
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
  features {
    key_vault {
      soft_delete_enabled     = true
      purge_protection_enabled = true
    }
  }
  use_oidc = true
}

provider "azuread" {
  use_oidc = true
}

# Network module
module "networking" {
  source = "../../modules/networking"

  environment = var.environment
  project     = var.project
  location    = var.location
  tags        = var.tags
}

# Compute module
module "compute" {
  source = "../../modules/compute"

  depends_on = [module.networking]

  environment = var.environment
  project     = var.project
  location    = var.location
  subnet_id   = module.networking.subnet_ids["app"]
  tags        = var.tags
}

# Monitoring module
module "monitoring" {
  source = "../../modules/monitoring"

  depends_on = [module.networking, module.compute]

  environment = var.environment
  project     = var.project
  location    = var.location
  resource_group_id = module.networking.resource_group_id
  vm_ids = module.compute.vm_ids
  tags   = var.tags
}
```

### environments/dev/terraform.tfvars

```hcl
environment = "dev"
project     = "devops"
location    = "eastus"

tags = {
  Environment = "dev"
  Project     = "DevOps"
  ManagedBy   = "Terraform"
}

# For CI/CD (optional)
subscription_id = "your-subscription-id"

# Alert configuration
alert_email = "devops-team@example.com"
```

---

## Interview Reinforcement

### Q: How do you secure secrets in Terraform state?

> "Terraform state can contain sensitive values. Best practices include: (1) Use Azure Key Vault and reference secrets via data sources, never store plain secrets in tfvars. (2) Use `sensitive = true` on output values to prevent CLI display. (3) Use remote backend with encryption at rest. (4) Enable Azure Policy to prevent export of secrets. (5) Consider using Terraform Cloud/Enterprise with secret masking."

### Q: What's the difference between system-assigned and user-assigned managed identities?

> "System-assigned MI is tied to a single Azure resource and deleted with it. User-assigned MI is a standalone resource that can be shared across multiple resources. I prefer user-assigned MIs for applications because they're more flexible, can be pre-created, and have independent lifecycle. They're also recommended by Microsoft for cross-resource scenarios."

### Q: How do you monitor Terraform deployments?

> "I enable diagnostic settings on all resources sending logs to Log Analytics. I create metric alerts for critical resources (CPU, disk, network). I use Azure Policy to enforce monitoring configuration. For Terraform operations themselves, I use Azure DevOps or GitHub Actions with OIDC, capturing all plan/apply outputs and integrating with Sentinel for security analytics."

### Q: How do you manage state for module dependencies?

> "I use `depends_on` to explicitly declare dependencies between resources. For modules, I reference outputs as inputs to dependent modules. Terraform builds the dependency graph automatically. For implicit dependencies (resources used in `count` or `for_each`), Terraform infers the relationship. I avoid implicit dependencies on resources that don't exist yet by using `azurerm_resource_group` as the anchor."

### Q: How do you implement blue-green deployment with Terraform?

> "Terraform supports this through resource sets and lifecycle management. I use `azurerm_linux_virtual_machine_scale_set` with rolling upgrades. For Azure App Service, I use deployment slots. The key is using `create_before_destroy` in lifecycle meta-argument to create new resources before destroying old ones. I also use `azurerm_traffic_manager_profile` or Azure Front Door to switch between environments."

---

## Professional Deliverables

Complete Phase 4 by creating:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Key Vault | RBAC-enabled, soft-delete | `resources/kv.tf` |
| Secrets | DB, API keys, certificates | `resources/secrets.tf` |
| Managed Identity | User-assigned for apps | `resources/identity.tf` |
| Log Analytics | Workspace and diagnostics | `resources/monitoring.tf` |
| Alerts | CPU, disk, security alerts | `resources/alerts.tf` |
| Policies | Tagging, security policies | `resources/policies.tf` |
| Module Structure | Reusable modules | `modules/` |
| Complete Env | Dev environment running | Azure |

---

## Quick Reference

```bash
# Initialize
terraform init

# Format and validate
terraform fmt -recursive
terraform validate

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

# Refresh state
terraform refresh

# Destroy
terraform destroy -auto-approve
```

---

## Phase 4 Complete Checklist

Before moving to Phase 5, ensure:

### Foundation
- [ ] Terraform v1.x with AzureRM v4.x installed
- [ ] Azure CLI configured with Managed Identity
- [ ] Remote backend (Blob Storage) configured

### Infrastructure
- [ ] Resource Groups created via Terraform
- [ ] Virtual Networks with subnets configured
- [ ] NSGs with security rules deployed
- [ ] Private Endpoints for PaaS services

### Security
- [ ] Key Vault with RBAC and soft-delete
- [ ] Secrets stored securely
- [ ] Managed Identities created and assigned
- [ ] Azure AD groups configured

### Monitoring
- [ ] Log Analytics workspace created
- [ ] Diagnostic settings enabled
- [ ] Alert rules configured
- [ ] Azure Policy applied

### Deliverables
- [ ] All code in version control
- [ ] Documentation complete
- [ ] Clean/apply cycle tested
- [ ] State locking verified

---

## Next Steps

After completing Phase 4:
- [x] Understand Infrastructure as Code principles
- [x] Configure Terraform with AzureRM provider v4.x
- [x] Implement remote state with Blob Storage
- [x] Create Azure resources programmatically
- [x] Integrate Key Vault and Managed Identities
- [x] Set up monitoring and alerts

Ready to proceed to **Phase 5: CI/CD with GitHub Actions** →