# Phase 1 Cleanup Guide

This guide explains how to clean up Azure resources created during Phase 1.

---

## When to Clean Up

- After completing Phase 1 exercises
- Before starting Phase 2 (to start fresh)
- When you no longer need the test environment
- To avoid ongoing Azure costs

---

## Cost Considerations

| Resource | Estimated Cost (B2s VM) |
|----------|------------------------|
| VM (running) | ~$8-10/month |
| VM (stopped) | ~$2-3/month |
| Deleted | $0 |

---

## Cleanup Options

### Option 1: Using the Cleanup Script (Single VM)

```bash
# Make the script executable
chmod +x scripts/common/cleanup-phase1.sh

# Run the cleanup script
./scripts/common/cleanup-phase1.sh
```

### Option 1b: Cleaning up the Multi-VM environment

If you created the 7-VM environment for Ansible testing, use the same unified cleanup script:

```bash
chmod +x scripts/common/cleanup-phase1.sh
./scripts/common/cleanup-phase1.sh
```

**Note:** This removes the `rg-devops-learn` resource group containing:
- 7 VMs (bastion, web1-3, app1-2, db1)
- Virtual network and subnets
- 4 Network Security Groups

The script will:
1. Display what will be deleted
2. Ask for confirmation
3. Delete the resource group in the background

---

### Option 2: Manual Cleanup via Azure CLI

```bash
# Delete the entire resource group
az group delete \
  --name devops-learn-rg \
  --yes \
  --no-wait
```

---

### Option 3: Stop VM (Keep for Later)

If you want to save costs but keep the VM for future use:

```bash
# Stop and deallocate the VM
az vm deallocate \
  --resource-group devops-learn-rg \
  --name devops-learn-vm

# Verify VM is stopped
az vm show \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --query "powerState" \
  --output table
```

**Expected Output:**
```
PowerState
----------
VM deallocated
```

---

### Option 4: Start VM Again Later

```bash
# Start the VM
az vm start \
  --resource-group devops-learn-rg \
  --name devops-learn-vm

# Get the public IP
az vm list-ip-addresses \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  --output tsv
```

---

## What Gets Deleted

### Single VM Setup (devops-learn-rg)

When you delete the resource group, the following are permanently removed:

| Resource | Type |
|----------|------|
| devops-learn-vm | Virtual Machine |
| devops-learn-vmNSG | Network Security Group |
| devops-learn-vm_OsDisk_xxx | OS Disk |
| devops-learn-vmNicxxx | Network Interface |
| Public IP | IP Address |
| Virtual Network | Network |
| All data on the VM | - |

### Multi-VM Setup (rg-devops-learn)

When you delete this resource group, the following are permanently removed:

| Resource | Type |
|----------|------|
| 7 VMs | bastion, web1, web2, web3, app1, app2, db1 |
| 4 NSGs | nsg-bastion, nsg-web, nsg-app, nsg-db |
| 1 VNet | vnet-devops-learn |
| 4 Subnets | subnet-bastion, subnet-web, subnet-app, subnet-db |
| 7 Public IPs | One per VM |
| 7 NICs | One per VM |
| All data on VMs | - |

---

## Verification

### Check Resource Group Status

```bash
# Try to show the resource group (will fail if deleted)
az group show --name devops-learn-rg
```

**Expected (after deletion):**
```
Resource group 'devops-learn-rg' could not be found.
```

### List All Resource Groups

```bash
# Verify devops-learn-rg is gone
az group list --output table | grep devops-learn
```

---

## Recreate Phase 1 Environment

If you deleted everything and need to start over:

```bash
# 1. Create resource group and VM
az group create --name devops-learn-rg --location eastus

az vm create \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --image Canonical:ubuntu-24_04-lts:server:latest \
  --admin-username azureuser \
  --generate-ssh-keys \
  --nsg-rule SSH \
  --size Standard_B2s

# 2. Get the public IP
VM_IP=$(az vm show \
  --resource-group devops-learn-rg \
  --name devops-learn-vm \
  --show-details \
  --query "publicIps" \
  --output tsv)

echo "VM IP: $VM_IP"

# 3. Upload and run hardening script
scp scripts/common/01-ssh-hardening.sh azureuser@$VM_IP:~/
ssh azureuser@$VM_IP "chmod +x ~/01-ssh-hardening.sh && sudo ~/01-ssh-hardening.sh"
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Delete everything | `az group delete --name devops-learn-rg --yes --no-wait` |
| Stop VM (save costs) | `az vm deallocate --resource-group devops-learn-rg --name devops-learn-vm` |
| Start VM | `az vm start --resource-group devops-learn-rg --name devops-learn-vm` |
| Check VM status | `az vm show --resource-group devops-learn-rg --name devops-learn-vm --query "powerState"` |
| Get VM IP | `az vm list-ip-addresses --resource-group devops-learn-rg --name devops-learn-vm` |
