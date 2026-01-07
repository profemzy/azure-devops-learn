# Phase 1 Scripts - Improved Version

This directory contains improved Azure infrastructure scripts with enhanced error handling, validation, idempotency, and user experience.

## 📋 What's New

### Key Improvements

1. **Shared Functions Library** (`az-common.sh`)
   - Eliminates code duplication
   - Consistent error handling and logging
   - Reusable validation functions

2. **Enhanced Error Handling**
   - Graceful failure with helpful error messages
   - Validation of Azure locations before resource creation
   - Better prerequisite checking

3. **Idempotent Operations**
   - Scripts can be run multiple times safely
   - Check if resources exist before creating
   - Skip existing resources with warnings

4. **Configurable via Environment Variables**
   - Customize VM size, image, location without editing scripts
   - Override defaults for different environments

5. **Better User Experience**
   - Color-coded output (INFO, SUCCESS, WARNING, ERROR)
   - Clear progress indicators
   - Helpful next steps and examples

6. **Optional Resource Group Deletion**
   - Choose to keep or delete resource group during cleanup
   - Useful for development/testing workflows

## 🚀 Scripts Overview

> **Structure note**: OS-specific scripts live in subfolders:
> - `scripts/ubuntu/` (Ubuntu/Debian)
> - `scripts/rhel/` (RHEL-compatible: Alma/Rocky/CentOS)
>
> Run OS-specific scripts from the subfolders:
> - Ubuntu/Debian: `scripts/ubuntu/*.sh`
> - RHEL-compatible: `scripts/rhel/*.sh`

### Shared Library

| Script | Purpose |
|--------|---------|
| `common/az-common.sh` | Common functions for all scripts (do not run directly) |

### Creation Scripts

| Script | Purpose |
|--------|---------|
| `ubuntu/create-linux-lab-vm.sh` | Create a single Ubuntu VM |
| `rhel/create-linux-lab-vm.sh` | Create a single RHEL-compatible VM (AlmaLinux) for learning |
| `ubuntu/create-multi-vms.sh` | Create 7 VMs for Ansible testing (3-tier architecture) |

### Cleanup Script

| Script | Purpose |
|--------|---------|
| `common/cleanup-phase1.sh` | **🌟 UNIFIED INTELLIGENT CLEANUP** - Automatically detects and cleans up ALL Phase 1 resources |

### Installation Scripts

| Script | Purpose |
|--------|---------|
| `ubuntu/install-lazyvim.sh` | Install LazyVim and dev tools on Ubuntu/Debian |
| `rhel/install-lazyvim.sh` | Install LazyVim and dev tools on RHEL-compatible systems |

## 📖 Usage

### Prerequisites

1. **Azure CLI installed**
   ```bash
   # macOS
   brew install azure-cli

   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

   # Verify
   az --version
   ```

2. **Login to Azure**
   ```bash
   az login
   ```

3. **SSH key** (auto-created if missing)
   ```bash
   # Optional: Create manually
   ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key
   ```

### Creating a Single Ubuntu VM

```bash
# Basic usage (defaults to eastus)
./ubuntu/create-linux-lab-vm.sh

# Specify location
./ubuntu/create-linux-lab-vm.sh westus2

# With custom VM size
AZURE_VM_SIZE=Standard_B2s ./ubuntu/create-linux-lab-vm.sh

# With custom image
AZURE_VM_IMAGE=Ubuntu2204 ./ubuntu/create-linux-lab-vm.sh
```

**Output:**
- Creates resource group: `devops-learn-rg`
- Creates VM: `devops-learn-vm`
- Opens SSH port (22)
- Installs LazyVim and development tools
- Displays connection information

### Creating a Single RHEL-compatible VM (AlmaLinux)

```bash
# Basic usage (defaults to eastus)
./rhel/create-linux-lab-vm.sh

# Specify location
./rhel/create-linux-lab-vm.sh westus2

# With custom VM size
AZURE_VM_SIZE=Standard_B2s ./rhel/create-linux-lab-vm.sh

# With custom AlmaLinux version
AZURE_VM_IMAGE=AlmaLinux9 ./rhel/create-linux-lab-vm.sh
```

**Output:**
- Creates resource group: `devops-learn-rg`
- Creates VM: `devops-rhel-vm`
- Opens SSH port (22)
- Installs LazyVim and development tools (RHEL-compatible versions)
- Displays connection information

**Note:** RHEL-compatible VMs use AlmaLinux, which is a 1:1 binary compatible fork of RHEL. Perfect for learning RHEL-based system administration.

### Cleaning Up Resources

```bash
# Intelligent cleanup (detects all Phase 1 resources automatically)
./common/cleanup-phase1.sh

# Preview what would be deleted (dry run)
./common/cleanup-phase1.sh
# Then choose option based on what you want to delete

# Keep resource groups, delete only VMs
AZURE_DELETE_RG=false ./common/cleanup-phase1.sh

# Skip confirmation prompts (CI/CD)
AZURE_DO_NOT_PROMPT=true ./common/cleanup-phase1.sh

# Dry run mode - see what would be deleted without actually deleting
AZURE_DRY_RUN=true ./common/cleanup-phase1.sh

# Clean up specific resource group only
AZURE_RESOURCE_GROUP=devops-learn-rg ./common/cleanup-phase1.sh
```

**The unified cleanup script will:**
1. 🔍 Scan your subscription for Phase 1 resources (by tags, naming patterns)
2. 📋 Show you exactly what it found (resource groups, VMs, counts)
3. 🎯 Let you choose what to delete (everything, specific RGs, or cancel)
4. ✅ Perform the cleanup with detailed progress feedback

### Creating Multi-VM Environment

```bash
# Basic usage
./ubuntu/create-multi-vms.sh

# Specify location
./ubuntu/create-multi-vms.sh westus2

# With custom VM size
AZURE_VM_SIZE=Standard_B4ms ./ubuntu/create-multi-vms.sh
```

**Architecture:**
```
┌─────────────┐
│   Bastion   │ (10.0.0.0/24) - SSH from internet
│   (1 VM)    │
└──────┬──────┘
       │
┌──────┴──────────────────────────────┐
│         Virtual Network             │
│  ┌─────────┬─────────┬─────────┐   │
│  │  Web    │   App   │    DB   │   │
│  │ (3 VMs) │ (2 VMs) │ (1 VM)  │   │
│  └─────────┴─────────┴─────────┘   │
└────────────────────────────────────┘
```

### Cleaning Up Multi-VM Environment

```bash
# The same unified cleanup script handles both single and multi-VM setups
./common/cleanup-phase1.sh

# It will automatically detect:
#   - Single VM setup (devops-learn-rg)
#   - Multi-VM setup (rg-devops-learn)
#   - Any custom resource groups with Phase 1 resources
```

## 🔧 Configuration

### Environment Variables

#### Creation Scripts

**Single VM (`create-linux-lab-vm.sh`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_RESOURCE_GROUP` | `devops-learn-rg` | Resource group name |
| `AZURE_VM_NAME` | `devops-learn-vm` | Virtual machine name |
| `AZURE_VM_SIZE` | `Standard_B4ms` | VM size (4 vCPU, 16 GB RAM) |
| `AZURE_VM_IMAGE` | `Ubuntu2404` | OS image |
| `AZURE_ADMIN_USER` | `azureuser` | Admin username |
| `AZURE_SSH_KEY_PATH` | `~/.ssh/azure-vm-key` | SSH key path |
| `AZURE_LOCATION` | `eastus` | Azure region |
| `AZURE_INSTALL_LAZYVIM` | `true` | Auto-install LazyVim |

**Single RHEL VM (`create-linux-lab-vm.sh`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_RESOURCE_GROUP` | `devops-learn-rg` | Resource group name |
| `AZURE_VM_NAME` | `devops-rhel-vm` | Virtual machine name |
| `AZURE_VM_SIZE` | `Standard_B4ms` | VM size (4 vCPU, 16 GB RAM) |
| `AZURE_VM_IMAGE` | `AlmaLinux9` | OS image (RHEL-compatible) |
| `AZURE_ADMIN_USER` | `azureuser` | Admin username |
| `AZURE_SSH_KEY_PATH` | `~/.ssh/azure-vm-key` | SSH key path |
| `AZURE_LOCATION` | `eastus` | Azure region |
| `AZURE_INSTALL_LAZYVIM` | `true` | Auto-install LazyVim |

**Multi-VM (`create-multi-vms.sh`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_RESOURCE_GROUP` | `rg-devops-learn` | Resource group name |
| `AZURE_VNET_NAME` | `vnet-devops-learn` | Virtual network name |
| `AZURE_VM_SIZE` | `Standard_B2s` | VM size for tier VMs |
| `AZURE_VM_SIZE_BASTION` | `Standard_B4ms` | VM size for bastion (4 vCPU, 16 GB RAM) |
| `AZURE_VM_IMAGE` | `Ubuntu2404` | OS image |
| `AZURE_ADMIN_USER` | `azureuser` | Admin username |
| `AZURE_SSH_KEY_PATH` | `~/.ssh/azure-vm-key` | SSH key path |
| `AZURE_LOCATION` | `eastus` | Azure region |
| `AZURE_INSTALL_LAZYVIM` | `true` | Auto-install LazyVim on bastion |

#### Cleanup Script (`cleanup-phase1.sh`)

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_DELETE_RG` | `true` | Delete resource groups (vs. only VMs) |
| `AZURE_DO_NOT_PROMPT` | `false` | Skip confirmation prompts (CI/CD mode) |
| `AZURE_RESOURCE_GROUP` | *auto-detect* | Specific RG to clean (default: scan all) |
| `AZURE_DRY_RUN` | `false` | Show what would be deleted without deleting |

### Common Azure Locations

```
eastus, eastus2, westus, westus2, westus3
centralus, northcentralus, southcentralus
westeurope, northeurope, southeastasia
eastasia, japaneast, japanwest
```

Validate locations:
```bash
az account list-locations -o table
```

## 🎯 Common Workflows

### Workflow 1: Learning Linux Basics

```bash
# 1. Create VM
./ubuntu/create-linux-lab-vm.sh

# 2. Connect and practice
ssh -i ~/.ssh/azure-vm-key azureuser@<PUBLIC_IP>

# 3. Clean up when done
./common/cleanup-phase1.sh
# Choose option 1 to delete everything
```

### Workflow 2: Testing Ansible

```bash
# 1. Create multi-VM environment
./ubuntu/create-multi-vms.sh

# 2. Get bastion IP
BASTION_IP=$(az vm show -g rg-devops-learn -n bastion -d --query publicIps -o tsv)

# 3. SSH to bastion
ssh -i ~/.ssh/azure-vm-key azureuser@$BASTION_IP

# 4. From bastion, distribute SSH keys
ssh-copy-id azureuser@10.0.1.4  # web1
ssh-copy-id azureuser@10.0.1.5  # web2
# ... etc

# 5. Create Ansible inventory
cat > ~/ansible-inventory.ini << 'EOF'
[webservers]
web1 ansible_host=10.0.1.4
web2 ansible_host=10.0.1.5
web3 ansible_host=10.0.1.6

[appservers]
app1 ansible_host=10.0.2.4
app2 ansible_host=10.0.2.5

[dbserver]
db1 ansible_host=10.0.3.4
EOF

# 6. Test connectivity
ansible all -i ~/ansible-inventory.ini -m ping

# 7. Clean up
./common/cleanup-phase1.sh
# Script will detect both single and multi-VM setups
```

### Workflow 3: Development with Resource Retention

```bash
# Create environment once
./ubuntu/create-linux-lab-vm.sh

# Do work, test, etc.

# Delete only VMs, keep resource group for faster recreation
AZURE_DELETE_RG=false ./common/cleanup-phase1.sh

# Recreate VM (reuses resource group, faster)
./ubuntu/create-linux-lab-vm.sh

# When completely done, delete everything
./common/cleanup-phase1.sh
# Or: AZURE_DELETE_RG=true AZURE_DO_NOT_PROMPT=true ./common/cleanup-phase1.sh
```

### Workflow 4: Dry Run Before Deletion

```bash
# Preview what would be deleted
AZURE_DRY_RUN=true ./common/cleanup-phase1.sh

# Output shows:
#   ✓ Single VM setup: devops-learn-rg (1 VM)
#   ✓ Multi-VM setup: rg-devops-learn (7 VMs)
#   DRY RUN MODE - No resources will be deleted

# Then run actual cleanup
./common/cleanup-phase1.sh
```

## 🛡️ Security Features

1. **SSH Key Authentication**
   - Key-based auth only (no password)
   - Auto-creates ED25519 keys if missing with proper permissions (600/644)
   - Falls back to existing default keys (id_ed25519, id_rsa, id_ecdsa)
   - Clear error messages if key creation fails

2. **Network Security**
   - NSGs with minimal required ports
   - Tier-specific security rules
   - SSH restricted to VNet where appropriate

3. **Credential Management**
   - No credentials in code
   - Uses Azure CLI authentication
   - Supports service principals for CI/CD

## 🔍 Troubleshooting

### Script fails with "Azure CLI is not installed"

Install Azure CLI:
```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Script fails with "Not logged into Azure"

Login:
```bash
az login
```

### Script fails with "Invalid Azure location"

Check available locations:
```bash
az account list-locations -o table
```

Use a valid location:
```bash
./ubuntu/create-linux-lab-vm.sh westus2
```

### VM creation fails with "already exists"

The script is idempotent - you can:
1. Run cleanup: `./common/cleanup-phase1.sh`
2. Or use different name: `AZURE_VM_NAME=my-vm ./ubuntu/create-linux-lab-vm.sh`

### Can't SSH to VM

Check SSH key path:
```bash
ls -l ~/.ssh/azure-vm-key*
```

If SSH key doesn't exist, the script will auto-create it, or you can:
```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/azure-vm-key

# Or use existing key
AZURE_SSH_KEY_PATH=~/.ssh/id_ed25519 ./ubuntu/create-linux-lab-vm.sh
```

Verify VM is running:
```bash
az vm get-instance-view -g devops-learn-rg -n devops-learn-vm
```

### Resources not deleting

Azure deletion is async. Check status:
```bash
az group show -n devops-learn-rg
```

Force deletion:
```bash
az group delete -n devops-learn-rg --yes --no-wait
```

## 📚 Advanced Usage

### Using Service Principals (CI/CD)

```bash
# Login with service principal
az login --service-principal \
  -u $APP_ID \
  -p $PASSWORD \
  --tenant $TENANT_ID

# Run scripts without prompts
AZURE_DO_NOT_PROMPT=true ./common/cleanup-phase1.sh
```

### Custom VM Sizes

List available sizes:
```bash
az vm list-sizes -l eastus -o table
```

Use custom size:
```bash
AZURE_VM_SIZE=Standard_D2s_v3 ./ubuntu/create-linux-lab-vm.sh
```

### Custom Images

List available images:
```bash
az vm image list -o table | grep Ubuntu
```

Use custom image:
```bash
AZURE_VM_IMAGE=Ubuntu2204 ./ubuntu/create-linux-lab-vm.sh
```

## 📝 Script Features Comparison

| Feature | Old Scripts | New Scripts |
|---------|------------|-------------|
| Shared functions | ❌ Duplicated code | ✅ `az-common.sh` library |
| Idempotent | ❌ Fails if resources exist | ✅ Checks and skips existing |
| Location validation | ❌ No validation | ✅ Validates before creation |
| SSH key handling | ❌ Manual creation required | ✅ Auto-detects or creates |
| Error messages | ⚠️ Generic | ✅ Detailed with solutions |
| Colored output | ❌ Plain text | ✅ Color-coded by severity |
| Configurable | ❌ Edit scripts | ✅ Environment variables |
| Cleanup options | ❌ Always delete RG | ✅ Keep or delete RG |
| Progress feedback | ⚠️ Limited | ✅ Detailed status updates |
| Help text | ⚠️ Minimal | ✅ Comprehensive examples |

## 🤝 Contributing

To improve these scripts:

1. Maintain backward compatibility
2. Use `az-common.sh` for new shared functions
3. Add error handling for all Azure commands
4. Test idempotency (run multiple times)
5. Update this README with new features

## 📄 License

These scripts are part of the Azure DevOps Learn project and are licensed under the MIT License.

## 🔗 Related Documentation

- [Phase 1 Guide](../01-linux-basics-guide.md)
- [SSH Hardening Guide](../02-ssh-hardening-guide.md)
- [Azure VM Setup Guide](../03-azure-vm-setup-guide.md)
- [Ansible Guide](../04-ansible-guide.md)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Azure VM Documentation](https://docs.microsoft.com/azure/virtual-machines/)
