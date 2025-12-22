# Phase 1: Azure Multi-VM Setup for Ansible

This guide creates multiple Azure VMs for practicing multi-node Ansible management. You'll set up a 3-tier architecture (web, app, database) to test the concepts from the Ansible multi-node lab.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Lab 1.20: Create Multiple VMs with Azure CLI](#lab-120-create-multiple-vms-with-azure-cli)
4. [Lab 1.21: Automated Multi-VM Setup Script](#lab-121-automated-multi-vm-setup-script)
5. [Configure Ansible Inventory](#configure-ansible-inventory)
6. [Distribute SSH Keys](#distribute-ssh-keys)
7. [Test Connectivity](#test-connectivity)
8. [Cleanup Multiple VMs](#cleanup-multiple-vms)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Virtual Network                     │
│                    10.0.0.0/16 (vnet-devops-learn)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Web Tier  │  │   App Tier  │  │     DB      │              │
│  │ 10.0.1.0/24 │  │ 10.0.2.0/24 │  │ 10.0.3.0/24 │              │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤              │
│  │ web1 (10.0.1.10)│ app1 (10.0.2.10) │ db1 (10.0.3.10) │        │
│  │ web2 (10.0.1.11)│ app2 (10.0.2.11) │               │        │
│  │ web3 (10.0.1.12)│                  │               │        │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                 │
│  ┌─────────────────────────────────────────────────┐            │
│  │           Bastion Host (Jump Box)               │            │
│  │              10.0.0.10 (bastion)                │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### VM Specifications

| VM Name | Subnet | Size | Purpose |
|---------|--------|------|---------|
| `bastion` | 10.0.0.0/24 | Standard_B2s | Jump box, Ansible control node |
| `web1` | 10.0.1.0/24 | Standard_B2s | Web server (nginx) |
| `web2` | 10.0.1.0/24 | Standard_B2s | Web server (nginx) |
| `web3` | 10.0.1.0/24 | Standard_B2s | Web server (nginx) |
| `app1` | 10.0.2.0/24 | Standard_B2s | Application server (Node.js) |
| `app2` | 10.0.2.0/24 | Standard_B2s | Application server (Node.js) |
| `db1` | 10.0.3.0/24 | Standard_B2s | PostgreSQL database |

---

## Prerequisites

```bash
# Check Azure CLI installation
az version

# Verify you're logged in
az account show

# Create a resource group first (if not exists)
az group create \
  --name rg-devops-learn \
  --location eastus

# Create SSH key (if not exists)
ls -la ~/.ssh/azure-vm-key*

# If not exists, generate:
ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key -N ""
```

---

## Lab 1.20: Create Multiple VMs with Azure CLI

### Step 1: Create Virtual Network and Subnets

```bash
# Variables
RESOURCE_GROUP="rg-devops-learn"
LOCATION="eastus"
VNET_NAME="vnet-devops-learn"

# Create Virtual Network
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefixes 10.0.0.0/16 \
  --location $LOCATION

# Create Subnets
# Bastion subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name subnet-bastion \
  --address-prefixes 10.0.0.0/24

# Web tier subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name subnet-web \
  --address-prefixes 10.0.1.0/24

# App tier subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name subnet-app \
  --address-prefixes 10.0.2.0/24

# Database tier subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name subnet-db \
  --address-prefixes 10.0.3.0/24

# Verify subnets
az network vnet subnet list \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --output table
```

### Step 2: Create Network Security Groups

```bash
# NSG for Bastion (allow SSH from anywhere)
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name nsg-bastion \
  --location $LOCATION

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-bastion \
  --name AllowSSH \
  --priority 100 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# NSG for Web tier (SSH from bastion, HTTP/HTTPS from anywhere)
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name nsg-web \
  --location $LOCATION

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-web \
  --name AllowSSHFromBastion \
  --priority 100 \
  --source-address-prefixes 10.0.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-web \
  --name AllowHTTP \
  --priority 110 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-web \
  --name AllowHTTPS \
  --priority 111 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 443 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# NSG for App tier (SSH from bastion, app port from web tier)
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name nsg-app \
  --location $LOCATION

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-app \
  --name AllowSSHFromBastion \
  --priority 100 \
  --source-address-prefixes 10.0.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-app \
  --name AllowAppPort \
  --priority 110 \
  --source-address-prefixes 10.0.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 3000 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# NSG for Database tier (SSH from bastion, PostgreSQL from app tier)
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name nsg-db \
  --location $LOCATION

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-db \
  --name AllowSSHFromBastion \
  --priority 100 \
  --source-address-prefixes 10.0.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-db \
  --name AllowPostgreSQL \
  --priority 110 \
  --source-address-prefixes 10.0.2.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 5432 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound
```

### Step 3: Create VMs

```bash
# Common variables
SSH_KEY=$(cat ~/.ssh/azure-vm-key.pub)
ADMIN_USER="azureuser"
VNET_NAME="vnet-devops-learn"

# === Create Bastion VM (Control Node) ===
echo "Creating bastion VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name bastion \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username $ADMIN_USER \
  --ssh-key-values "$SSH_KEY" \
  --vnet-name $VNET_NAME \
  --subnet subnet-bastion \
  --nsg nsg-bastion \
  --public-ip-sku Standard \
  --tags "tier=bastion" "environment=dev"

# === Create Web Tier VMs ===
for i in 1 2 3; do
  echo "Creating web$i VM..."
  az vm create \
    --resource-group $RESOURCE_GROUP \
    --name web$i \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username $ADMIN_USER \
    --ssh-key-values "$SSH_KEY" \
    --vnet-name $VNET_NAME \
    --subnet subnet-web \
    --nsg nsg-web \
    --public-ip-sku Standard \
    --tags "tier=web" "environment=dev" "serial=$i"
done

# === Create App Tier VMs ===
for i in 1 2; do
  echo "Creating app$i VM..."
  az vm create \
    --resource-group $RESOURCE_GROUP \
    --name app$i \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username $ADMIN_USER \
    --ssh-key-values "$SSH_KEY" \
    --vnet-name $VNET_NAME \
    --subnet subnet-app \
    --nsg nsg-app \
    --public-ip-sku Standard \
    --tags "tier=app" "environment=dev" "serial=$i"
done

# === Create Database VM ===
echo "Creating db1 VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name db1 \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username $ADMIN_USER \
  --ssh-key-values "$SSH_KEY" \
  --vnet-name $VNET_NAME \
  --subnet subnet-db \
  --nsg nsg-db \
  --public-ip-sku Standard \
  --tags "tier=db" "environment=dev"

# Verify all VMs
echo "Listing all VMs..."
az vm list \
  --resource-group $RESOURCE_GROUP \
  --output table --query "[].{Name:name,Status:powerState,PublicIP:publicIps,PrivateIP:privateIps}"
```

---

## Lab 1.21: Automated Multi-VM Setup Script

```bash
#!/bin/bash
# Phase 1: Create Multi-VM Infrastructure for Ansible Testing
# Usage: ./create-multi-vms.sh [location]

set -euo pipefail

LOCATION="${1:-eastus}"
RESOURCE_GROUP="rg-devops-learn"
VNET_NAME="vnet-devops-learn"
ADMIN_USER="azureuser"
SSH_KEY_PATH="$HOME/.ssh/azure-vm-key"

echo "=== Multi-VM Setup for Ansible ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""

# Check prerequisites
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Creating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

SSH_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Create resource group
echo "Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output none

# Create VNET
echo "Creating virtual network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefixes 10.0.0.0/16 \
  --location $LOCATION \
  --output none

# Create subnets
for subnet in subnet-bastion subnet-web subnet-app subnet-db; do
    case $subnet in
        subnet-bastion) PREFIX="10.0.0.0/24" ;;
        subnet-web) PREFIX="10.0.1.0/24" ;;
        subnet-app) PREFIX="10.0.2.0/24" ;;
        subnet-db) PREFIX="10.0.3.0/24" ;;
    esac

    az network vnet subnet create \
      --resource-group $RESOURCE_GROUP \
      --vnet-name $VNET_NAME \
      --name $subnet \
      --address-prefixes $PREFIX \
      --output none
done

# Create NSGs and rules
create_nsg() {
    local nsg_name=$1
    local rules=$2

    az network nsg create \
      --resource-group $RESOURCE_GROUP \
      --name $nsg_name \
      --location $LOCATION \
      --output none

    eval "$rules"
}

# Bastion NSG (SSH from anywhere)
create_nsg "nsg-bastion" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-bastion \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output none
"

# Web NSG (SSH from VNet, HTTP/HTTPS from anywhere)
create_nsg "nsg-web" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTP \
    --priority 110 \
    --source-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-web \
    --name AllowHTTPS \
    --priority 111 \
    --source-address-prefixes '*' \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# App NSG
create_nsg "nsg-app" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-app \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-app \
    --name AllowApp \
    --priority 110 \
    --source-address-prefixes 10.0.1.0/24 \
    --destination-port-ranges 3000 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# DB NSG
create_nsg "nsg-db" "
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-db \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes 10.0.0.0/16 \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --output none
  az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-db \
    --name AllowPostgreSQL \
    --priority 110 \
    --source-address-prefixes 10.0.2.0/24 \
    --destination-port-ranges 5432 \
    --access Allow \
    --protocol Tcp \
    --output none
"

# Function to create VM
create_vm() {
    local name=$1
    local subnet=$2
    local nsg=$3
    local tier=$4

    echo "Creating $name VM..."
    az vm create \
      --resource-group $RESOURCE_GROUP \
      --name $name \
      --image Ubuntu2204 \
      --size Standard_B2s \
      --admin-username $ADMIN_USER \
      --ssh-key-values "$SSH_KEY" \
      --vnet-name $VNET_NAME \
      --subnet $subnet \
      --nsg $nsg \
      --public-ip-sku Standard \
      --tags "tier=$tier" "environment=dev" \
      --output none
}

# Create Bastion
create_vm "bastion" "subnet-bastion" "nsg-bastion" "bastion"

# Create Web tier (3 VMs)
for i in 1 2 3; do
    create_vm "web$i" "subnet-web" "nsg-web" "web"
done

# Create App tier (2 VMs)
for i in 1 2; do
    create_vm "app$i" "subnet-app" "nsg-app" "app"
done

# Create DB tier (1 VM)
create_vm "db1" "subnet-db" "nsg-db" "db"

# Get public IPs
echo ""
echo "=== VM Public IP Addresses ==="
az vm list-ip-addresses \
  --resource-group $RESOURCE_GROUP \
  --output table \
  --query "[].{Name:virtualMachine.name,PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress,PrivateIP:virtualMachine.network.privateIpAddresses[0]}"

echo ""
echo "=== Setup Complete ==="
echo "7 VMs created successfully!"
echo ""
echo "Next steps:"
echo "  1. SSH to bastion: ssh -i ~/.ssh/azure-vm-key azureuser@<bastion-ip>"
echo "  2. Copy SSH key to all VMs from bastion"
echo "  3. Configure Ansible inventory"
echo "  4. Run ansible-playbook"
```

Save this as `scripts/create-multi-vms.sh` and make it executable:

```bash
chmod +x scripts/create-multi-vms.sh
./scripts/create-multi-vms.sh eastus
```

---

## Configure Ansible Inventory

After creating VMs, configure your Ansible inventory:

```yaml
# ~/ansible/inventory/dev.yml
---
all:
  children:
    # Control node (bastion)
    control:
      hosts:
        bastion:
          ansible_host: <BASTION_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          control_node: true

    # Web tier
    webservers:
      hosts:
        web1:
          ansible_host: <WEB1_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web
        web2:
          ansible_host: <WEB2_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web
        web3:
          ansible_host: <WEB3_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web

    # App tier
    appservers:
      hosts:
        app1:
          ansible_host: <APP1_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: app
        app2:
          ansible_host: <APP2_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: app

    # Database tier
    dbservers:
      hosts:
        db1:
          ansible_host: <DB1_PUBLIC_IP>
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: db

  vars:
    environment: development
    ntp_servers:
      - 0.pool.ntp.org
      - 1.pool.ntp.org
```

---

## Distribute SSH Keys

From the bastion host, distribute the SSH key to all VMs:

```bash
# On your local machine, copy key to bastion first
ssh-copy-id -i ~/.ssh/azure-vm-key.pub azureuser@<BASTION_IP>

# SSH to bastion
ssh -i ~/.ssh/azure-vm-key azureuser@<BASTION_IP>

# From bastion, copy key to all other VMs
for vm in web1 web2 web3 app1 app2 db1; do
    ssh-copy-id azureuser@$vm
done
```

Or use Ansible's authorized_key module in a playbook:

```yaml
# ~/ansible/distribute-keys.yml
---
- name: Distribute SSH keys to all nodes
  hosts: all
  become: true
  gather_facts: false

  vars:
    ssh_key: "{{ lookup('file', '~/.ssh/azure-vm-key.pub') }}"

  tasks:
    - name: Ensure .ssh directory exists
      file:
        path: /home/azureuser/.ssh
        state: directory
        mode: '0700'
        owner: azureuser
        group: azureuser

    - name: Add SSH key to authorized_keys
      authorized_key:
        user: azureuser
        key: "{{ ssh_key }}"
        state: present
```

---

## Test Connectivity

```bash
# Test all hosts
ansible all -m ping

# Test specific group
ansible webservers -m ping
ansible appservers -m ping
ansible dbservers -m ping

# Gather facts from all hosts
ansible all -m setup

# Check disk space on all hosts
ansible all -a "df -h"

# Check memory on all hosts
ansible all -a "free -m"
```

---

## Use Ansible to Create VMs (Alternative)

You can also use Ansible to create and manage the VMs:

```yaml
# ~/ansible/create-vms.yml
---
- name: Create Azure VMs for testing
  hosts: localhost
  connection: local
  gather_facts: false

  vars:
    resource_group: rg-devops-learn
    location: eastus
    vnet_name: vnet-devops-learn
    admin_user: azureuser
    ssh_key: "{{ lookup('file', '~/.ssh/azure-vm-key.pub') }}"

  tasks:
    - name: Create resource group
      azure.azcollection.azure_rm_resourcegroup:
        name: "{{ resource_group }}"
        location: "{{ location }}"

    - name: Create virtual network
      azure.azcollection.azure_rm_virtualnetwork:
        resource_group: "{{ resource_group }}"
        name: "{{ vnet_name }}"
        address_prefixes: "10.0.0.0/16"

    - name: Create web subnet
      azure.azcollection.azure_rm_subnet:
        resource_group: "{{ resource_group }}"
        name: subnet-web
        virtual_network_name: "{{ vnet_name }}"
        address_prefix: "10.0.1.0/24"

    - name: Create VMs
      azure.azcollection.azure_rm_virtualmachine:
        resource_group: "{{ resource_group }}"
        name: "{{ item.name }}"
        vm_size: Standard_B2s
        image:
          offer: UbuntuServer
          publisher: Canonical
          sku: "22_04-lts"
          version: latest
        admin_username: "{{ admin_user }}"
        ssh_password_enabled: false
        ssh_public_keys:
          - path: "/home/{{ admin_user }}/.ssh/authorized_keys"
            key_data: "{{ ssh_key }}"
        virtual_network_name: "{{ vnet_name }}"
        subnet: subnet-web
      loop:
        - { name: web1 }
        - { name: web2 }
        - { name: web3 }
        - { name: app1 }
        - { name: app2 }
        - { name: db1 }
```

---

## Cleanup Multiple VMs

```bash
#!/bin/bash
# Cleanup all VMs created for Ansible testing

RESOURCE_GROUP="rg-devops-learn"

# Delete all VMs
for vm in bastion web1 web2 web3 app1 app2 db1; do
    echo "Deleting $vm..."
    az vm delete \
      --resource-group $RESOURCE_GROUP \
      --name $vm \
      --yes \
      --no-wait \
      2>/dev/null || true
done

# Delete NSGs
for nsg in nsg-bastion nsg-web nsg-app nsg-db; do
    az network nsg delete \
      --resource-group $RESOURCE_GROUP \
      --name $nsg \
      --no-wait \
      2>/dev/null || true
done

# Delete VNet
az network vnet delete \
  --resource-group $RESOURCE_GROUP \
  --name vnet-devops-learn \
  --no-wait

# Delete resource group (optional - removes everything)
# az group delete --name $RESOURCE_GROUP --yes

echo "Cleanup initiated. Resource group will be deleted shortly."
```

Save as `scripts/cleanup-multi-vms.sh`:

```bash
chmod +x scripts/cleanup-multi-vms.sh
./scripts/cleanup-multi-vms.sh
```

---

## Professional Deliverables

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Multi-VM Setup Script | Creates 7 VMs for testing | `scripts/create-multi-vms.sh` |
| Cleanup Script | Removes all VMs and resources | `scripts/cleanup-multi-vms.sh` |
| Ansible Inventory | Multi-tier inventory file | `inventory/dev.yml` |
| SSH Key Distribution | Playbook for key distribution | `distribute-keys.yml` |

---

## Phase 1 Complete Checklist

After completing multi-VM setup:

- [ ] Resource group created
- [ ] Virtual network with subnets configured
- [ ] NSGs with appropriate rules created
- [ ] All 7 VMs provisioned
- [ ] SSH connectivity verified from control node
- [ ] Ansible inventory configured
- [ ] Multi-node Ansible ping successful

---

## Next Steps

After multi-VM setup:

- Configure Ansible playbooks for multi-tier deployment
- Practice rolling updates with `serial: 1`
- Test ad-hoc commands across all tiers
- Deploy application stack with web, app, and database tiers