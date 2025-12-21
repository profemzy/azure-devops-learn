# Phase 4: Azure Resources with Terraform

This guide covers creating Azure resource groups, virtual networks, subnets, NSGs, and Private Endpoints using Terraform.

---

## Table of Contents

1. [Resource Organization](#resource-organization)
2. [Lab 4.6: Resource Groups](#lab-46-resource-groups)
3. [Lab 4.7: Virtual Networks](#lab-47-virtual-networks)
4. [Lab 4.8: Network Security Groups](#lab-48-network-security-groups)
5. [Lab 4.9: Private Endpoints](#lab-49-private-endpoints)
6. [Using Data Sources](#using-data-sources)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Resource Organization

### Recommended Structure

```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── stg/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
└── prod/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars

modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── compute/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── security/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### Naming Conventions

| Resource Type | Pattern | Example |
|--------------|---------|---------|
| Resource Group | `rg-{env}-{project}-{loc}` | `rg-dev-devops-eastus` |
| VNet | `vnet-{env}-{project}-{loc}` | `vnet-dev-devops-eastus` |
| Subnet | `snet-{purpose}` | `snet-app`, `snet-db` |
| NSG | `nsg-{env}-{purpose}` | `nsg-dev-app` |
| Private Endpoint | `pe-{service}` | `pe-keyvault` |

---

## Lab 4.6: Resource Groups

### Basic Resource Group

```hcl
# resources/resource-group.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.environment}-${var.project}-${var.location}"
  location = var.location
  tags     = var.tags
}
```

### Resource Group with Lock

```hcl
# Prevent accidental deletion
resource "azurerm_management_lock" "main" {
  name       = "${azurerm_resource_group.main.name}-lock"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "This resource group is protected from deletion"
}
```

### Output References

```hcl
# outputs.tf
output "resource_group_id" {
  description = "Resource Group ID"
  value       = azurerm_resource_group.main.id
}

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Resource Group location"
  value       = azurerm_resource_group.main.location
}
```

### Variables

```hcl
# variables.tf
variable "environment" {
  description = "Environment (dev, stg, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "Environment must be dev, stg, or prod"
  }
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "devops"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "DevOps"
    ManagedBy   = "Terraform"
  }
}
```

---

## Lab 4.7: Virtual Networks

### VNet with Subnets

```hcl
# resources/virtual-network.tf
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment}-${var.project}-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers

  tags = var.tags
}

# Application subnet
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

# Database subnet
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  # Private endpoint network policies
  private_endpoint_network_policies_enabled = true
}

# Bastion subnet (required for Azure Bastion)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Delegate subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]

  delegation {
    name = "aks-delegation"
    service_delegation {
      name = "Microsoft.ContainerService/managedClusters"
    }
  }
}
```

### Variables for Networking

```hcl
# variables.tf (additional)
variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "dns_servers" {
  description = "Custom DNS servers"
  type        = list(string)
  default     = []
}
```

### VNet Outputs

```hcl
# outputs.tf (additional)
output "virtual_network_id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    app      = azurerm_subnet.app.id
    db       = azurerm_subnet.db.id
    bastion  = azurerm_subnet.bastion.id
    aks      = azurerm_subnet.aks.id
  }
}
```

---

## Lab 4.8: Network Security Groups

### NSG with Security Rules

```hcl
# resources/network-security-group.tf
resource "azurerm_network_security_group" "app" {
  name                = "nsg-${var.environment}-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}

# Security rule: Allow HTTPS from anywhere
resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow-https"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = 443
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Security rule: Allow SSH from bastion
resource "azurerm_network_security_rule" "allow_ssh_bastion" {
  name                        = "allow-ssh-from-bastion"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = azurerm_subnet.bastion.address_prefixes
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = 22
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Security rule: Allow SQL from app subnet
resource "azurerm_network_security_rule" "allow_sql_app" {
  name                        = "allow-sql-from-app"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = azurerm_subnet.app.address_prefixes
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = 1433
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Deny all other inbound
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny-all-inbound"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Allow outbound HTTPS
resource "azurerm_network_security_rule" "allow_https_outbound" {
  name                        = "allow-https-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "Internet"
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}
```

### Associate NSG with Subnet

```hcl
# Associate NSG with app subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

### NSG for Database

```hcl
# Database NSG - more restrictive
resource "azurerm_network_security_group" "db" {
  name                = "nsg-${var.environment}-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}

# Allow PostgreSQL from app subnet
resource "azurerm_network_security_rule" "allow_postgres_app" {
  name                        = "allow-postgres-from-app"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = azurerm_subnet.app.address_prefixes
  destination_port_range      = 5432
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.db.name
}

# Associate with db subnet
resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}
```

### Service Tags in Rules

```hcl
# Use service tags for Azure services
resource "azurerm_network_security_rule" "allow_storage_https" {
  name                        = "allow-storage-https"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"  # Service tag
  destination_port_range      = 443
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "allow_keyvault" {
  name                        = "allow-keyvault"
  priority                    = 111
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureKeyVault"  # Service tag
  destination_port_range      = 443
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}
```

---

## Lab 4.9: Private Endpoints

### Create Private DNS Zones

```hcl
# resources/private-dns.tf
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}

resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_link" {
  name                  = "keyvault-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_link" {
  name                  = "storage-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
```

### Private Endpoint for Key Vault

```hcl
# resources/private-endpoint-keyvault.tf
data "azurerm_key_vault" "existing" {
  name                = "kv-${var.environment}-${var.project}-${var.location}"
  resource_group_name = "rg-${var.environment}-security-${var.location}"
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.environment}-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.app.id

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = data.azurerm_key_vault.existing.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                   = "keyvault-dns"
    private_dns_zone_ids   = [azurerm_private_dns_zone.keyvault.id]
  }
}
```

### Private Endpoint for Storage

```hcl
# resources/private-endpoint-storage.tf
data "azurerm_storage_account" "existing" {
  name                  = "st${var.environment}${var.project}${replace(var.location, "-", "")}"
  resource_group_name   = "rg-${var.environment}-storage-${var.location}"
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-${var.environment}-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.app.id

  private_service_connection {
    name                           = "storage-blob-connection"
    private_connection_resource_id = data.azurerm_storage_account.existing.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                   = "storage-dns"
    private_dns_zone_ids   = [azurerm_private_dns_zone.storage.id]
  }
}
```

### Private Endpoint for SQL Database

```hcl
# resources/private-endpoint-sql.tf
data "azurerm_mssql_server" "existing" {
  name                = "sql-${var.environment}-${var.project}"
  resource_group_name = "rg-${var.environment}-data-${var.location}"
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.environment}-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.db.id

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = data.azurerm_mssql_server.existing.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                   = "sql-dns"
    private_dns_zone_ids   = [azurerm_private_dns_zone.sql.id]
  }
}
```

---

## Using Data Sources

### Read Existing Resources

```hcl
# data-sources.tf

# Read VNet from Hub subscription
data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-eastus"
  resource_group_name = "rg-hub-networking-eastus"
}

# Read Azure AD Group
data "azuread_group" "devops_team" {
  display_name = "DevOps-Team"
}

# Read existing Key Vault
data "azurerm_key_vault" "shared" {
  name                = "kv-shared-secrets"
  resource_group_name = "rg-shared-security-eastus"
}

# Get current subscription
data "azurerm_subscription" "current" {}

# Get current client identity
data "azurerm_client_config" "current" {}
```

### Use Data Source in Configuration

```hcl
# VNet peering to hub
resource "azurerm_virtual_network_peering" "to_hub" {
  name                      = "peer-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = true
}

# Add members to AD group
resource "azuread_group_member" "add_user" {
  group_object_id  = data.azuread_group.devops_team.object_id
  member_object_id = data.azurerm_client_config.current.object_id
}
```

---

## Professional Deliverables

Complete this section by creating:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Resource Groups | Dev, staging, prod RGs | `resources/rg.tf` |
| Virtual Network | VNet with subnets | `resources/vnet.tf` |
| NSGs | App and DB NSGs | `resources/nsg.tf` |
| Private DNS Zones | For KV, Storage, SQL | `resources/dns.tf` |
| Private Endpoints | Key Vault, Storage, SQL | `resources/pe.tf` |
| Variables | Environment-specific | `environments/dev/variables.tf` |
| Outputs | Resource outputs | `environments/dev/outputs.tf` |

---

## Interview Reinforcement

### Q: How do you structure Terraform for multiple environments?

> "I use a module-based approach with environment-specific configurations. Each environment has its own folder with `main.tf`, `variables.tf`, and `terraform.tfvars`. Common resources are in reusable modules. Remote state is separated by environment using different keys. This ensures isolation while maintaining code consistency."

### Q: What's the difference between implicit and explicit subnet associations?

> "Implicit association happens automatically when you create a subnet in a VNet. Explicit association is when you use `azurerm_subnet_network_security_group_association` resource. In Terraform v4.x, explicit association is recommended because it makes the dependency clear and allows Terraform to manage the lifecycle properly."

### Q: How do you implement least privilege with Terraform state?

> "I use separate service principals or managed identities for different environments. Dev can have Contributor on dev RG only. Prod has more restricted access. CI/CD uses workload identity with federated credentials. State storage uses Azure RBAC with Storage Blob Data Contributor role only where needed."

### Q: Why use Private Endpoints in Terraform?

> "Private Endpoints route traffic through Azure backbone, keeping it off the public internet. They're essential for PCI compliance, GDPR, and other regulatory requirements. In Terraform, I create the Private DNS zones and link them to the VNet for automatic name resolution. This ensures applications can reach PaaS services without public IPs."

### Q: How do you handle drift detection in Terraform?

> "Terraform detects drift automatically when you run `terraform plan`. It compares the current state with desired state and shows differences. For ongoing drift, I enable Azure Policy to prevent configuration changes outside Terraform. For critical resources, I use `terraform refresh` to sync state. Automated drift detection can be set up with Azure Monitor and Sentinel."

---

## Quick Reference

```bash
# Plan changes
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply with auto-approve
terraform apply -auto-approve -var-file="environments/dev/terraform.tfvars"

# Show specific resource
terraform state show azurerm_virtual_network.main

# List all resources
terraform state list | grep vnet

# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/...
```

---

## Next Steps

After completing this section:
- [x] Create Resource Groups with naming conventions
- [x] Configure Virtual Networks with subnets
- [x] Implement NSGs with security rules
- [x] Set up Private DNS Zones
- [x] Create Private Endpoints

Proceed to **Lab 4.10: Key Vault & Monitoring Integration** →