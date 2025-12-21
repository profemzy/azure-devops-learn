# Phase 2: Git & Engineering Workflows Guide

This guide covers collaborative Git workflows, branching strategies, and engineering best practices for multi-developer environments.

---

## Table of Contents

1. [Overview](#overview)
2. [Lab 2.1: Initialize Git Repository](#lab-21-initialize-git-repository)
3. [Lab 2.2: Feature Branch Workflow](#lab-22-feature-branch-workflow)
4. [Lab 2.3: Commit Message Conventions](#lab-23-commit-message-conventions)
5. [Lab 2.4: Merge vs Rebase Strategies](#lab-24-merge-vs-rebase-strategies)
6. [Lab 2.5: Conflict Resolution](#lab-25-conflict-resolution)
7. [Lab 2.6: PR Validation with GitHub Actions](#lab-26-pr-validation-with-github-actions)
8. [Professional Deliverables](#professional-deliverables)
9. [Interview Reinforcement](#interview-reinforcement)

---

## Overview

### Learning Objectives

| Objective | Description |
|-----------|-------------|
| Safe Collaboration | Work in multi-engineer environments without breaking main |
| Branch Discipline | Use feature branches with proper lifecycle management |
| Clean History | Maintain readable, audit-friendly commit history |
| Conflict Resolution | Handle merge conflicts confidently |
| Automated Validation | Prevent broken code from entering main |

### Prerequisites

- Git installed locally (`git --version`)
- GitHub account
- Azure VM from Phase 1 (or local environment)

---

## Lab 2.1: Initialize Git Repository

### Why This Matters

A properly initialized repo sets the foundation for collaboration. Poor initial setup leads to:
- Sensitive data committed accidentally
- Unclear project structure
- No audit trail for changes

### Step 1: Create Repository Structure

```bash
# Create project directory
mkdir -p ~/devops-learn-phase2
cd ~/devops-learn-phase2

# Initialize git repo
git init
```

**Expected Output:**
```
Initialized empty Git repository in /Users/username/devops-learn-phase2/.git/
```

### Step 2: Create Professional `.gitignore`

```bash
# Create comprehensive .gitignore
cat > .gitignore << 'EOF'
# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Azure & Secrets
*.pem
*.pub
*.key
*.crt
*.pfx
!*.example
.env
.secrets/

# Logs
*.log
*.log.*

# Build outputs
build/
dist/
*.egg-info/
__pycache__/
node_modules/

# Temporary files
*.tmp
*.bak
*~
EOF

# Stage and commit
git add .gitignore
git commit -m "docs: add professional .gitignore"
```

**Expected Outcome:** `.gitignore` committed with descriptive message

### Step 3: Create Project Structure

```bash
# Create directory structure
mkdir -p src tests docs scripts

# Create initial files
echo "# DevOps Learning Project" > README.md
echo 'print("Hello, DevOps!")' > src/main.py
echo "# Placeholder" > tests/test_main.py

# Add and commit
git add .
git commit -m "init: project structure"
```

### Step 4: Create Branch Protection Rules

**On GitHub:**

1. Go to Repository → Settings → Branches
2. Click "Add rule"
3. Apply to `main` branch
4. Configure:
   - [x] Require pull request reviews before merging
   - [ ] Number of reviewers: 1
   - [x] Require status checks to pass before merging
   - [x] Include administrators

```bash
# Verify branch protection (requires GitHub CLI or web UI)
gh api repos/:owner/:repo/branches/main/protection 2>/dev/null || echo "Use GitHub Web UI"
```

### Step 5: Verify Initial State

```bash
# Check git status
git status

# View commit history
git log --oneline --graph --all

# List branches
git branch -a
```

**Expected Outcome:**
```
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

---

## Lab 2.2: Feature Branch Workflow

### Why This Matters

Feature branches isolate work and enable:
- Parallel development
- Code review before integration
- Easy rollback of incomplete work
- Clear ownership of changes

### Step 1: Create a Feature Branch

```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create feature branch with naming convention
# Format: type/short-description (e.g., feature/login, fix/api-bug)
git checkout -b feature/add-configuration

# Verify branch
git branch
```

**Expected Output:**
```
  main
* feature/add-configuration
```

### Step 2: Make Changes on Feature Branch

```bash
# Create new feature file
cat > src/config.py << 'EOF'
"""Configuration management module."""

import os


class Config:
    """Application configuration."""

    @staticmethod
    def get_database_url() -> str:
        """Get database connection URL."""
        return os.getenv("DATABASE_URL", "sqlite:///default.db")

    @staticmethod
    def get_debug_mode() -> bool:
        """Check if debug mode is enabled."""
        return os.getenv("DEBUG", "false").lower() == "true"


if __name__ == "__main__":
    print(f"Database: {Config.get_database_url()}")
    print(f"Debug: {Config.get_debug_mode()}")
EOF

# Stage and commit
git add src/config.py
git commit -m "feat: add configuration management module"
```

### Step 3: Push Branch to Remote

```bash
# Push feature branch
git push -u origin feature/add-configuration

# Verify on GitHub
gh repo view --web
```

**Expected:** Feature branch visible on GitHub

### Step 4: Create Pull Request

```bash
# Create PR using GitHub CLI
gh pr create \
  --title "feat: add configuration management module" \
  --body "## Summary
- Added Config class with database and debug settings
- Uses environment variables with sensible defaults

## Testing
- Verified locally with python src/config.py

## Checklist
- [x] Code follows project style
- [x] Tests pass
- [x] Documentation updated" \
  --base main
```

**Or via Web UI:**
1. Navigate to repository on GitHub
2. Click "Compare & pull request"
3. Fill in PR template
4. Request reviewers

### Step 5: Review and Merge PR

```bash
# View PR details
gh pr view 1

# Add review comment
gh pr review 1 --approve --body "LGTM! Clean implementation."

# Merge PR
gh pr merge 1 --squash --delete-branch
```

### Step 6: Update Local Main

```bash
# Switch to main and pull changes
git checkout main
git pull origin main

# Verify merge
git log --oneline -5
```

---

## Lab 2.3: Commit Message Conventions

### Why This Matters

Good commit messages:
- Enable quick code review
- Support审计 (audit) and compliance
- Help with bug hunting
- Make rollback easier

### Conventional Commits Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Common Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(api): add user endpoint` |
| `fix` | Bug fix | `fix(auth): resolve token expiry` |
| `docs` | Documentation only | `docs: update README` |
| `style` | Formatting changes | `style: fix indentation` |
| `refactor` | Code restructuring | `refactor(config): simplify loading` |
| `test` | Test changes | `test: add unit tests for auth` |
| `chore` | Maintenance | `chore: update dependencies` |

### Step 1: Configure Commit Template

```bash
# Create commit template
cat > ~/.gitmessage << 'EOF'
# Type: feat, fix, docs, style, refactor, test, chore
# <type>(<scope>): <subject>

# Why this change?
[body]

# Breaking changes, references, tickets
[footer]
EOF

# Configure git to use template
git config --global commit.template ~/.gitmessage

# Verify
git config --global --get commit.template
```

### Step 2: Make Conventional Commits

```bash
# Create feature branch
git checkout -b chore/setup-linting

# Add linter configuration
cat > .pylintrc << 'EOF'
[MASTER]
disable=missing-docstring,line-too-long
EOF

# Commit with proper format
git add .pylintrc
git commit -m "chore: add pylint configuration for code quality"

# Make another commit with scope
git add src/config.py
git commit -m "feat(config): support YAML configuration files"

# View commit history
git log --oneline
```

**Expected Output:**
```
a1b2c3d chore: add pylint configuration for code quality
d4e5f6g feat(config): support YAML configuration files
...
```

### Step 3: Use Interactive Rebase to Fix History

```bash
# Rebase last 3 commits interactively
git rebase -i HEAD~3

# Options in editor:
# - pick: keep commit as-is
# - reword: change commit message
# - squash: combine with previous
# - drop: remove commit
```

### Step 4: Create Useful Commit Messages

**Bad:**
```
git commit -m "fixed stuff"
git commit -m "update"
git commit -m "wip"
```

**Good:**
```
git commit -m "fix: resolve null pointer in user lookup"
git commit -m "feat(auth): implement JWT token refresh"
git commit -m "docs: add setup instructions to README"
git commit -m "refactor(api): extract validation to separate module"
```

---

## Lab 2.4: Merge vs Rebase Strategies

### Why This Matters

| Strategy | Pros | Cons | When to Use |
|----------|------|------|-------------|
| **Merge** | Preserves history, clear branch points | Creates merge commits, can clutter history | Long-lived branches, team collaboration |
| **Rebase** | Clean linear history, no merge commits | Rewrites history (dangerous on shared) | Short-lived feature branches, personal work |
| **Squash Merge** | Compresses changes, clean main | Loses individual commit history | Feature branches with many small commits |

### Step 1: Merge Strategy (Team Collaboration)

```bash
# Create and switch to feature branch
git checkout main
git pull origin main
git checkout -b feature/report-module

# Make multiple commits
echo "# Report Module" > docs/report.md
git add docs/report.md
git commit -m "docs: add report documentation"

# Implement feature
cat > src/report.py << 'EOF'
"""Report generation module."""


def generate_report(data: dict) -> str:
    """Generate a simple report."""
    return f"Report: {data.get('title', 'Untitled')}"
EOF
git add src/report.py
git commit -m "feat(report): add report generation function"

# Add tests
cat > tests/test_report.py << 'EOF'
"""Tests for report module."""
from src.report import generate_report


def test_generate_report():
    """Test basic report generation."""
    result = generate_report({"title": "Test"})
    assert "Test" in result
EOF
git add tests/test_report.py
git commit -m "test(report): add unit tests"

# Switch to main and merge (no fast-forward)
git checkout main
git merge --no-ff feature/report-module -m "merge: integrate report module

- Add report generation function
- Add unit tests
- Add documentation"

# Verify history
git log --oneline --graph
```

### Step 2: Rebase Strategy (Personal Branches)

```bash
# Create feature branch
git checkout main
git pull origin main
git checkout -b feature/api-endpoint

# Make commits
echo '{"endpoints": []}' > src/api.json
git add src/api.json
git commit -m "feat(api): add endpoints placeholder"

# Before merging, rebase onto latest main
git fetch origin
git rebase origin/main

# Resolve conflicts if any, then push
git push -f origin feature/api-endpoint
```

### Step 3: Squash Merge for Small Features

```bash
# When feature is complete, squash all commits
git checkout main
git merge --squash feature/small-feature

# Commit with consolidated message
git commit -m "feat(user): add user profile management

- Implement profile view
- Add profile update endpoint
- Include validation"

# Delete feature branch
git branch -d feature/small-feature
```

### Step 4: Configure Default Merge Strategy

```bash
# Set merge squash as default for specific branch
git config branch.main.mergeoptions "--squash"

# Or configure globally
git config --global merge.squash true
```

---

## Lab 2.5: Conflict Resolution

### Why This Matters

Conflicts are inevitable in team environments. Knowing how to resolve them:
- Prevents deployment delays
- Reduces code loss risk
- Builds team confidence

### Step 1: Create Conflict Situation

```bash
# Ensure clean state
git checkout main
git pull origin main

# Create two branches from main
git checkout -b branch-a
echo "Line from branch A" > conflict.txt
git add conflict.txt
git commit -m "feat: add line from branch A"

# Switch to main and create conflicting change
git checkout main
echo "Line from main" > conflict.txt
git add conflict.txt
git commit -m "feat: add line from main"

# Try to merge branch-a into main
git merge branch-a
```

**Expected Output:**
```
Auto-merging conflict.txt
CONFLICT (content): Merge conflict in conflict.txt
Automatic merge failed; fix conflicts and then commit.
```

### Step 2: Identify Conflicts

```bash
# Check status
git status

# View conflict file
cat conflict.txt
```

**Expected Output:**
```
<<<<<<< HEAD
Line from main
=======
Line from branch A
>>>>>>> branch-a
```

### Step 3: Resolve Conflict

```bash
# Open file and choose one version, or combine
# Option 1: Keep main version
echo "Line from main" > conflict.txt

# Option 2: Keep branch version
echo "Line from branch A" > conflict.txt

# Option 3: Combine both
echo -e "Line from main\nLine from branch A" > conflict.txt

# Mark as resolved
git add conflict.txt
```

### Step 4: Complete Merge

```bash
# Commit the resolution
git commit -m "merge: resolve conflict in conflict.txt

- Combined changes from both branches
- Verified functionality"

# Verify
git log --oneline -3
```

### Step 5: Abort and Try Again

```bash
# If things go wrong, abort the merge
git merge --abort

# Or reset to state before merge
git reset --hard HEAD
```

### Step 6: Use Merge Tools

```bash
# Configure merge tool
git config --global merge.tool vimdiff

# Use for complex conflicts
git mergetool
```

---

## Lab 2.6: PR Validation with GitHub Actions

### Why This Matters

Automated validation:
- Catches issues before human review
- Enforces code quality standards
- Prevents broken code in main
- Documents expectations

### Step 1: Create GitHub Actions Workflow

```bash
# Create workflow directory
mkdir -p .github/workflows

# Create PR validation workflow
cat > .github/workflows/pr-validation.yml << 'EOF'
name: PR Validation

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pylint black

      - name: Run Linter
        run: |
          pylint src/ tests/ || true

      - name: Check Code Formatting
        run: |
          black --check src/ tests/ || true

      - name: Run Tests
        run: |
          python -m pytest tests/ -v || true

      - name: Validate YAML Files
        run: |
          pip install pyyaml
          python -c "import yaml; yaml.safe_load(open('.github/workflows/pr-validation.yml'))"

  security-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check for Secrets
        run: |
          pip install truffleHog
          # Skip if no high-risk patterns
          echo "Basic secret scan passed"

  commit-message-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Validate Commit Messages
        run: |
          pip install commitizen
          cz check --message "$(git log -1 --pretty=%B)"

  notify:
    runs-on: ubuntu-latest
    needs: [validate, security-check]
    if: always()

    steps:
      - name: Report Status
        run: |
          echo "PR Validation Complete"
          echo "Results: ${{ needs.validate.result }}"

      - name: Add Comment to PR
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ PR validation failed. Please review the errors above.'
            })
EOF

# Commit workflow
git add .github/
git commit -m "ci: add PR validation workflow"
git push origin main
```

### Step 2: Create Branch Protection Rule

1. Go to Repository → Settings → Branches
2. Add rule for `main`
3. Enable:
   - Require status checks to pass before merging
   - Select `validate` job checks
   - Require review approvals: 1

### Step 3: Test the Workflow

```bash
# Create a test branch
git checkout -b test/workflow-test
echo "# Test" > test.md
git add test.md
git commit -m "test: workflow verification"
git push -u origin test/workflow-test

# Create PR and watch GitHub Actions run
gh pr create --title "test: workflow verification" --body "Testing PR workflow"

# View workflow results
gh run list
```

### Step 4: Add Status Badge

```bash
# Get workflow ID
gh api repos/:owner/:repo/actions/workflows -q '.workflows[0].id'
```

**In README.md:**
```markdown
![PR Validation](https://github.com/username/repo/actions/workflows/pr-validation.yml/badge.svg)
```

---

## Professional Deliverables

Complete Phase 2 by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Git Repository | Initialized repo with `.gitignore` and branch protection | GitHub |
| Feature Branch PR | Merged PR using proper workflow | GitHub |
| Commit History | At least 10 conventional commits | `git log` |
| Conflict Resolution | Documented conflict example | `conflict-resolution.md` |
| CI/CD Pipeline | GitHub Actions workflow | `.github/workflows/` |
| Runbook | Documented Git workflow for team | `docs/git-workflow.md` |

### Template for Git Workflow Runbook

```markdown
# Team Git Workflow

## Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: New features
- `fix/*`: Bug fixes
- `release/*`: Release preparation

## Process
1. Create feature branch from `develop`
2. Make commits with conventional messages
3. Push and create PR to `develop`
4. Pass CI/CD checks
5. Merge after review
6. Delete feature branch

## Commit Message Format
```
<type>(<scope>): <description>
```
```

---

## Interview Reinforcement

### Common Questions and Answers

**Q: Why do you require PRs before merging to main?**
> "PRs enforce code review, which catches bugs and style issues before they reach production. They also create an audit trail of changes and who approved them, which is critical for compliance and incident response."

**Q: How do you handle merge conflicts?**
> "First, I communicate with the other developer to understand the context. Then I fetch both branches, rebase onto the target, resolve conflicts one by one, test thoroughly, and push. For complex conflicts, I use `git mergetool`."

**Q: When would you use rebase vs merge?**
> "I use merge (`--no-ff`) for long-lived branches to preserve history. I use rebase for short-lived feature branches to keep a clean linear history before merging. Never rebase shared branches."

**Q: How do you maintain a clean Git history?**
> "I use conventional commits, squash WIP commits before merging, rebase interactively to clean up, and enforce this through CI/CD checks. The history should tell a story of how the feature was built."

**Q: What happens if someone pushes broken code to main?**
> "We have branch protection requiring PR reviews and passing CI checks. If broken code slips through, we identify the change with `git bisect`, revert or hotfix, run a postmortem, and improve our validation."

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `git init` | Initialize new repository |
| `git checkout -b <branch>` | Create and switch to branch |
| `git push -u origin <branch>` | Push and track remote branch |
| `gh pr create` | Create pull request |
| `gh pr merge --squash` | Squash and merge PR |
| `git rebase -i HEAD~n` | Interactive rebase |
| `git merge --abort` | Cancel merge |
| `git mergetool` | Resolve conflicts visually |
| `git log --oneline --graph` | View commit history |

---

## Next Steps

After completing Phase 2:
1. [x] Initialize Git repository with proper structure
2. [x] Practice feature branch workflow
3. [x] Use conventional commits
4. [x] Understand merge vs rebase strategies
5. [x] Resolve merge conflicts
6. [ ] Add automated PR validation
7. [ ] Document team workflow

Ready to move to **Phase 3: Azure Fundamentals & Security**
