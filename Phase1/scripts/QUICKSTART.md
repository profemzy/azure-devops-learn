# Quick Reference - Phase 1 Scripts

## 🚀 Quick Start

### Single VM (Linux Learning)
```bash
# Create (Ubuntu)
./ubuntu/create-linux-lab-vm.sh [location]

# Clean up
./common/cleanup-phase1.sh
```

### Multi-VM (Ansible Testing)
```bash
# Create (Ubuntu)
./ubuntu/create-multi-vms.sh [location]

# Clean up
./common/cleanup-phase1.sh
```

### 🌟 Unified Cleanup (Handles Both!)
```bash
# The smart way - detects everything automatically
./common/cleanup-phase1.sh

# Dry run first
AZURE_DRY_RUN=true ./common/cleanup-phase1.sh
```

## 📋 Common Commands

### Check Azure Login Status
```bash
az account show
```

### List Resource Groups
```bash
az group list -o table
```

### List VMs in Resource Group
```bash
az vm list -g devops-learn-rg -o table
```

### Get VM Public IP
```bash
az vm show -g devops-learn-rg -n devops-learn-vm -d --query publicIps -o tsv
```

### SSH to VM
```bash
ssh -i ~/.ssh/azure-vm-key azureuser@<PUBLIC_IP>
```

### Check VM Status
```bash
az vm get-instance-view -g devops-learn-rg -n devops-learn-vm
```

## 🔧 Environment Variables

### Quick Override Examples

```bash
# Change location
./ubuntu/create-linux-lab-vm.sh westus2

# Use bigger VM
AZURE_VM_SIZE=Standard_B2s ./ubuntu/create-linux-lab-vm.sh

# Use Ubuntu 22.04
AZURE_VM_IMAGE=Ubuntu2204 ./ubuntu/create-linux-lab-vm.sh

# Custom resource group name
AZURE_RESOURCE_GROUP=my-rg ./ubuntu/create-linux-lab-vm.sh

# Keep resource group on cleanup
AZURE_DELETE_RG=false ./common/cleanup-phase1.sh

# Skip all prompts (CI/CD)
AZURE_DO_NOT_PROMPT=true ./common/cleanup-phase1.sh
```

## 🎯 Typical Workflow

```bash
# 1. Create VM
./ubuntu/create-linux-lab-vm.sh

# 2. Get IP
IP=$(az vm show -g devops-learn-rg -n devops-learn-vm -d --query publicIps -o tsv)

# 3. SSH in
ssh -i ~/.ssh/azure-vm-key azureuser@$IP

# 4. Do your work...
# Practice Linux commands, test Ansible, etc.

# 5. Clean up
./common/cleanup-phase1.sh
```

## 🏗️ Multi-VM Architecture

```
Internet → Bastion (10.0.0.4)
             ↓
        ┌────┴────┬────────┬────────┐
        ↓         ↓        ↓        ↓
    Web Tier  App Tier  DB Tier
    (3 VMs)   (2 VMs)  (1 VM)
  10.0.1.*   10.0.2.*  10.0.3.*
```

## 🔑 SSH Key Management

```bash
# Auto-generated (default)
~/.ssh/azure-vm-key

# Or use your existing key
AZURE_SSH_KEY_PATH=~/.ssh/id_ed25519 ./ubuntu/create-linux-lab-vm.sh

# Manual key creation
ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key -N ""
```

## 🧹 Cleanup Options

```bash
# Smart cleanup - detects all Phase 1 resources
./common/cleanup-phase1.sh

# Preview first (dry run)
AZURE_DRY_RUN=true ./common/cleanup-phase1.sh

# Keep resource groups, delete only VMs
AZURE_DELETE_RG=false ./common/cleanup-phase1.sh

# Skip confirmation (CI/CD)
AZURE_DO_NOT_PROMPT=true ./common/cleanup-phase1.sh

# Clean specific resource group
AZURE_RESOURCE_GROUP=devops-learn-rg ./common/cleanup-phase1.sh
```

**What the unified cleanup does:**
1. 🔍 Scans subscription for Phase 1 resources (by tags, patterns)
2. 📋 Shows what it found (RGs, VMs, counts)
3. 🎯 Lets you choose what to delete
4. ✅ Performs cleanup with progress feedback

## 🐛 Troubleshooting

### Problem: "Not logged into Azure"
```bash
az login
```

### Problem: "Invalid location"
```bash
# List valid locations
az account list-locations -o table

# Use valid location
./ubuntu/create-linux-lab-vm.sh westus2
```

### Problem: "VM already exists"
```bash
# Clean up first
./common/cleanup-phase1.sh

# Or use different name
AZURE_VM_NAME=my-vm ./ubuntu/create-linux-lab-vm.sh
```

### Problem: Can't SSH
```bash
# Check VM status
az vm get-instance-view -g devops-learn-rg -n devops-learn-vm

# Check your SSH key
ls -l ~/.ssh/azure-vm-key*

# Verify IP
az vm show -g devops-learn-rg -n devops-learn-vm -d --query publicIps -o tsv
```

## 📊 Resource Limits

```bash
# Check your quota
az quota list

# List current usage
az vm list --resource-group devops-learn-rg --query "length(@)" -o tsv

# Check VM size availability
az vm list-usage -l eastus -o table
```

## 💰 Cost Management

```bash
# Estimate costs (with LazyVim and build tools)
# - Single VM (Standard_B4ms): ~$80-100/month (4 vCPU, 16 GB RAM)
# - Multi-VM (1x B4ms bastion + 6x B2s): ~$150-200/month
#
# Use smaller sizes to reduce costs:
#   AZURE_VM_SIZE=Standard_B2s ./ubuntu/create-linux-lab-vm.sh  # ~$30/month
#   AZURE_VM_SIZE=Standard_B1s ./ubuntu/create-linux-lab-vm.sh  # ~$10/month

# Stop VM when not in use (save costs)
az vm deallocate -g devops-learn-rg -n devops-learn-vm

# Start VM again
az vm start -g devops-learn-rg -n devops-learn-vm

# Delete when done
./common/cleanup-phase1.sh
```

## 🎓 Learning Path

1. **Start with single VM**
   ```bash
   ./ubuntu/create-linux-lab-vm.sh
   ```
   - Practice Linux commands
   - Learn file management
   - Understand user permissions

2. **Add SSH hardening**
   - Run `01-ssh-hardening.sh` on VM
   - Learn security best practices

3. **Scale to multi-VM**
   ```bash
./ubuntu/create-multi-vms.sh
   ```
   - Learn Ansible basics
   - Practice multi-server management

4. **Clean up everything**
   ```bash
   ./common/cleanup-phase1.sh
   ```
   - Script detects both single and multi-VM
   - One command cleans all

## 📝 Tips

- ✅ Scripts are idempotent - safe to run multiple times
- ✅ Use `AZURE_DRY_RUN=true` to preview cleanup before deleting
- ✅ Use `AZURE_DELETE_RG=false` to keep resource group for faster recreation
- ✅ Set `AZURE_DO_NOT_PROMPT=true` for CI/CD automation
- ✅ Always check Azure location availability before creating resources
- ✅ Delete resources when not in use to avoid unnecessary charges
- ✅ Use `az monitor` commands to track resource status

## 🔗 Useful Links

- [Full Documentation](./README.md)
- [Azure CLI Docs](https://docs.microsoft.com/cli/azure/)
- [Azure Pricing](https://azure.microsoft.com/pricing/)
- [Phase 1 Guides](../)
