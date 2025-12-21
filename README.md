### Overview
This is the "Azure DevOps Engineer Professional Self-Study Learning Guide," aligned with global industry standards. It's designed to develop production-ready Azure DevOps Engineers through hands-on, outcome-driven practice, emphasizing engineering judgment, operational responsibility, and system thinking rather than tool memorization. The guide aligns with Microsoft Azure DevOps Engineer Expert expectations, real-world DevOps and Platform Engineering roles, and international hiring standards in North America, Europe, and APAC.

No prior cloud experience is required. It's targeted at career switchers entering cloud or DevOps roles, junior engineers seeking production experience, self-taught practitioners formalizing skills, and engineers preparing for Azure DevOps interviews.

### Learning Philosophy
The guide follows five core principles:
1. **Practice before theory**: Concepts are learned through implementation first.
2. **Production realism**: Labs mirror real infrastructure, pipelines, and failure modes.
3. **Security by default**: Identity, access, and secrets are treated as first-class concerns.
4. **Operational ownership**: Learners handle monitoring, failures, and recovery.
5. **Explainability**: Every lab must be explainable to a technical interviewer.

### Competency Framework
By completing the guide, learners demonstrate competence in these domains:

| Domain      | Capability                              |
|-------------|-----------------------------------------|
| Linux       | Secure system operation and troubleshooting |
| Git         | Collaborative engineering workflows     |
| Azure       | Secure cloud architecture and identity  |
| IaC         | Reproducible infrastructure with Terraform |
| CI/CD       | Automated pipelines using GitHub Actions |
| Containers  | Docker and Kubernetes operations       |
| Reliability | Monitoring, alerting, and incident response |
| Security    | Identity-first, least-privilege design  |

### Guide Structure
Each phase includes:
- Learning objectives
- Hands-on labs
- Validation criteria
- Professional deliverables
- Interview reinforcement

### Phases
The guide is divided into 7 phases, each building on the previous, plus a capstone project.

#### Phase 1: Linux Systems & Automation
- **Professional Objective**: Operate Linux systems as production infrastructure, not personal machines.
- **Core Competencies**: Secure access control, service lifecycle management, log-driven troubleshooting, safe automation practices.
- **Professional Deliverables**: Hardened Linux server, troubleshooting runbook, Bash automation scripts.
- **Industry Alignment**: RHCSA fundamentals, cloud VM operational expectations.
- **Interview Reinforcement**: Explain why SSH hardening is mandatory, how systemd differs from init systems, how exit codes affect automation, how you diagnose production outages.

#### Phase 2: Git & Engineering Workflows
- **Professional Objective**: Work safely in collaborative, multi-engineer environments.
- **Core Competencies**: Branching strategies, pull request discipline, conflict resolution, change traceability.
- **Professional Deliverables**: Clean Git history, documented PR workflow, conflict resolution examples.
- **Industry Alignment**: GitHub Flow, trunk-based development.
- **Interview Reinforcement**: Explain why PRs reduce deployment risk, how Git history supports audits, when to rebase vs merge, how teams prevent broken main branches.

#### Phase 3: Azure Fundamentals & Security
- **Professional Objective**: Design secure, identity-first Azure environments.
- **Core Competencies**: Resource organization, network isolation, identity and access management, secrets handling.
- **Professional Deliverables**: Secure VNet architecture, Managed Identity integration, Key Vault usage documentation.
- **Industry Alignment**: Azure Well-Architected Framework, zero-trust principles.
- **Interview Reinforcement**: Explain why Managed Identity is preferred over secrets, how Azure networking isolates workloads, how RBAC differs from traditional IAM, how you prevent credential leakage.

#### Phase 4: Infrastructure as Code (Terraform)
- **Professional Objective**: Treat infrastructure as versioned, reviewable software.
- **Core Competencies**: Remote state management, modular design, environment separation, drift detection.
- **Professional Deliverables**: Terraform modules, remote state backend, environment promotion strategy.
- **Industry Alignment**: Terraform best practices, GitOps-compatible IaC workflows.
- **Interview Reinforcement**: Explain why remote state is critical, how Terraform detects drift, how you manage breaking changes, how IaC improves reliability.

#### Phase 5: CI/CD with GitHub Actions
- **Professional Objective**: Automate builds and deployments safely and audibly.
- **Core Competencies**: Declarative pipelines, secure authentication, artifact traceability, failure handling.
- **Professional Deliverables**: GitHub Actions workflows, Terraform automation pipelines, deployment logs.
- **Industry Alignment**: GitHub Actions enterprise usage, CI/CD security best practices.
- **Interview Reinforcement**: Explain how pipelines are triggered, how secrets are protected, how failures are handled, why CI/CD reduces risk.

#### Phase 6: Containers & AKS
- **Professional Objective**: Operate containerized workloads in production.
- **Core Competencies**: Container image hygiene, Kubernetes scheduling, resource management, service exposure.
- **Professional Deliverables**: AKS cluster, deployed application, resource-limited workloads.
- **Industry Alignment**: CNCF Kubernetes fundamentals, cloud-native application patterns.
- **Interview Reinforcement**: Explain what AKS manages vs what you manage, how Kubernetes schedules pods, why resource limits matter, how services expose applications.

#### Phase 7: GitOps, Observability & Reliability
- **Professional Objective**: Own systems after deployment.
- **Core Competencies**: Declarative deployments, monitoring and alerting, incident response, postmortem culture.
- **Professional Deliverables**: GitOps deployment, dashboards and alerts, incident simulation report.
- **Industry Alignment**: SRE principles, GitOps workflows.
- **Interview Reinforcement**: Explain what GitOps solves, how alerts differ from logs, how you respond to incidents, how reliability is improved over time.

### Capstone Project
- **Professional Objective**: Demonstrate end-to-end DevOps ownership.
- **Capstone Requirements**: Terraform-managed Azure infrastructure, GitHub Actions CI/CD, AKS workloads, GitOps deployment, monitoring and alerting, secure secrets management.
- **Required Documentation**: Architecture diagram, deployment runbooks, incident response guide, postmortem example.

### Definition of Professional Readiness
You are ready for Azure DevOps roles when you can:
- Rebuild environments from scratch
- Explain architectural tradeoffs
- Diagnose failures confidently
- Secure systems by default
- Communicate clearly with engineers and stakeholders

### Certification Alignment
This guide prepares for:
- Microsoft Certified: Azure Fundamentals
- Microsoft Certified: Azure Administrator Associate
- Microsoft Certified: Azure DevOps Engineer Expert
- Terraform Certified Associate
- Certified Kubernetes Administrator (CKA)

### Closing Note
The guide is intentionally demanding, reflecting real engineering responsibility rather than classroom exercises. Completing it demonstrates capability, not just attendance.
