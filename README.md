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
├── Xxxx-xxxx-guide.md    # Main learning guide
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

#### Learning Content

| Guide | Topics |
|-------|--------|
| `linux-basics-guide.md` | Complete Linux fundamentals |
| `ssh-hardening-guide.md` | SSH security configuration |
| `azure-vm-setup-guide.md` | Azure VM creation |
| `cleanup-guide.md` | Resource cleanup |

#### Professional Deliverables

- [ ] Hardened Linux server with SSH key-only access
- [ ] System health check automation script
- [ ] Backup and log analysis scripts
- [ ] Documented troubleshooting runbook

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
| `git-workflows-guide.md` | Complete Git workflow guide |

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

> **Objective**: Design secure, identity-first Azure environments.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 2 complete |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Resource Organization | Resource groups, naming conventions |
| Network Security | VNets, subnets, NSGs, private endpoints |
| Identity Management | Azure AD, RBAC, Managed Identities |
| Secrets Management | Key Vault, environment variables |
| Monitoring | Azure Monitor, Log Analytics |

#### Interview Topics

- Why Managed Identity is preferred over secrets
- Azure networking isolation mechanisms
- RBAC vs traditional IAM
- Preventing credential leakage
- Zero-trust implementation

---

### Phase 4: Infrastructure as Code (Terraform)

> **Objective**: Treat infrastructure as versioned, reviewable software.

| Aspect | Details |
|--------|---------|
| **Duration** | 6-8 hours |
| **Prerequisites** | Phase 3 complete |

#### Core Competencies

| Skill | Description |
|-------|-------------|
| Terraform Basics | Providers, resources, state |
| Module Design | Reusable, parameterized modules |
| State Management | Remote backends, locking |
| Environment Strategy | Dev/staging/production separation |
| Drift Detection | Identifying configuration drift |

#### Interview Topics

- Why remote state is critical
- Terraform drift detection
- Managing breaking changes
- How IaC improves reliability
- State file security

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
