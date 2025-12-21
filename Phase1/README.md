# Phase 1: Linux Systems & Automation

> **Objective**: Operate Linux systems as production infrastructure, not personal machines.

## Learning Order

Start with these guides in order:

| Order | Guide | Topics |
|-------|-------|--------|
| 1 | `01-linux-basics-guide.md` | Linux fundamentals, shell scripting |
| 2 | `02-ssh-hardening-guide.md` | SSH security configuration |
| 3 | `03-azure-vm-setup-guide.md` | Azure VM creation |

After completing labs:
- Run `99-cleanup-guide.md` to clean up resources

## Quick Start

```bash
cd Phase1

# Start with Linux basics
less 01-linux-basics-guide.md

# When ready for SSH hardening
less 02-ssh-hardening-guide.md

# Set up Azure VM
less 03-azure-vm-setup-guide.md
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-ssh-hardening.sh` | Automated SSH hardening |
| `scripts/cleanup.sh` | Resource cleanup |

## Duration

- **4-6 hours** total

## Prerequisites

- Azure account
- Terminal access (macOS Terminal, Windows Terminal, WSL)

## After Phase 1

Proceed to [Phase 2: Git & Engineering Workflows](../Phase2/)