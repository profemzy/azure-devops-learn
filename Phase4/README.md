# Phase 4: Infrastructure as Code (Terraform)

> **Objective**: Treat infrastructure as versioned, reviewable software using modern Terraform patterns.

## Learning Order

Complete these guides in order:

| Order | Guide | Topics |
|-------|-------|--------|
| 1 | `01-terraform-basics-provider.md` | Provider setup, Managed Identity auth, AzureRM v4.x |
| 2 | `02-remote-state-backend.md` | Blob Storage backend with state locking |
| 3 | `03-azure-resources.md` | Resource Groups, VNets, NSGs, Private Endpoints |
| 4 | `04-keyvault-monitoring.md` | Key Vault, Managed Identities, monitoring integration |

## Quick Start

```bash
cd Phase4

# Start with basics
less 01-terraform-basics-provider.md
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-validate-phase4.sh` | Validates Terraform configuration |
| `scripts/02-cleanup-phase4.sh` | Deletes all Phase 4 resources |
| `scripts/03-plan-apply.sh` | Safe apply with plan review |

## Duration

- **6-8 hours** total

## Prerequisites

- Phase 3 complete
- Azure subscription with owner access
- Terraform installed (`terraform version` >= 1.0)
- Azure CLI installed (`az version`)

## Core Competencies

| Skill | Description |
|-------|-------------|
| Provider Configuration | AzureRM v4.x, version constraints |
| Authentication | Managed Identity (no service principals) |
| State Management | Remote backend with Blob Storage + locking |
| Resource Management | RG, VNet, NSG, Private Endpoints |
| Secrets Management | Key Vault integration, Azure Key Vault provider |
| Module Design | Reusable, parameterized modules |

## Terraform Version

This phase uses **Terraform 1.x** with **AzureRM Provider 4.x**:

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

  required_version = ">= 1.0.0"
}
```

## Authentication Method

**Managed Identity** is the recommended authentication method for Terraform in production:

```bash
# Enable on your machine (Azure VM or use Azure CLI)
az login --identity
```

## After Phase 4

Proceed to [Phase 5: CI/CD with GitHub Actions](../Phase5/)