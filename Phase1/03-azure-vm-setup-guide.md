# Azure VM Setup Guide

This guide covers creating and configuring an Azure Linux VM for the SSH hardening exercise.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Create Resource Group and VM](#create-resource-group-and-vm)
3. [Configure Network Security](#configure-network-security)
4. [Connect to the VM](#connect-to-the-vm)
5. [Verify Prerequisites for SSH Hardening](#verify-prerequisites-for-ssh-hardening)
6. [Upload Hardening Script](#upload-hardening-script)
7. [Clean Up](#clean-up)

---

## Prerequisites

### Azure CLI Installation

**Windows (PowerShell):**
```powershell
winget install Microsoft.AzureCLI
```

**macOS:**
```bash
brew install azure-cli
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Verify Installation:**
```bash
az version
```

### Azure Account

```bash
# Login to Azure
az login

# Set your subscription (if multiple)
az account set --subscription "your-subscription-id"

# Verify current account
az account show --output table
```

---

## Create Resource Group and VM

### Step 1: Create Resource Group

A resource group is a container for related resources.

```bash
# Create resource group
az group create \
  --name devops-learn-rg \
  --location eastus

# Verify creation
az group show --name devops-learn-rg --output table
```

**Expected Output:**
```
Name               Location    Status
-----------------  ----------  ----------
devops-learn-rg    eastus      Succeeded
```

### Step 2: Create Linux VM

```bash
# Create VM with SSH keys
az vm create \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --image Canonical:ubuntu-24_04-lts:server:latest \
  --admin-username azureuser \
  --generate-ssh-keys \
  --nsg-rule SSH \
  --size Standard_B2s
```

**Parameters Explained:**

| Parameter | Description |
|-----------|-------------|
| `--resource-group` | Resource group name |
| `--name` | VM name |
| `--image` | OS image (Ubuntu 24.04 LTS) |
| `--admin-username` | Default admin user |
| `--generate-ssh-keys` | Creates ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub |
| `--nsg-rule` | Creates NSG rule allowing SSH (port 22) |
| `--size` | VM size (B2s = 2 vCPUs, 4 GiB RAM) |

**Expected Output:**
```
{
  "fqdns": "",
  "id": "/subscriptions/.../resourceGroups/devops-learn-rg/providers/Microsoft.Compute/virtualMachines/devops-learn-vm",
  "location": "eastus",
  "macAddress": "...",
  "powerState": "VM running",
  "privateIpAddress": "10.0.0.4",
  "publicIpAddress": "20.x.x.x",
  "resourceGroup": "devops-learn-rg",
  "vmId": "..."
}
```

---

## Configure Network Security

### View Network Security Group Rules

```bash
# Get NSG name
az vm show \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --query "networkProfile.networkInterfaces[0].id" \
  --output tsv

# List NSG rules
az network nsg list \
  --resource-group devops-learn-rg \
  --query "[].name" \
  --output table

# Show detailed NSG rules
az network nsg rule list \
  --resource-group devops-learn-rg \
  --nsg-name devops-learn-vmNSG \
  --output table
```

**Expected Output:**
```
Name          ResourceGroup        Priority    Port  Protocol  Access
------------  -------------------  ----------  ----  --------  --------
default-allow-devops-learn-rg  devops-learn-rg  1000   22        TCP     Allow
SSH           devops-learn-rg     300          22    TCP      Allow
```

### Add Custom SSH Port (Optional)

If you want to use a non-standard SSH port:

```bash
# Create NSG rule for custom port
az network nsg rule create \
  --resource-group devops-learn-rg \
  --nsg-name devops-learn-vmNSG \
  --name SSH-Custom-2222 \
  --destination-port-ranges 2222 \
  --priority 1001 \
  --access Allow \
  --protocol Tcp
```

---

## Connect to the VM

### Get Public IP Address

```bash
# Method 1: Get IP directly
az vm list-ip-addresses \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --output table

# Method 2: Get only the public IP
PUBLIC_IP=$(az vm show \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --show-details \
  --query "publicIps" \
  --output tsv)
echo "VM IP: $PUBLIC_IP"
```

### SSH Connection

```bash
# Connect to VM (uses auto-generated keys)
ssh azureuser@$PUBLIC_IP

# Or with specific key
ssh -i ~/.ssh/id_rsa azureuser@$PUBLIC_IP
```

**Expected Output:**
```
Welcome to Ubuntu 24.04 LTS (GNU/Linux 6.5.0-xxxx-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

...

azureuser@devops-learn-vm:~$
```

---

## Verify Prerequisites for SSH Hardening

Before running the SSH hardening script, verify your environment:

### Check 1: Admin User Exists

```bash
# Check current user
whoami

# List sudo users
getent group sudo

# Test sudo access
sudo whoami
```

**Expected Output:**
```
azureuser
# Output should show "root" without password prompt
```

### Check 2: SSH Service is Running

```bash
# Check SSH service status
sudo systemctl status ssh --no-pager

# Verify SSH is listening
sudo ss -tlnp | grep ssh
```

**Expected Output:**
```
Active: active (running)
LISTEN    0         128                0.0.0.0:22                0.0.0.0:*
```

### Check 3: SSH Key Authentication Works

```bash
# Verify key files exist
ls -la ~/.ssh/

# Check key permissions
stat -c "%a" ~/.ssh/id_rsa
```

**Expected Output:**
```
id_rsa      (private key - 600)
id_rsa.pub  (public key - 644)
authorized_keys (644)
```

### Check 4: Password Authentication is Currently Enabled

```bash
# Check current SSH settings
sudo sshd -T | grep -i passwordauthentication
```

**Expected Output (before hardening):**
```
passwordauthentication yes
```

### Check 5: Root Login Status

```bash
# Check current root login setting
sudo sshd -T | grep -i permitrootlogin
```

**Expected Output (before hardening):**
```
permitrootlogin without-password
```

---

## Upload Hardening Script

### Method 1: SCP Upload

```bash
# Upload the hardening script
scp scripts/common/01-ssh-hardening.sh azureuser@$PUBLIC_IP:~/

# Make it executable
ssh azureuser@$PUBLIC_IP "chmod +x ~/01-ssh-hardening.sh"
```

### Method 2: Azure Run Command (Alternative)

```bash
# Upload and set permissions via Azure
az vm run-command invoke \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --command-id RunShellScript \
  --scripts "wget -O ~/01-ssh-hardening.sh https://raw.githubusercontent.com/your-repo/Phase1/scripts/common/01-ssh-hardening.sh && chmod +x ~/01-ssh-hardening.sh"
```

### Method 3: Cloud-Init (For New VMs)

Create a cloud-init.txt file:

```bash
# Create cloud-init configuration
cat > cloud-init.txt << 'EOF'
#cloud-config
package_update: true
packages:
  - openssh-server
runcmd:
  - wget -O /home/azureuser/01-ssh-hardening.sh https://raw.githubusercontent.com/your-repo/Phase1/scripts/common/01-ssh-hardening.sh
  - chmod +x /home/azureuser/01-ssh-hardening.sh
  - sudo /home/azureuser/01-ssh-hardening.sh
EOF

# Create VM with cloud-init
az vm create \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --image Canonical:ubuntu-24_04-lts:server:latest \
  --admin-username azureuser \
  --generate-ssh-keys \
  --custom-data cloud-init.txt \
  --size Standard_B2s
```

---

## Clean Up

### Option 1: Keep VM for Further Exercises

```bash
# List all resources in the resource group
az resource list \
  --resource-group devops-learn-rg \
  --output table
```

### Option 2: Delete Resource Group (Complete Cleanup)

```bash
# WARNING: This deletes ALL resources in the group
az group delete \
  --name devops-learn-rg \
  --yes --no-wait
```

**Expected Output:**
```
Operation results in a long-running operation. Provisioning state will be updated asynchronously.
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Create resource group | `az group create --name devops-learn-rg --location eastus` |
| Create VM | `az vm create --resource-group devops-learn-rg --name devops-learn-vm ...` |
| Get VM IP | `az vm list-ip-addresses --resource-group devops-learn-rg --name devops-learn-vm` |
| SSH connect | `ssh azureuser@<VM_IP>` |
| Delete resource group | `az group delete --name devops-learn-rg --yes` |

---

## Troubleshooting

### VM Creation Fails

```bash
# Check available VM sizes in region
az vm list-sizes --location eastus --output table | head -20

# Check quota limits
az vm list-usage --location eastus --output table
```

### SSH Connection Refused

```bash
# Check if SSH is running
az vm run-command invoke \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --command-id RunShellScript \
  --scripts "sudo systemctl status ssh"

# Check NSG rules
az network nsg rule list \
  --resource-group devops-learn-rg \
  --nsg-name devops-learn-vmNSG \
  --output table
```

### SSH Keys Not Working

```bash
# Regenerate SSH keys
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Upload new public key
az vm user update \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --username azureuser \
  --ssh-key-value ~/.ssh/id_rsa.pub
```
