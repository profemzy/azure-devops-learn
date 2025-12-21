# Phase 3: Azure Network Security Guide

This guide covers VNet design, NSG configuration, Private Endpoints, and Network Security Perimeters for secure Azure deployments.

---

## Table of Contents

1. [Virtual Network Architecture](#virtual-network-architecture)
2. [Lab 3.5: VNet Design & Subnetting](#lab-35-vnet-design--subnetting)
3. [Lab 3.6: Network Security Groups](#lab-36-network-security-groups)
4. [Lab 3.7: Private Endpoints](#lab-37-private-endpoints)
5. [Lab 3.8: Network Security Perimeters (2025)](#lab-38-network-security-perimeters-2025)
6. [Professional Deliverables](#professional-deliverables)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Virtual Network Architecture

### VNet Design Principles

```
Subscription: Production
└── Resource Group: rg-devops-prod-networking-eastus
    └── Virtual Network: vnet-devops-prod-eastus (10.0.0.0/16)
        ├── Subnet: snet-bastion (10.0.0.0/24)
        ├── Subnet: snet-app (10.0.1.0/24)
        ├── Subnet: snet-data (10.0.2.0/24)
        └── Subnet: snet-db (10.0.3.0/28)
```

### CIDR Block Planning

| CIDR | Usable IPs | Use Case |
|------|------------|----------|
| /24 | 251 | Small workload |
| /23 | 507 | Medium workload |
| /22 | 1019 | Large workload |
| /21 | 2043 | Enterprise |

---

## Lab 3.5: VNet Design & Subnetting

### Step 1: Create Virtual Network

```bash
# Set variables
RESOURCE_GROUP="rg-devops-prod-networking-eastus"
LOCATION="eastus"
VNET_NAME="vnet-devops-prod-eastus"
ADDRESS_PREFIX="10.0.0.0/16"

# Create VNet
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefixes "$ADDRESS_PREFIX" \
  --tags "Environment=Production" "Project=DevOps"

# Verify creation
az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query "{Name:name, AddressSpace:addressSpace.addressPrefixes, Subnets:subnets}"
```

### Step 2: Create Subnets

```bash
# Create Bastion subnet (for Azure Bastion access)
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-bastion" \
  --address-prefixes "10.0.0.0/24"

# Create Application subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --address-prefixes "10.0.1.0/24"

# Create Data subnet (for storage, cache)
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-data" \
  --address-prefixes "10.0.2.0/24"

# Create Database subnet (restricted)
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-db" \
  --address-prefixes "10.0.3.0/28"

# List all subnets
az network vnet subnet list \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --output table
```

### Step 3: Configure Subnet Delegation

```bash
# Delegate subnet to Azure Container Apps
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --delegations "Microsoft.App/containerApps"

# Delegate to Azure Kubernetes Service
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --delegations "Microsoft.ContainerService/managedClusters"

# Verify delegation
az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --query "delegations"
```

### Step 4: Create Route Table

```bash
# Create route table
az network route-table create \
  --resource-group "$RESOURCE_GROUP" \
  --name "rt-devops-prod-eastus" \
  --location "$LOCATION" \
  --tags "Environment=Production"

# Add custom route (example: force tunnel through NVA)
az network route-table route create \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "rt-devops-prod-eastus" \
  --name "to-firewall" \
  --address-prefix "0.0.0.0/0" \
  --next-hop-type "VirtualAppliance" \
  --next-hop-ip-address "10.0.100.4"

# Associate route table with subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --route-table "rt-devops-prod-eastus"
```

### Step 5: Create VNet Peering (Cross-Region)

```bash
# Get remote VNet ID (assuming peer VNet exists)
PEER_VNET_ID="/subscriptions/OTHER-SUBSCRIPTION/resourceGroups/rg-devops-prod-westus/providers/Microsoft.Network/virtualNetworks/vnet-devops-prod-westus"

# Create peering from eastus to westus
az network vnet peering create \
  --resource-group "$RESOURCE_GROUP" \
  --name "peer-east-to-west" \
  --vnet-name "$VNET_NAME" \
  --remote-vnet "$PEER_VNET_ID" \
  --allow-vnet-access

# Note: Must also create reverse peering from westus
```

---

## Lab 3.6: Network Security Groups

### NSG Rule Structure

```
Priority (100-4096) → Lower number = higher priority
Direction: Inbound/Outbound
Source/Dest: IP, Service Tag, or NSG
Port: Specific port or range
Action: Allow/Deny
```

### Step 1: Create NSG for Application Subnet

```bash
# Create NSG
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "nsg-devops-prod-app" \
  --location "$LOCATION" \
  --tags "Environment=Production"

# Add inbound rules

# Allow HTTP from anywhere (not recommended for production)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-http" \
  --priority 100 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Inbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 80

# Allow HTTPS
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-https" \
  --priority 101 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Inbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 443

# Allow SSH from specific IP (bastion or admin)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-ssh-from-bastion" \
  --priority 200 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Inbound" \
  --source-address-prefixes "10.0.0.0/24" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 22

# Deny all other inbound
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "deny-all-inbound" \
  --priority 4095 \
  --access "Deny" \
  --protocol "*" \
  --direction "Inbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "*"

# Allow outbound HTTPS
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-https-outbound" \
  --priority 100 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Outbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 443

# List NSG rules
az network nsg show \
  --resource-group "$RESOURCE_GROUP" \
  --name "nsg-devops-prod-app" \
  --query "securityRules" \
  --output table
```

### Step 2: Create NSG for Database Subnet

```bash
# Create strict NSG for database
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "nsg-devops-prod-db" \
  --location "$LOCATION" \
  --tags "Environment=Production"

# Allow SQL from App subnet only
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-db" \
  --name "allow-sql-from-app" \
  --priority 100 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Inbound" \
  --source-address-prefixes "10.0.1.0/24" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 1433

# Allow PostgreSQL from App subnet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-db" \
  --name "allow-postgresql-from-app" \
  --priority 101 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Inbound" \
  --source-address-prefixes "10.0.1.0/24" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 5432

# Deny all other inbound
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-db" \
  --name "deny-all-inbound" \
  --priority 4095 \
  --access "Deny" \
  --protocol "*" \
  --direction "Inbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "*"
```

### Step 3: Associate NSGs with Subnets

```bash
# Associate app NSG with app subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-app" \
  --network-security-group "nsg-devops-prod-app"

# Associate db NSG with db subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "snet-db" \
  --network-security-group "nsg-devops-prod-db"

# Verify associations
az network vnet subnet list \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --query "[].{Name:name, NSG:id}"
```

### Step 4: Use Service Tags

```bash
# Allow outbound to Azure Services (Storage, Key Vault)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-azure-storage" \
  --priority 110 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Outbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "Storage" \
  --destination-port-ranges 443

# Allow Azure Key Vault
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-keyvault" \
  --priority 111 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Outbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "AzureKeyVault" \
  --destination-port-ranges 443

# Allow SQL Database (for app connectivity)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "nsg-devops-prod-app" \
  --name "allow-sql" \
  --priority 112 \
  --access "Allow" \
  --protocol "Tcp" \
  --direction "Outbound" \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "Sql" \
  --destination-port-ranges 1433

# List available service tags
az network list-service-tags --location eastus --output table
```

---

## Lab 3.7: Private Endpoints

### Why Private Endpoints?

| Feature | Public Endpoint | Private Endpoint |
|---------|-----------------|------------------|
| Access | Anyone with internet | VNet only |
| DNS | Public resolution | Private DNS zone |
| NSG | Cannot filter | Cannot filter NIC |
| Traffic | Via internet | Via Azure backbone |

### Step 1: Create Private DNS Zone

```bash
# Create Private DNS Zone for Key Vault
az network private-dns zone create \
  --resource-group "$RESOURCE_GROUP" \
  --name "privatelink.vaultcore.azure.net" \
  --tags "Environment=Production"

# Create for Storage
az network private-dns zone create \
  --resource-group "$RESOURCE_GROUP" \
  --name "privatelink.blob.core.windows.net" \
  --tags "Environment=Production"

# Create for Azure SQL
az network private-dns zone create \
  --resource-group "$RESOURCE_GROUP" \
  --name "privatelink.database.windows.net" \
  --tags "Environment=Production"

# Link DNS zone to VNet (no auto-registration)
az network private-dns link vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "dns-link-kv" \
  --zone-name "privatelink.vaultcore.azure.net" \
  --virtual-network "$VNET_NAME" \
  --registration-enable false

az network private-dns link vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "dns-link-storage" \
  --zone-name "privatelink.blob.core.windows.net" \
  --virtual-network "$VNET_NAME" \
  --registration-enable false

az network private-dns link vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "dns-link-sql" \
  --zone-name "privatelink.database.windows.net" \
  --virtual-network "$VNET_NAME" \
  --registration-enable false
```

### Step 2: Create Private Endpoint for Key Vault

```bash
# Get Key Vault ID
KV_ID=$(az keyvault show \
  --name "kv-devops-prod-secrets" \
  --query "id" -o tsv)

# Create Private Endpoint
az network private-endpoint create \
  --resource-group "$RESOURCE_GROUP" \
  --name "pe-kv-devops-prod" \
  --location "$LOCATION" \
  --vnet-name "$VNET_NAME" \
  --subnet "snet-app" \
  --private-connection-resource-id "$KV_ID" \
  --group-id "vault" \
  --connection-name "kv-connection" \
  --tags "Environment=Production"

# Get Private Endpoint IP
PE_NIC_ID=$(az network private-endpoint show \
  --resource-group "$RESOURCE_GROUP" \
  --name "pe-kv-devops-prod" \
  --query "networkInterfaces[0].id" -o tsv)

az network nic show \
  --ids "$PE_NIC_ID" \
  --query "ipConfigurations[0].privateIPAddress"
```

### Step 3: Disable Public Access on Key Vault

```bash
# Disable public network access
az keyvault update \
  --name "kv-devops-prod-secrets" \
  --resource-group "rg-devops-prod-security-eastus" \
  --public-network-access "Disabled"

# Verify configuration
az keyvault show \
  --name "kv-devops-prod-secrets" \
  --query "{PublicAccess:properties.publicNetworkAccess, PrivateEndpoints:properties.privateEndpointConnections}"
```

### Step 4: Create Private Endpoint for Storage

```bash
# Get Storage Account ID
STORAGE_ID=$(az storage account show \
  --name "stdevopsprodeastus" \
  --resource-group "$RESOURCE_GROUP" \
  --query "id" -o tsv)

# Create Private Endpoint for Blob
az network private-endpoint create \
  --resource-group "$RESOURCE_GROUP" \
  --name "pe-storage-blob" \
  --location "$LOCATION" \
  --vnet-name "$VNET_NAME" \
  --subnet "snet-app" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id "blob" \
  --connection-name "storage-blob-connection"

# Disable public blob access
az storage account update \
  --name "stdevopsprodeastus" \
  --resource-group "$RESOURCE_GROUP" \
  --public-network-access "Disabled"
```

### Step 5: Create Private Endpoint for Azure SQL

```bash
# Get SQL Server ID
SQL_ID=$(az sql server show \
  --name "sql-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --query "id" -o tsv)

# Create Private Endpoint
az network private-endpoint create \
  --resource-group "$RESOURCE_GROUP" \
  --name "pe-sql-devops-prod" \
  --location "$LOCATION" \
  --vnet-name "$VNET_NAME" \
  --subnet "snet-data" \
  --private-connection-resource-id "$SQL_ID" \
  --group-id "sqlServer" \
  --connection-name "sql-connection"

# Disable public network access
az sql server update \
  --name "sql-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --public-network-access "Disabled"
```

---

## Lab 3.8: Network Security Perimeters (2025)

### Understanding Network Security Perimeters

Network Security Perimeters provide **traffic filtering across VNets and Private Endpoints** with a unified security model.

### Step 1: Create Network Security Perimeter

```bash
# Create perimeter (using REST API or Portal)
# Perimeters allow defining allowed traffic patterns

# List supported resources for NSP
# - Azure Monitor
# - Azure AI Search
# - Cosmos DB
# - Event Hubs
# - Key Vault
# - Storage Accounts
# - SQL Servers
```

### Step 2: Configure Perimeter Rules

```json
{
  "perimeter": {
    "name": "nsp-devops-prod",
    "location": "eastus",
    "accessRules": [
      {
        "name": "allow-app-to-db",
        "direction": "Inbound",
        "source": {
          "type": "VirtualNetwork",
          "ids": ["/subscriptions/.../virtualNetworks/vnet-devops-prod-eastus"]
        },
        "destination": {
          "type": "AzureResource",
          "ids": ["/subscriptions/.../sqlServers/sql-devops-prod"]
        },
        "protocols": ["tcp"],
        "ports": ["1433"]
      },
      {
        "name": "allow-app-to-storage",
        "direction": "Outbound",
        "source": {
          "type": "VirtualNetwork",
          "ids": ["/subscriptions/.../virtualNetworks/vnet-devops-prod-eastus"]
        },
        "destination": {
          "type": "AzureResource",
          "ids": ["/subscriptions/.../storageAccounts/stdevopsprodeastus"]
        },
        "protocols": ["tcp"],
        "ports": ["443"]
      }
    ]
  }
}
```

### Step 3: Associate Resources with Perimeter

```bash
# Associate storage account with perimeter
az rest --method put \
  --url "https://management.azure.com/subscriptions/SUB-ID/resourceGroups/RG/providers/Microsoft.Network/networkSecurityPerimeters/nsp-devops-prod/resourceAssociations/storage-assoc?api-version=2024-01-01" \
  --body '{
    "properties": {
      "profile": {
        "name": "default",
        "perimeterGuid": "PERIMETER-GUID"
      }
    }
  }'
```

### Step 4: Verify Perimeter Compliance

```bash
# Check if resources are properly isolated
az network security-perimeter profile list \
  --resource-group "$RESOURCE_GROUP" \
  --output table

# View perimeter definitions
az network security-perimeter definition list \
  --output table
```

---

## Professional Deliverables

Complete Phase 3 Network Security section by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Virtual Network | Multi-subnet VNet with proper CIDR | Azure |
| NSGs | Application and database NSGs | Azure |
| Route Table | Custom routing with firewall | Azure |
| Private DNS Zones | Linked to VNet | Azure |
| Private Endpoints | KV, Storage, SQL endpoints | Azure |
| Network Diagram | Architecture documentation | `docs/network-architecture.png` |
| NSG Rule Documentation | Security rules explained | `docs/nsg-rules.md` |

---

## Interview Reinforcement

### Q: When would you use Private Endpoint vs Service Endpoint?

> "Private Endpoint provides resource-level security with a private IP pointing to the specific resource. It's more secure but NSG rules on the Private Endpoint NIC are not supported. Service Endpoint provides subnet-level access with Microsoft backbone routing, allowing NSG filtering. For critical resources requiring maximum isolation, use Private Endpoint. For general PaaS access with NSG control, Service Endpoint works."

### Q: How do you secure a subnet with NSGs?

> "I create layered NSGs - subnet-level for broad rules and NIC-level for specific control. I deny all inbound by default and only allow specific ports from specific sources. I use service tags for Azure services instead of IP ranges. I enable NSG flow logs for monitoring. I regularly audit and review rules."

### Q: What are Network Security Perimeters and why use them?

> "NSPs are a 2025 feature providing unified traffic filtering across VNets and Private Endpoints. They enable micro-segmentation at the resource level with a single policy model. They're useful when you need consistent security policy across multiple resources and VNets, especially for compliant workloads."

### Q: How do you prevent public access to PaaS resources?

> "I disable public network access on each PaS resource. I create Private Endpoints for required connectivity. I use Private DNS zones for name resolution. I configure NSG rules to block outbound public traffic if needed. I use Azure Policy to enforce these settings."

### Q: How do you handle DNS resolution for Private Endpoints?

> "I create Private DNS zones for each PaaS service type (vault.azure.net, blob.core.windows.net). I link these zones to the VNet with no auto-registration. This ensures resources resolve to private IPs. For hybrid scenarios, I use DNS forwarding to on-premises DNS servers."

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `az network vnet create` | Create VNet |
| `az network nsg create` | Create NSG |
| `az network nsg rule create` | Add NSG rule |
| `az network private-dns zone create` | Create DNS zone |
| `az network private-endpoint create` | Create Private Endpoint |
| `az network vnet subnet update --network-security-group` | Associate NSG |

---

## Next Steps

After completing Phase 3 Network Security:
- [x] Design VNet with proper subnetting
- [x] Configure NSGs with least privilege
- [x] Implement Private Endpoints for critical resources
- [x] Create Private DNS zones
- [x] Explore Network Security Perimeters

Proceed to **Azure Key Vault & Secrets Management** →