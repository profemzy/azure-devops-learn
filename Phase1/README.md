# Phase 1: Linux Systems & Automation

> **Objective**: Operate Linux systems as production infrastructure, not personal machines.

## Learning Order

Start with these guides in order:

| Order | Guide | Topics |
|-------|-------|--------|
| 1 | `01-linux-basics-guide.md` | Linux fundamentals, shell scripting |
| 2 | `02-ssh-hardening-guide.md` | SSH security configuration |
| 3 | `03-azure-vm-setup-guide.md` | Azure VM creation |
| 4 | `04-ansible-guide.md` | Ansible configuration management |
| 5 | `05-azure-multi-vm-setup.md` | Multi-VM setup for Ansible testing |

After completing labs:
- Run `99-cleanup-guide.md` to clean up resources

## Quick Start

```bash
cd Phase1

# Step 1: Linux basics
less 01-linux-basics-guide.md

# Step 2: SSH hardening
less 02-ssh-hardening-guide.md

# Step 3: Single VM setup
less 03-azure-vm-setup-guide.md

# Step 4: Ansible configuration management
less 04-ansible-guide.md

# Step 5: Multi-VM setup (optional - for multi-node testing)
less 05-azure-multi-vm-setup.md

# When done: Clean up resources
less 99-cleanup-guide.md
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-ssh-hardening.sh` | Automated SSH hardening |
| `scripts/04-validate-ansible.sh` | Ansible validation |
| `scripts/create-multi-vms.sh` | Create 7 VMs for multi-node testing |
| `scripts/cleanup.sh` | All Phase 1 cleanup (single & multi-VM) |

## Duration

- **4-6 hours** total

## Prerequisites

- Azure account
- Terminal access (macOS Terminal, Windows Terminal, WSL)

## After Phase 1

Proceed to [Phase 2: Git & Engineering Workflows](../Phase2/)