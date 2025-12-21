#!/bin/bash
# Phase 2 Validation Script
# Checks completion of all Phase 2 labs

set -euo pipefail

echo "=== Phase 2: Git Workflows Validation ==="
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"

    if [ "$result" -eq 0 ]; then
        echo "[PASS] $name"
        ((PASS++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

# Check 1: Git initialized
echo "--- Lab 2.1: Repository Setup ---"
if git rev-parse --git-dir > /dev/null 2>&1; then
    check "Git repository initialized" 0
else
    check "Git repository initialized" 1
fi

# Check 2: .gitignore exists and has content
if [ -f .gitignore ]; then
    if grep -q "IDE" .gitignore && grep -q "Azure" .gitignore; then
        check "Professional .gitignore created" 0
    else
        check "Professional .gitignore created" 1
    fi
else
    check "Professional .gitignore created" 1
fi

# Check 3: Project structure
if [ -d src ] && [ -d tests ] && [ -d docs ]; then
    check "Project structure (src/, tests/, docs/)" 0
else
    check "Project structure (src/, tests/, docs/)" 1
fi

# Check 4: Conventional commits
echo ""
echo "--- Lab 2.2: Feature Branch Workflow ---"
BRANCH_COUNT=$(git branch -a 2>/dev/null | wc -l)
if [ "$BRANCH_COUNT" -gt 1 ]; then
    check "Multiple branches created" 0
else
    check "Multiple branches created" 1
fi

# Check 5: Commit message format
echo ""
echo "--- Lab 2.3: Commit Message Conventions ---"
if git log --oneline -5 | grep -qE '^(feat|fix|docs|style|refactor|test|chore)'; then
    check "Conventional commit messages" 0
else
    check "Conventional commit messages" 1
fi

# Check 6: Merge commits exist
echo ""
echo "--- Lab 2.4: Merge vs Rebase ---"
if git log --oneline | grep -q "merge:"; then
    check "Merge strategy used" 0
else
    echo "[INFO] No merge commits found - may use rebase/squash"
fi

# Check 7: GitHub Actions workflow
echo ""
echo "--- Lab 2.5 & 2.6: CI/CD & PR Validation ---"
if [ -d .github/workflows ]; then
    if ls .github/workflows/*.yml 2>/dev/null | grep -q .; then
        check "GitHub Actions workflow created" 0
    else
        check "GitHub Actions workflow created" 1
    fi
else
    check "GitHub Actions workflow created" 1
fi

# Check 8: PRs merged (check for merge commits)
echo ""
echo "--- Additional Checks ---"
COMMIT_COUNT=$(git rev-list --count HEAD)
if [ "$COMMIT_COUNT" -ge 5 ]; then
    check "Sufficient commits ($COMMIT_COUNT)" 0
else
    check "Sufficient commits ($COMMIT_COUNT)" 1
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "[SUCCESS] All Phase 2 validation checks passed!"
    exit 0
else
    echo "[INCOMPLETE] Some checks failed. Review the labs and try again."
    exit 1
fi
