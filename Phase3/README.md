# Phase 3: Azure Fundamentals & Security

> **Objective**: Design secure, identity-first Azure environments using modern zero-trust principles.

## Learning Order

Complete these guides in order:

| Order | Guide | Topics |
|-------|-------|--------|
| 1 | `01-azure-identity-guide.md` | Identity architecture, RBAC, Managed Identities |
| 2 | `02-azure-network-security.md` | VNets, NSGs, Private Endpoints |
| 3 | `03-azure-keyvault-guide.md` | Secrets management, Key Vault RBAC |
| 4 | `04-azure-monitoring-guide.md` | Log Analytics, alerts, dashboards |

## Quick Start

```bash
cd Phase3

# Start with identity
less 01-azure-identity-guide.md

# Then networking
less 02-azure-network-security.md

# Key Vault
less 03-azure-keyvault-guide.md

# Monitoring
less 04-azure-monitoring-guide.md
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-validate-phase3.sh` | Validates all Phase 3 resources |
| `scripts/02-cleanup-phase3.sh` | Deletes all Phase 3 resources |
| `scripts/03-keyvault-access.sh` | Demo: secure secret retrieval |

## Duration

- **6-8 hours** total

## Prerequisites

- Phase 2 complete
- Azure subscription (free tier works)

## Core Competencies

| Skill | Description |
|-------|-------------|
| Resource Organization | Management groups, subscriptions, resource groups |
| Network Security | VNets, NSGs, Private Endpoints, Network Security Perimeters |
| Identity Management | RBAC, Managed Identities, PIM, Microsoft Entra ID |
| Secrets Management | Key Vault RBAC, access policies |
| Monitoring | Azure Monitor, Log Analytics, diagnostic settings |

## Deliverables

- [ ] Azure landing zone with management group hierarchy
- [ ] VNet with subnets secured by NSGs and Private Endpoints
- [ ] Key Vault with RBAC-based access and Managed Identity integration
- [ ] Azure Policy assignments for security compliance
- [ ] Log Analytics workspace with diagnostic settings
- [ ] Documented security architecture runbook

## After Phase 3

Proceed to [Phase 4: Infrastructure as Code (Terraform)](../Phase4/)