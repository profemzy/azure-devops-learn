#!/bin/bash
# Phase 2 Lab 2.1: Repository Setup Script
# This script sets up a professional Git repository structure

set -euo pipefail

REPO_NAME="${1:-devops-learn-phase2}"
echo "=== Phase 2 Lab 2.1: Git Repository Setup ==="
echo ""

# Check prerequisites
if ! command -v git &> /dev/null; then
    echo "[ERROR] Git is not installed. Please install git first."
    exit 1
fi

# Create project directory
echo "[INFO] Creating project directory..."
mkdir -p ~/$REPO_NAME
cd ~/$REPO_NAME

# Initialize git repo
echo "[INFO] Initializing Git repository..."
git init

# Create .gitignore
echo "[INFO] Creating .gitignore..."
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
.env
.secrets/
!.gitignore.template

# Logs
*.log
*.log.*

# Build
build/
dist/
*.egg-info/
__pycache__/
node_modules/

# Temporary
*.tmp
*.bak
*~
EOF

# Create directory structure
echo "[INFO] Creating project structure..."
mkdir -p src tests docs scripts

# Create README
echo "[INFO] Creating README.md..."
cat > README.md << 'EOF'
# DevOps Learning Project

This repository contains materials for Phase 2: Git & Engineering Workflows.

## Structure

- `src/` - Source code
- `tests/` - Unit tests
- `docs/` - Documentation
- `scripts/` - Utility scripts

## Getting Started

```bash
# Clone and setup
git clone <repo-url>
cd devops-learn-phase2
```
EOF

# Create initial files
echo "[INFO] Creating initial source files..."
cat > src/main.py << 'EOF'
"""Main application module."""


def greet(name: str) -> str:
    """Return a greeting message."""
    return f"Hello, {name}!"


if __name__ == "__main__":
    print(greet("DevOps Engineer"))
EOF

cat > tests/test_main.py << 'EOF'
"""Tests for main module."""
from src.main import greet


def test_greet():
    """Test basic greeting."""
    assert greet("World") == "Hello, World!"
EOF

cat > docs/.gitkeep << 'EOF'
# Documentation directory
EOF

# Configure git
echo "[INFO] Configuring Git..."
git config user.name "DevOps Learner"
git config user.email "learner@example.com"

# Initial commit
echo "[INFO] Creating initial commit..."
git add .
git commit -m "init: project setup with gitignore and basic structure

- Add professional .gitignore
- Create src/, tests/, docs/ directories
- Add initial Python module and tests"

# Create develop branch
echo "[INFO] Creating develop branch..."
git checkout -b develop

echo ""
echo "[SUCCESS] Repository setup complete!"
echo ""
echo "Next steps:"
echo "  1. Create repository on GitHub"
echo "  2. Add remote: git remote add origin <github-url>"
echo "  3. Push: git push -u origin main"
echo ""
echo "Current branches:"
git branch -a
