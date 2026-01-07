# Azure DevOps Engineer Professional Self-Study Guide

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Phases](https://img.shields.io/badge/Phases-7-blue.svg)](#phases)
[![Capstone](https://img.shields.io/badge/Capstone-Required-orange.svg)](#capstone-project)

---

## Table of Contents

- [Overview](#overview)
- [Learning Philosophy](#learning-philosophy)
- [Competency Framework](#competency-framework)
- [Getting Started](#getting-started)
- [Phases](#phases)
  - [Phase 1: Linux Systems & Automation](#phase-1-linux-systems--automation)
  - [Phase 2: Git & Engineering Workflows](#phase-2-git--engineering-workflows)
  - [Phase 3: Azure Fundamentals & Security](#phase-3-azure-fundamentals--security)
  - [Phase 4: Infrastructure as Code (Terraform)](#phase-4-infrastructure-as-code-terraform)
  - [Phase 5: CI/CD with GitHub Actions](#phase-5-cicd-with-github-actions)
  - [Phase 6: Containers & AKS](#phase-6-containers--aks)
  - [Phase 7: GitOps, Observability & Reliability](#phase-7-gitops-observability--reliability)
- [Capstone Project](#capstone-project)
- [Certification Alignment](#certification-alignment)
- [Professional Readiness](#professional-readiness)

---

## Overview

A comprehensive, hands-on learning path designed to develop **production-ready Azure DevOps Engineers**. This guide emphasizes engineering judgment, operational responsibility, and system thinking over tool memorization.

### Who This Is For

| Audience | Why This Guide |
|----------|----------------|
| Career Switchers | Entering cloud/DevOps roles from other fields |
| Junior Engineers | Seeking production experience beyond tutorials |
| Self-Taught Practitioners | Formalizing skills with structured learning |
| Interview Candidates | Preparing for Azure DevOps roles |
| Platform Engineers | Building DevOps expertise |

### What You'll Build

Real-world skills applicable to:
- Microsoft Azure DevOps Engineer Expert roles
- Platform Engineering positions
- Site Reliability Engineering (SRE) roles
- Cloud Operations teams

---

## Learning Philosophy

We follow **five core principles** that reflect real-world engineering responsibility:

1. **Practice Before Theory**
   - Learn by implementing first, understanding follows
   - Each concept has a hands-on lab

2. **Production Realism**
   - Labs mirror real infrastructure and failure modes
   - Experience actual operational challenges

3. **Security by Default**
   - Identity, access, and secrets treated as first-class concerns
   - Security integrated into every phase

4. **Operational Ownership**
   - Learners handle monitoring, failures, and recovery
   - Document procedures for future reference

5. **Explainability**
   - Every lab must be explainable to a technical interviewer
   - Build communication skills alongside technical skills

---

## Competency Framework

Upon completion, you'll demonstrate expertise in these domains:

| Domain | Core Capabilities |
|--------|-------------------|
| **Linux** | Secure system operation, troubleshooting, automation |
| **Git** | Collaborative workflows, branching strategies, history management |
| **Azure** | Cloud architecture, identity management, network security |
| **IaC** | Terraform, infrastructure versioning, module design |
| **CI/CD** | Pipeline automation, artifact management, deployment strategies |
| **Containers** | Docker, Kubernetes, AKS operations |
| **Reliability** | Monitoring, alerting, incident response |
| **Security** | Zero-trust design, least-privilege access, secrets management |

---

## Getting Started

### Prerequisites

- **Account**: Azure subscription (free tier works)
- **Hardware**: Computer with terminal access
- **Knowledge**: Basic command line familiarity
- **Time**: 2-4 hours per phase (self-paced)

### Initial Setup

```bash
# 1. Clone or download this repository
git clone https://github.com/your-org/azure-devops-learn.git
cd azure-devops-learn

# 2. Start with Phase 1
cd Phase1

# 3. Follow the guides in order
ls -la *.md
```

### Phase Structure

Each phase follows this format:

```
PhaseX/
├── scripts/              # Automation scripts & exercises
├── 01-linux-basics-guide.md # Main learning guide
└── cleanup-guide.md      # Resource cleanup (if applicable)
```

---

## Phases

### Phase 1: Linux Systems & Automation

> **Objective**: Operate Linux systems as production infrastructure, not personal machines.

| Aspect | Details |
|--------|---------|
| **Duration** | 4-6 hours |
| **Prerequisites** | Azure account, terminal access |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| File Management | Navigation, permissions, ownership, linking |
| User Administration | Users, groups, sudo, access control |
| Process Management | Monitoring, control, resource usage |
| Package Management | apt/yum, dependency handling |
| Shell Scripting | Variables, control flow, functions, error handling |
| System Administration | systemd, journalctl, log management |
| SSH Security | Hardening, key-based auth, access control |
| Configuration Management | Ansible, idempotent automation, playbook design |

#### Learning Content

| Guide | Topics |
|-------|--------|
| `01-linux-basics-guide.md` | Complete Linux fundamentals |
| `02-ssh-hardening-guide.md` | SSH security configuration |
| `03-azure-vm-setup-guide.md` | Azure VM creation |
| `04-ansible-guide.md` | Ansible configuration management |
| `05-azure-multi-vm-setup.md` | Multi-VM setup for Ansible multi-node testing |
| `99-cleanup-guide.md` | Resource cleanup |

#### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/common/01-ssh-hardening.sh` | Automated SSH hardening |
| `scripts/common/04-validate-ansible.sh` | Ansible validation |
| `scripts/ubuntu/create-multi-vms.sh` | Create 7 VMs for multi-node testing |
| `scripts/common/cleanup-phase1.sh` | All Phase 1 cleanup (single & multi-VM) |

#### Professional Deliverables

- [ ] Hardened Linux server with SSH key-only access
- [ ] System health check automation script
- [ ] Backup and log analysis scripts
- [ ] Documented troubleshooting runbook
- [ ] Ansible playbook for VM configuration
- [ ] Ansible inventory for development/production
- [ ] Multi-VM environment (7 VMs) for multi-node testing
- [ ] Multi-tier Ansible playbook (web, app, db tiers)

#### Interview Topics

- Difference between systemd and init systems
- How exit codes affect automation
- Troubleshooting high CPU/memory
- Securing a Linux server
- Hard vs soft links

---

### Phase 2: Git & Engineering Workflows

> **Objective**: Work safely in collaborative, multi-engineer environments.

| Aspect | Details |
|--------|---------|
| **Duration** | 4-6 hours |
| **Prerequisites** | Phase 1 complete, GitHub account |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Repository Management | Initialization, structure, .gitignore |
| Branching Strategies | Feature branches, GitHub Flow, trunk-based |
| Commit Hygiene | Conventional commits, clean history |
| Pull Requests | Reviews, iterations, merge strategies |
| Conflict Resolution | Merge vs rebase, conflict handling |
| CI/CD Integration | GitHub Actions, automated validation |

#### Learning Content

| Guide | Topics |
|-------|--------|
| `01-git-workflows-guide.md` | Complete Git workflow guide |

#### Professional Deliverables

- [ ] Git repository with branch protection rules
- [ ] At least 5 merged pull requests with conventional commits
- [ ] GitHub Actions PR validation workflow
- [ ] Documented team Git workflow runbook

#### Interview Topics

- Why PRs reduce deployment risk
- How Git history supports audits
- When to rebase vs merge
- Preventing broken main branches
- Handling merge conflicts

---

### Phase 3: Azure Fundamentals & Security

> **Objective**: Design secure, identity-first Azure environments using modern zero-trust principles.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 2 complete, Azure subscription |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Resource Organization | Management groups, subscriptions, resource groups, naming conventions |
| Network Security | VNets, subnets, NSGs, Private Endpoints, Service Endpoints, Network Security Perimeters |
| Identity Management | Azure AD, RBAC, Privileged Identity Management (PIM), Microsoft Entra ID |
| Secrets Management | Key Vault with RBAC, Managed Identities, access policies |
| Monitoring | Azure Monitor, Log Analytics, Azure Sentinel, diagnostic settings |
| Security Governance | Azure Policy, Microsoft Defender for Cloud, compliance frameworks |

#### Learning Content

| Guide | Topics |
|-------|--------|
| `Phase3/01-azure-identity-guide.md` | Identity architecture, RBAC best practices, Managed Identity implementation |
| `Phase3/02-azure-network-security.md` | VNet design, NSG rules, Private Endpoint configuration, Network Security Perimeters |
| `Phase3/03-azure-keyvault-guide.md` | Secret management, Key Vault RBAC, integration patterns |
| `Phase3/04-azure-monitoring-guide.md` | Log Analytics, Azure Monitor, alerting strategies |

#### Professional Deliverables

- [ ] Azure landing zone with management group hierarchy
- [ ] VNet with subnets secured by NSGs and Private Endpoints
- [ ] Key Vault with RBAC-based access and Managed Identity integration
- [ ] Azure Policy assignments for security compliance
- [ ] Log Analytics workspace with diagnostic settings
- [ ] Documented security architecture runbook

#### 2025 Azure Security Best Practices

**Identity & Access Management:**
- Use **Microsoft Entra ID** (formerly Azure AD) as the identity provider
- Implement **Privileged Identity Management (PIM)** for just-in-time access
- Prefer **RBAC over Azure AD roles** for resource access control
- Use **user-assigned managed identities** for cross-resource scenarios (recommended by Microsoft)
- Apply **least-privilege** principles - start with Reader, escalate only when needed

**Network Security:**
- Use **Private Endpoints** over Service Endpoints for critical resources
- Deploy **Network Security Groups (NSGs)** at subnet and NIC levels
- Implement **Network Security Perimeters** for enhanced micro-segmentation (2025 feature)
- Disable **public network access** on PaaS resources where possible
- Use **Azure Firewall** or **Azure DDoS Protection** for perimeter security

**Secrets Management:**
- Store all secrets, keys, and certificates in **Azure Key Vault**
- Use **Key Vault RBAC** model (not legacy access policies)
- Enable **Key Vault soft-delete** and purge protection
- Integrate **Managed Identities** for application authentication
- Use **Azure Key Vault references** for App Service/Container Apps

**Monitoring & Compliance:**
- Create **Log Analytics workspaces** per business unit or environment
- Use **diagnostic settings** to forward logs to Log Analytics
- Enable **Microsoft Defender for Cloud** tier
- Implement **Azure Policy** for guardrails and compliance
- Configure **alert rules** for security events

#### Interview Topics

| Question | Key Points |
|----------|------------|
| Why Managed Identity over secrets? | No credential management, automatic rotation, no secrets in code |
| Private Endpoint vs Service Endpoint | PE: resource-level access, NSG can't filter; SE: subnet-level, NSG compatible |
| RBAC vs Azure AD roles | RBAC for Azure resources, Azure AD roles for directory management |
| Network Security Perimeter | New 2025 feature for traffic filtering across VNets and Private Endpoints |
| Zero-trust implementation | Verify explicitly, use least privilege, assume breach |
| Preventing credential leakage | Key Vault, Managed Identities, scan repos, Microsoft Defender |

---

### Phase 4: Infrastructure as Code (Terraform)

> **Objective**: Treat infrastructure as versioned, reviewable software using modern Terraform patterns with AzureRM v4.x.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 3 complete, Azure subscription with owner access |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Provider Configuration | AzureRM v4.x, version constraints, OIDC auth |
| Authentication | Managed Identity (no service principals) |
| State Management | Remote backend with Blob Storage + state locking |
| Resource Management | RG, VNet, NSG, Private Endpoints |
| Secrets Management | Key Vault integration, RBAC access |
| Module Design | Reusable, parameterized modules |

#### Learning Content

| Guide | Topics |
|-------|--------|
| `Phase4/01-terraform-basics-provider.md` | Provider setup, Managed Identity auth, AzureRM v4.x |
| `Phase4/02-remote-state-backend.md` | Blob Storage backend with state locking |
| `Phase4/03-azure-resources.md` | Resource Groups, VNets, NSGs, Private Endpoints |
| `Phase4/04-keyvault-monitoring.md` | Key Vault, Managed Identities, monitoring integration |

#### Professional Deliverables

- [ ] AzureRM provider v4.x configuration with OIDC authentication
- [ ] Remote backend (Blob Storage) with state locking
- [ ] Resource Groups, VNets, subnets via Terraform
- [ ] NSGs with security rules and service tags
- [ ] Private Endpoints and Private DNS Zones
- [ ] Key Vault with RBAC and secrets
- [ ] User-assigned Managed Identities
- [ ] Log Analytics workspace with diagnostic settings
- [ ] Reusable module structure

#### 2025 Terraform Best Practices

**Provider & Authentication:**
- Use **AzureRM Provider v4.x** with Terraform 1.x
- Prefer **Managed Identity/OIDC** over service principals
- Use `use_oidc = true` in provider configuration
- Set explicit version constraints (`~> 4.0`)

**State Management:**
- Use **Azure Blob Storage** as remote backend
- Enable **state locking** via blob leases
- Separate state by environment (dev/stg/prod)
- Enable **blob versioning** for recovery

**Module Design:**
- Create reusable modules for common patterns
- Use `count` or `for_each` for multiple instances
- Implement `depends_on` for implicit dependencies
- Use `lifecycle` blocks for resource protection

**Security:**
- Use **Key Vault** for secrets (not tfvars)
- Enable **soft-delete** and **purge protection**
- Use **Private Endpoints** for PaaS resources
- Implement **least privilege** with RBAC

#### Interview Topics

| Question | Key Points |
|----------|------------|
| Why Managed Identity over service principals? | No secrets, automatic rotation, works on Azure VMs |
| How does Azure Blob Storage provide state locking? | Blob leases prevent concurrent modifications |
| What's the difference between local and remote state? | Remote enables collaboration, locking, durability |
| How do you recover from corrupted state? | Versioning, import command, refresh |
| Why use Private Endpoints in Terraform? | Keep traffic on Azure backbone, security compliance |

---

### Phase 5: CI/CD with GitHub Actions

> **Objective**: Automate builds and deployments safely and audibly.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 4 complete |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Pipeline Design | YAML workflows, triggers, jobs |
| Authentication | GitHub tokens, OIDC |
| Artifact Management | Build artifacts, versioning |
| Deployment Strategies | Blue/green, rolling, canary |
| Security | Secret scanning, dependency review |

#### Interview Topics

- Pipeline trigger mechanisms
- Secret protection in workflows
- Handling deployment failures
- CI/CD risk reduction
- Artifact traceability

---

### Phase 6: Containers & AKS

> **Objective**: Operate containerized workloads in production.

| Aspect | Details |
|--------|---------|
| **Duration** | 8-10 hours |
| **Prerequisites** | Phase 5 complete |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Docker | Images, containers, Dockerfile best practices |
| Kubernetes | Pods, services, deployments, configmaps |
| AKS | Cluster management, node pools, Azure integration |
| Resource Management | Limits, requests, autoscaling |
| Networking | Ingress, service types, network policies |

#### Interview Topics

- AKS managed vs user-managed components
- Kubernetes scheduling mechanics
- Why resource limits matter
- Service exposure patterns
- Container security best practices

---

### Phase 7: GitOps, Observability & Reliability

> **Objective**: Own systems after deployment.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 6 complete |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| GitOps | ArgoCD/Flux, declarative deployments |
| Monitoring | Metrics, logs, traces |
| Alerting | Alert rules, notification channels |
| Incident Response | Detection, escalation, resolution |
| Reliability | SLOs, SLIs, error budgets |

#### Interview Topics

- GitOps operational benefits
- Alert design principles
- Incident response procedures
- Reliability improvement strategies
- Postmortem culture

---

## Capstone Project

The capstone demonstrates **end-to-end DevOps ownership** by combining all phase skills.

### Requirements

| Component | Description |
|-----------|-------------|
| **Infrastructure** | Terraform-managed Azure resources |
| **CI/CD** | GitHub Actions pipeline |
| **Containers** | AKS-deployed workloads |
| **GitOps** | Declarative deployment pattern |
| **Observability** | Monitoring and alerting |
| **Security** | Key Vault, Managed Identity |

### Deliverables

| Deliverable | Format |
|-------------|--------|
| Architecture Diagram | Draw.io/png/svg |
| Deployment Runbook | Markdown document |
| Incident Response Guide | Markdown document |
| Postmortem Example | Markdown document |

### Evaluation Criteria

- [ ] Infrastructure provisions successfully from scratch
- [ ] Pipeline runs without manual intervention
- [ ] Application accessible and healthy
- [ ] Monitoring captures key metrics
- [ ] Documentation is clear and complete

---

## Certification Alignment

This guide prepares for these certifications:

| Certification | Primary Coverage |
|--------------|------------------|
| [Azure Fundamentals (AZ-900)](https://learn.microsoft.com/certifications/azure-fundamentals/) | Phases 1-3 |
| [Azure Administrator (AZ-104)](https://learn.microsoft.com/certifications/azure-administrator/) | Phases 1-4, 6 |
| [Azure DevOps Engineer (AZ-400)](https://learn.microsoft.com/certifications/azure-devops-engineer/) | Phases 2, 4-7 |
| [Terraform Associate](https://www.hashicorp.com/certification/terraform-associate) | Phase 4 |
| [Kubernetes Administrator (CKA)](https://www.cncf.io/certification/cka/) | Phase 6 |

---

## Professional Readiness

You are ready for Azure DevOps roles when you can:

### Technical Skills

- [ ] Rebuild environments from scratch without assistance
- [ ] Explain architectural tradeoffs in your designs
- [ ] Diagnose production failures confidently
- [ ] Implement security by default
- [ ] Write clean, maintainable code

### Soft Skills

- [ ] Communicate clearly with engineers
- [ ] Document procedures for operators
- [ ] Present solutions to stakeholders
- [ ] Collaborate on shared goals
- [ ] Learn new technologies independently

---

## Contributing

This is a self-study guide. To suggest improvements:

1. Open an issue with your suggestion
2. Or submit a pull request with changes
3. Include rationale and examples

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Microsoft Learn documentation
- Azure Well-Architected Framework
- CNCF Kubernetes documentation
- HashiCorp Terraform guides
- GitHub Actions documentation

---

**Start your journey →** [Phase 1: Linux Systems & Automation](Phase1/)

---

*This guide is intentionally demanding, reflecting real engineering responsibility rather than classroom exercises. Completing it demonstrates capability, not just attendance.*
